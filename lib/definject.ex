defmodule Definject do
  @doc """
  `definject` transforms a function to accept a map where dependent functions and modules can be injected.

      import Definject

      definject send_welcome_email(user_id) do
        %{email: email} = Repo.get(User, user_id)

        welcome_email(to: email)
        |> Mailer.send()
      end

  is expanded into

      def send_welcome_email(user_id, deps \\\\ %{}) do
        %{email: email} = Map.get(deps, &Repo.get/2, :erlang.make_fun(Map.get(deps, Repo, Repo), :get, 2)).(User, user_id)

        welcome_email(to: email)
        |> Map.get(deps, &Mailer.send/1, :erlang.make_fun(Map.get(deps, Mailer, Mailer), :send, 1)).()
      end

  Note that local function calls like `welcome_email(to: email)` are not expanded unless it is prepended with `__MODULE__`.

  Now, you can inject mock functions and modules in tests.

      test "send_welcome_email" do
        Accounts.send_welcome_email(100, %{
          Repo => MockRepo,
          &Mailer.send/1 => fn %Email{to: "user100@gmail.com", subject: "Welcome"} ->
            Process.send(self(), :email_sent)
          end
        })

        assert_receive :email_sent
      end

  `definject` raises if the passed map includes a function or a module that's not used within the injected function.
  You can disable this by adding `strict: false` option.

      test "send_welcome_email with strict: false" do
        Accounts.send_welcome_email(100, %{
          &Repo.get/2 => fn User, 100 -> %User{email: "user100@gmail.com"} end,
          &Repo.all/1 => fn _ -> [%User{email: "user100@gmail.com"}] end, # Unused
          strict: false,
        })
      end
  """
  defmacro definject(head, do: body) do
    alias Definject.Inject

    original =
      quote do
        def unquote(head), do: unquote(body)
      end

    if Application.get_env(:definject, :enable, Mix.env() == :test) do
      injected = Inject.inject_function(head, body, __CALLER__)

      if Application.get_env(:definject, :trace, false) do
        %{file: file, line: line} = __CALLER__

        dash = "=============================="

        IO.puts("""
        #{dash} definject #{file}:#{line} #{dash}
        #{original |> Macro.to_string()}
        #{dash} into #{dash}"
        #{injected |> Macro.to_string()}
        """)
      end

      injected
    else
      original
    end
  end

  defmacro definject(head, do: body, rescue: resq) do
    alias Definject.Inject

    original =
      quote do
        def unquote(head), do: unquote(body), rescue: unquote(resq)
      end

    if Application.get_env(:definject, :enable, Mix.env() == :test) do
      injected = Inject.inject_function(head, body, resq, __CALLER__)

      if Application.get_env(:definject, :trace, false) do
        %{file: file, line: line} = __CALLER__

        dash = "=============================="

        IO.puts("""
        #{dash} definject #{file}:#{line} #{dash}
        #{original |> Macro.to_string()}
        #{dash} into #{dash}"
        #{injected |> Macro.to_string()}
        """)
      end

      injected
    else
      original
    end
  end

  defmacro definject(head) do
    alias Definject.Inject

    original =
      quote do
        def unquote(head)
      end

    if Application.get_env(:definject, :enable, Mix.env() == :test) do
      injected = Inject.inject_function(head, __CALLER__)

      if Application.get_env(:definject, :trace, false) do
        %{file: file, line: line} = __CALLER__

        dash = "=============================="

        IO.puts("""
        #{dash} definject #{file}:#{line} #{dash}
        #{original |> Macro.to_string()}
        #{dash} into #{dash}"
        #{injected |> Macro.to_string()}
        """)
      end

      injected
    else
      original
    end
  end

  @doc """
  If you don't need pattern matching in mock function, `mock/1` can be used to reduce boilerplates.

      import Definject

      test "send_welcome_email with mock/1" do
        Accounts.send_welcome_email(
          100,
          mock(%{
            Repo => MockRepo,
            &Mailer.send/1 => Process.send(self(), :email_sent)
          })
        )

        assert_receive :email_sent
      end

  Note that `Process.send(self(), :email_sent)` is surrounded by `fn _ -> end` when expanded.
  """
  defmacro mock({:%{}, context, mocks}) do
    alias Definject.Mock

    {:%{}, context, mocks |> Enum.map(&Mock.decorate_with_fn/1)}
  end
end
