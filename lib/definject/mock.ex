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
end
