defmodule Definject.Inject do
  @moduledoc false

  alias Definject.AST

  @uninjectable [:erlang, Kernel]
  @modifiers [:import, :require, :use]

  def inject_function(head, body, %Macro.Env{module: mod, file: file, line: line} = env) do
    with {:ok, {injected_body, captures, mods}} <- body |> process_body_recusively(env) do
      call_for_head = call_for_head(head)
      call_for_clause = call_for_clause(head)
      fa = {name, arity} = get_fa(head)

      quote do
        Module.register_attribute(__MODULE__, :definjected, accumulate: true)

        unless unquote(fa) in Module.get_attribute(__MODULE__, :definjected) do
          def unquote(call_for_head)
          @definjected unquote(fa)
        end

        def unquote(call_for_clause) do
          Definject.Check.validate_deps(
            deps,
            {unquote(captures), unquote(mods)},
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

  def inject_function(head, body, resq, %Macro.Env{module: mod, file: file, line: line} = env) do
    with {:ok, {injected_body, body_captures, body_mods}} <- body |> process_body_recusively(env),
         {:ok, {injected_resq, resq_captures, resq_mods}} <- resq |> process_body_recusively(env) do
      call_for_head = call_for_head(head)
      call_for_clause = call_for_clause(head)
      fa = {name, arity} = get_fa(head)

      quote do
        Module.register_attribute(__MODULE__, :definjected, accumulate: true)

        unless unquote(fa) in Module.get_attribute(__MODULE__, :definjected) do
          def unquote(call_for_head)
          @definjected unquote(fa)
        end

        def unquote(call_for_clause) do
          Definject.Check.validate_deps(
            deps,
            {unquote(body_captures ++ resq_captures), unquote(body_mods ++ resq_mods)},
            unquote(Macro.escape({mod, name, arity}))
          )

          unquote(injected_body)
        rescue
          unquote(injected_resq)
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

  defp get_fa({:when, _, [name_args, _when_cond]}) do
    get_fa(name_args)
  end

  defp get_fa({name, _, args}) when is_list(args) do
    {name, args |> Enum.count()}
  end

  defp get_fa({name, _, _}) do
    {name, 0}
  end

  def process_body_recusively(body, env) do
    with {:ok, ^body} <- body |> check_no_modifier_recursively() do
      {injected_body, {captures, mods}} =
        body
        |> expand_recursively!(env)
        |> mark_remote_call_recursively!()
        |> inject_recursively!()

      {:ok, {injected_body, captures, mods}}
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
    |> Macro.postwalk({[], []}, fn ast, {captures, mods} ->
      {injected_ast, new_caputres, new_mods} = inject(ast)
      {injected_ast, {new_caputres ++ captures, new_mods ++ mods}}
    end)
  end

  defp inject({_func, [{:skip_inject, true} | _], _args} = ast) do
    {ast, [], []}
  end

  defp inject({{:., _dot_ctx, [mod, name]}, _call_ctx, args} = ast)
       when is_atom(name) and is_list(args) do
    if AST.is_module_ast(mod) and AST.unquote_module_ast(mod) not in @uninjectable do
      arity = Enum.count(args)
      capture = AST.quote_function_capture({mod, name, arity})

      injected_call =
        quote do
          Map.get(
            deps,
            unquote(capture),
            :erlang.make_fun(
              Map.get(deps, unquote(mod), unquote(mod)),
              unquote(name),
              unquote(arity)
            )
          ).(unquote_splicing(args))
        end

      {injected_call, [capture], [mod]}
    else
      {ast, [], []}
    end
  end

  defp inject(ast) do
    {ast, [], []}
  end

  def call_for_head({:when, _when_ctx, [name_args, _when_cond]}) do
    call_for_head(name_args)
  end

  def call_for_head({name, meta, context}) when not is_list(context) do
    # Normalize function head.
    # def some do: nil end   ->   def some(), do: nil end
    call_for_head({name, meta, []})
  end

  def call_for_head({name, meta, params}) when is_list(params) do
    deps =
      quote do
        deps \\ %{}
      end

    # def div(n, 0) -> def div(a, b)
    params =
      for {p, index} <- params |> Enum.with_index() do
        AST.Param.remove_pattern(p, index)
      end

    {name, meta, params ++ [deps]}
  end

  def call_for_clause({:when, when_ctx, [name_args, when_cond]}) do
    name_args = call_for_clause(name_args)
    {:when, when_ctx, [name_args, when_cond]}
  end

  def call_for_clause({name, meta, context}) when not is_list(context) do
    # Normalize function head.
    # def some do: nil end   ->   def some(), do: nil end
    call_for_clause({name, meta, []})
  end

  def call_for_clause({name, meta, params}) when is_list(params) do
    deps = quote do: deps

    params = params |> Enum.map(&AST.Param.remove_default/1)
    {name, meta, params ++ [deps]}
  end

  def get_name_arity({:when, _when_ctx, [name_args, _when_cond]}) do
    get_name_arity(name_args)
  end

  def get_name_arity({name, _, context}) when not is_list(context) do
    {name, 0}
  end

  def get_name_arity({name, _, params}) when is_list(params) do
    {name, params |> Enum.count()}
  end
end
