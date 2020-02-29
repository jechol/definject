defmodule DefInject do
  @uninjectable [:erlang, Kernel, Macro, Module, Access]

  defmacro __using__(_opts) do
    quote do
      import Inject, only: [definject: 2, mock: 1]
    end
  end

  @doc """
  `definject` transforms a function to accept a map where dependent functions can be injected.

      import DefInject

      definject send_welcome_email(user_id) do
        %{email: email} = Repo.get(User, user_id)

        Email.welcome(email)
        |> Mailer.send()
      end

  is expanded into

      def send_welcome_email(user_id, deps \\\\ %{}) do
        %{email: email} = (deps[{Repo, :get, 2}] || &Repo.get/2).(User, user_id)

        (deps[{Email, :welcome, 1}] || &Email.welcome/1).(email)
        |> (deps[{Mailer, :send, 1}] || &Mailer.send/1).()
      end

  Then we can inject mock functions in tests.

      test "send_welcome_email" do
        Accounts.send_welcome_email(100, %{
          {Repo, :get, 2} => fn User, 100 -> %User{email: "mr.jechol@gmail.com"} end,
          {Mailer, :send, 1} => fn %Email{to: "mr.jechol@gmail.com", subject: "Welcome"} ->
            Process.send(self(), :email_sent)
          end
        })

        assert_receive :email_sent
      end

  `definject` raises if the passed map includes a function that's not called within the injected function.
  You can disable this by adding `strict: false` option.

      test "send_welcome_email with strict: false" do
        Accounts.send_welcome_email(100, %{
          {Repo, :get, 2} => fn User, 100 -> %User{email: "mr.jechol@gmail.com"} end,
          {Repo, :all, 1} => fn _ -> [%User{email: "mr.jechol@gmail.com"}] end, # Unused
          :strict => false,
        })
      end
  """
  defmacro definject(head, do: body) do
    if Application.get_env(:definject, :enabled?, Mix.env() == :test) do
      inject_function(%{head: head, body: body, env: __CALLER__})
    else
      quote do
        def unquote(head), do: unquote(body)
      end
    end
  end

  @doc false
  def inject_function(%{head: head, body: body, env: %Macro.Env{} = env}) do
    injected_head = head_with_deps(%{head: head})

    {_, env_modified?} =
      Macro.prewalk(body, false, fn ast, env_modified? ->
        {ast, env_modified? || modifies_env?(ast)}
      end)

    if env_modified? do
      quote do
        raise "Cannot import/require/use inside definject. Move it to module level."
      end
    else
      {injected_body, mfas} =
        body
        |> Macro.prewalk(fn ast ->
          if expandable?(ast) do
            Macro.expand(ast, env)
          else
            ast
          end
        end)
        |> Macro.postwalk([], fn ast, mfas ->
          %{ast: ast, mfas: new_mfas} = inject_remote_call(ast)
          {ast, new_mfas ++ mfas}
        end)

      # `quote` with dynamic `context` requires Elixir 1.10+
      quote do
        def unquote(injected_head) do
          DefInject.Check.raise_if_uninjectable_deps_injected(deps)
          DefInject.Check.raise_if_unknown_deps_found(unquote(Macro.escape(mfas)), deps)
          unquote(injected_body)
        end
      end
    end
  end

  defp expandable?({:@, _, _}), do: false
  defp expandable?(_), do: true

  defp modifies_env?({name, _, _}) when name in [:import, :require, :use], do: true
  defp modifies_env?(_), do: false

  @doc false
  def head_with_deps(%{head: {name, meta, context}}) when not is_list(context) do
    # Normalize function head.
    # def some do: nil end   ->   def some(), do: nil end
    head_with_deps(%{head: {name, meta, []}})
  end

  def head_with_deps(%{head: {name, meta, params}}) when is_list(params) do
    deps =
      quote do
        %{} = deps \\ %{}
      end

    {name, meta, params ++ [deps]}
  end

  @doc false
  def inject_remote_call({{:., _, [remote_mod, name]} = func, _, args})
      when remote_mod not in @uninjectable and is_atom(name) and is_list(args) do
    arity = Enum.count(args)
    capture = {func, [no_parens: true], []}

    ast =
      quote do
        (deps[{unquote(remote_mod), unquote(name), unquote(arity)}] ||
           &(unquote(capture) / unquote(arity))).(unquote_splicing(args))
      end

    %{ast: ast, mfas: [{remote_mod, name, arity}]}
  end

  def inject_remote_call(ast) do
    %{ast: ast, mfas: []}
  end

  @doc """
  If you don't need pattern matching in mock function, `mock/1` can be used to reduce boilerplates.

      test "send_welcome_email with mock/1" do
        Accounts.send_welcome_email(
          100,
          mock(%{
            &Repo.get/2 => %User{email: "mr.jechol@gmail.com"},
            &Mailer.send/1 => Process.send(self(), :email_sent)
          })
        )

        assert_receive :email_sent
      end

  Note that `Process.send(self(), :email_sent)` is surrounded by `fn _ -> end` when expanded.
  """
  defmacro mock({:%{}, _, mocks}) do
    mocks =
      mocks
      |> Enum.map(fn {k, v} ->
        {:&, _, [capture]} = k
        {:/, _, [mf, a]} = capture
        {mf, _, []} = mf
        {:., _, [m, f]} = mf

        quote do
          {{unquote(m), unquote(f), unquote(a)},
           unquote(__MODULE__).make_const_function(unquote(a), unquote(v), unquote(__CALLER__))}
        end
      end)

    {:%{}, [], mocks}
  end

  @doc false
  defmacro make_const_function(arity, expr, %Macro.Env{module: context}) do
    {:fn, [], [{:->, [], [Macro.generate_arguments(arity, context), expr]}]}
  end
end
