defmodule Definject.NoDoTest do
  defmodule ForDoc do
    definject add(a, b)

    definject add(a, b), do: Calc.sum(a, b)
  end

  defmodule ForDefault do
    definject add(a, b \\ 0)

    definject add(a, b), do: Calc.sum(a, b)
  end
end
