defmodule Definject.Mock do
  def surround_by_fn({{:&, _, [{:/, _, [_mf, a]}]} = capture, v}) do
    const_fn = {:fn, [], [{:->, [], [Macro.generate_arguments(a, __MODULE__), v]}]}
    {capture, const_fn}
  end

  def surround_by_fn({:strict, _} = orig) do
    orig
  end

  def function_capture_ast({mod, name, arity}) do
    mf = {{:., [], [mod, name]}, [], []}
    mfa = {:/, [], [mf, arity]}
    {:&, [], [mfa]}
  end

  def unquote_function_capture({mod_ast, name, arity}) do
    mod = mod_ast |> unquote_module()
    :erlang.make_fun(mod, name, arity)
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
