defmodule Definject.Impl do
  @uninjectable [:erlang, Kernel, Macro, Module, Access]

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
          Definject.Check.raise_if_uninjectable_deps_injected(deps)
          Definject.Check.raise_if_unknown_deps_found(unquote(Macro.escape(mfas)), deps)
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
           (&(unquote(capture) / unquote(arity)))).(unquote_splicing(args))
      end

    %{ast: ast, mfas: [{remote_mod, name, arity}]}
  end

  def inject_remote_call(ast) do
    %{ast: ast, mfas: []}
  end

  @doc false
  defmacro make_const_function(arity, expr, %Macro.Env{module: context}) do
    {:fn, [], [{:->, [], [Macro.generate_arguments(arity, context), expr]}]}
  end
end
