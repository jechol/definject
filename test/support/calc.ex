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

  def div(a, b \\ 1)
  def div(a, b)

  def div(a, 1) do
    {:no_div, a}
  end

  def div(a, b) do
    if b == 0 do
      raise ArithmeticError, "div_by_zero"
    else
      {:div, a / b}
    end
  rescue
    ArithmeticError -> :error
  end

  Module.register_attribute(__MODULE__, :a, accumulate: true)

  unless {:add, 2} in Module.get_attribute(__MODULE__, :a) do
    IO.puts("!!!!!")
  end

  @a {:add, 2}
  unless {:add, 2} in Module.get_attribute(__MODULE__, :a) do
    IO.puts("!!!!!")
  end

  @a {:add, 2}
  unless {:add, 2} in Module.get_attribute(__MODULE__, :a) do
    IO.puts("!!!!!")
  end
end
