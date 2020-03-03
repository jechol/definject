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

  def function_capture_ast(remote_mod, name, arity) do
    mf = {{:., [], [remote_mod, name]}, [], []}
    mfa = {:/, [], [mf, arity]}
    {:&, [], [mfa]}
  end
end
