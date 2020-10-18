defmodule Definject.Def do
  defmacro def(call, expr \\ nil) do
    if Application.get_env(:definject, :enable, Mix.env() == :test) do
      quote do
        Definject.definject(unquote(call), unquote(expr))
      end
    else
      quote do
        Kernel.def(unquote(call), unquote(expr))
      end
    end
  end
end
