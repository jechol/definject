defmodule Definject.MulticlauseTest do
  use ExUnit.Case, async: true
  import Definject

  defmodule Multi do
    definject add(a, 0), do: Calc.id(a)
    definject add(a, b), do: Calc.sum(a, b)
  end

  test "Multiclause with pattern matching works" do
    assert Multi.add(10, 0) == 10
    assert Multi.add(10, 0, mock(%{&Calc.id/1 => 99})) == 99

    assert Multi.add(10, 1) == 11

    assert_raise RuntimeError, ~r/unused/, fn ->
      Multi.add(10, 1, mock(%{&Calc.id/1 => 99}))
    end

    assert Multi.add(10, 1, mock(%{&Calc.sum/2 => 99})) == 99
  end
end
