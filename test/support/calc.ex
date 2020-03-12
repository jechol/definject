defmodule Calc do
  def sum(a, b), do: a + b
  def to_int(str), do: String.to_integer(str)

  def id(a), do: a

  defmacro macro_sum(a, b) do
    quote do
      import Calc
      sum(unquote(a), unquote(b))
    end
  end
end
