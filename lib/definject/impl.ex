defmodule Definject.Impl do
  @moduledoc false
  @uninjectable Application.get_env(:definject, :uninjectable, [
                  PlaceholderToSuppressCompileWarning
                ])

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
      {injected_body, captures} =
        body
        |> Macro.prewalk(fn ast ->
          if expandable?(ast) do
            Macro.expand(ast, env)
          else
            ast
          end
        end)
        |> Macro.postwalk([], fn ast, captures ->
          %{ast: ast, captures: new_captures} = inject_remote_call(ast)
          {ast, new_captures ++ captures}
        end)

      # `quote` with dynamic `context` requires Elixir 1.10+
      quote do
        def unquote(injected_head) do
          Definject.Check.validate_deps(unquote(captures), deps)

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
  def inject_remote_call({{:., _, [remote_mod, name]}, _, args})
      when remote_mod not in @uninjectable and is_atom(name) and is_list(args) do
    arity = Enum.count(args)
    capture = function_capture(remote_mod, name, arity)

    ast =
      quote do
        (deps[unquote(capture)] || unquote(capture)).(unquote_splicing(args))
      end

    %{ast: ast, captures: [capture]}
  end

  def inject_remote_call(ast) do
    %{ast: ast, captures: []}
  end

  def surround_by_fn({{:&, _, [capture]}, v}) do
    {:/, _, [mf, a]} = capture
    {mf, _, []} = mf
    {:., _, [m, f]} = mf

    capture = function_capture(m, f, a)
    const_fn = {:fn, [], [{:->, [], [Macro.generate_arguments(a, __MODULE__), v]}]}

    {capture, const_fn}
  end

  def surround_by_fn({:strict, _} = orig) do
    orig
  end

  defp function_capture(remote_mod, name, arity) do
    mf = {{:., [], [remote_mod, name]}, [no_parens: true], []}
    mfa = {:/, [], [mf, arity]}
    {:&, [], [mfa]}
  end
end
