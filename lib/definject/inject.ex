defmodule Definject.Inject do
  @moduledoc false
  @uninjectable quote(do: [:erlang])
  @modifiers [:import, :require, :use]

  def inject_function(head, body, %Macro.Env{module: mod, file: file, line: line} = env) do
    with {:ok, {injected_body, captures}} <- body |> process_body_recusively(env) do
      {name, _, args} = injected_head = head_with_deps(head)
      arity = args |> Enum.count()

      quote do
        def unquote(injected_head) do
          Definject.Check.validate_deps(
            deps,
            unquote(captures),
            unquote(Macro.escape({mod, name, arity}))
          )

          unquote(injected_body)
        end
      end
    else
      {:error, :modifier} ->
        raise CompileError,
          file: file,
          line: line,
          description: "Cannot import/require/use inside definject. Move it to module level."
    end
  end

  def process_body_recusively(body, env) do
    with {:ok, ^body} <- body |> check_no_modifier_recursively() do
      {injected_body, captures} =
        body
        |> expand_recursively!(env)
        |> mark_remote_call_recursively!()
        |> inject_recursively!()

      {:ok, {injected_body, captures}}
    end
  end

  defp check_no_modifier_recursively(ast) do
    case ast
         |> Macro.prewalk(:ok, fn
           _ast, {:error, :modifier} ->
             {nil, {:error, :modifier}}

           {modifier, _, _}, :ok when modifier in @modifiers ->
             {nil, {:error, :modifier}}

           ast, :ok ->
             {ast, :ok}
         end) do
      {expanded_ast, :ok} -> {:ok, expanded_ast}
      {_, {:error, :modifier}} -> {:error, :modifier}
    end
  end

  defp expand_recursively!(ast, env) do
    ast
    |> Macro.prewalk(fn
      {:@, _, _} = ast ->
        ast

      ast ->
        Macro.expand(ast, env)
    end)
  end

  defp mark_remote_call_recursively!(ast) do
    ast
    |> Macro.prewalk(fn
      {:&, c1, [{:/, c2, [{{:., c3, [mod, name]}, c4, []}, arity]}]} ->
        {:&, c1, [{:/, c2, [{{:., c3, [mod, name]}, [{:skip_inject, true} | c4], []}, arity]}]}

      ast ->
        ast
    end)
  end

  defp inject_recursively!(ast) do
    ast
    |> Macro.postwalk([], fn ast, captures ->
      {injected_ast, new_caputres} = inject(ast)
      {injected_ast, new_caputres ++ captures}
    end)
  end

  defp inject({_func, [{:skip_inject, true} | _], _args} = ast) do
    {ast, []}
  end

  defp inject({{:., _dot_ctx, [mod, name]}, _call_ctx, args})
       when mod not in @uninjectable and is_atom(name) and is_list(args) do
    mfa = {mod, name, Enum.count(args)}
    capture = function_capture_ast(mfa)

    injected_call =
      quote do
        (deps[unquote(capture)] || unquote(capture)).(unquote_splicing(args))
      end

    {injected_call, [capture]}
  end

  defp inject(ast) do
    {ast, []}
  end

  defp function_capture_ast({mod, name, arity}) do
    mf = {{:., [], [mod, name]}, [], []}
    mfa = {:/, [], [mf, arity]}
    {:&, [], [mfa]}
  end

  def head_with_deps({:when, when_ctx, [name_args, when_cond]}) do
    name_args = head_with_deps(name_args)
    {:when, when_ctx, [name_args, when_cond]}
  end

  def head_with_deps({name, meta, context}) when not is_list(context) do
    # Normalize function head.
    # def some do: nil end   ->   def some(), do: nil end
    head_with_deps({name, meta, []})
  end

  def head_with_deps({name, meta, params}) when is_list(params) do
    deps =
      quote do
        %{} = deps \\ %{}
      end

    {name, meta, params ++ [deps]}
  end
end
