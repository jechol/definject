defmodule Definject.NoDoTest do
  use ExUnit.Case, async: true
  import Definject

  defmodule ForDocumentation do
    definject add(a, b)

    definject add(a, b), do: Calc.sum(a, b)
  end

  test "no do: for documentation" do
    assert ForDocumentation.add(1, 1) == 2
    assert ForDocumentation.add(1, 1, mock(%{&Calc.sum/2 => 99})) == 99
  end

  defmodule ForDefault do
    definject add(a, b \\ 0)

    definject add(a, b), do: Calc.sum(a, b)
  end

  test "no do: for default" do
    assert ForDefault.add(1) == 1

    assert ForDefault.add(1, 1) == 2
    assert ForDefault.add(1, 1, mock(%{&Calc.sum/2 => 101})) == 101
  end
end
