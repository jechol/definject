defmodule Definject.Inject do
  @moduledoc false
  @uninjectable quote(do: [:erlang])
  @modifiers [:import, :require, :use]

  def inject_function(%{head: head, body: body, env: %Macro.Env{} = env}) do
    with {:ok, {injected_body, captures}} <- body |> process_body_recusively(env) do
      injected_head = head_with_deps(head)

      quote do
        def unquote(injected_head) do
          Definject.Check.validate_deps(unquote(captures), deps)

          unquote(injected_body)
        end
      end
    else
      {:error, modifier} when modifier in @modifiers ->
        quote do
          raise "Cannot import/require/use inside definject. Move it to module level."
        end
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
    ast
    |> Macro.prewalk(:ok, fn
      ast, {:error, reason} ->
        {ast, {:error, reason}}

      {modifier, _, _} = ast, :ok when modifier in @modifiers ->
        {ast, {:error, modifier}}

      ast, :ok ->
        {ast, :ok}
    end)
    |> convert_walk_result()
  end

  defp convert_walk_result({expanded_ast, :ok}), do: {:ok, expanded_ast}
  defp convert_walk_result({_, {:error, reason}}), do: {:error, reason}

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

  defp inject({{:., _dot_ctx, [remote_mod, name]}, _call_ctx, args})
       when remote_mod not in @uninjectable and is_atom(name) and is_list(args) do
    capture = Definject.Mock.function_capture_ast(remote_mod, name, Enum.count(args))

    injected_call =
      quote do
        (deps[unquote(capture)] || unquote(capture)).(unquote_splicing(args))
      end

    {injected_call, [capture]}
  end

  defp inject(ast) do
    {ast, []}
  end

  def head_with_deps({:when, when_ctx, [call_head, when_cond]}) do
    head = head_with_deps(call_head)
    {:when, when_ctx, [head, when_cond]}
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
