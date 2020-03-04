defmodule Definject.Mock do
  @moduledoc false

  def decorate_with_fn({{:__aliases__, _, _}, _} = orig) do
    orig
  end

  def decorate_with_fn({mod, _} = orig) when is_atom(mod) do
    orig
  end

  def decorate_with_fn({:strict, _} = orig) do
    orig
  end

  def decorate_with_fn({{:&, _, [{:/, _, [_mf, a]}]} = capture, v}) do
    const_fn = {:fn, [], [{:->, [], [Macro.generate_arguments(a, __MODULE__), v]}]}
    {capture, const_fn}
  end
end
