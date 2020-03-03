defmodule Definject.Mock do
  def surround_by_fn({{:&, _, [capture]}, v}) do
    {:/, _, [mf, a]} = capture
    {mf, _, []} = mf
    {:., _, [m, f]} = mf

    capture = function_capture_ast(m, f, a)
    const_fn = {:fn, [], [{:->, [], [Macro.generate_arguments(a, __MODULE__), v]}]}

    {capture, const_fn}
  end

  def surround_by_fn({:strict, _} = orig) do
    orig
  end

  def function_capture_ast(mod_ast, name, arity) do
    :erlang.make_fun(mod_ast |> unquote_module(), name, arity)
  end

  defp unquote_module({:__aliases__, [alias: mod], _}) when is_atom(mod) and mod != false do
    mod
  end

  defp unquote_module({:__aliases__, _, atoms}) do
    Module.concat(atoms)
  end

  defp unquote_module(atom) when is_atom(atom) do
    atom
  end
end
