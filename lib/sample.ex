defmodule Sample do
  def hello(com) do
    case com do
      :throw -> throw(10)
      :raise -> raise "hi"
      :else -> 1000
    end
  rescue
    e -> IO.inspect(e)
  catch
    e -> IO.inspect("------------ catched #{e}")
  else
    e -> IO.inspect(e)
  after
    IO.inspect("----------- after")
  end

  defmodule Calc do
    def sum(a, b), do: a + b
    def div(a, b), do: a / b
    def to_int(str), do: String.to_integer(str)

    def id(a), do: a

    defmacro macro_sum(a, b) do
      quote do
        import Calc
        sum(unquote(a), unquote(b))
      end
    end
  end

  def div(a, b) do
    if b == 0 do
      raise ArithmeticError
    else
      throw(Calc.div(a, b))
    end
  rescue
    ArithmeticError -> Calc.id(:div_by_zero)
  catch
    n when is_number(n) -> IO.inspect(n)
  else
    n when is_number(n) -> IO.inspect(n)
  after
    IO.inspect("---- after")
  end
end
