defmodule Definject.RescueTest do
  use ExUnit.Case, async: true
  import Definject

  defmodule Rescue do
    definject div(a, b) do
      if b == 0 do
        raise ArithmeticError
      else
        Calc.div(a, b)
      end
    rescue
      ArithmeticError -> Calc.id(:div_by_zero)
    end
  end

  test "definject/3" do
    assert Rescue.div(10, 2) == 5
    assert Rescue.div(10, 2, mock(%{&Calc.div/2 => 99})) == 99

    assert Rescue.div(10, 0) == :div_by_zero
    assert Rescue.div(10, 0, mock(%{&Calc.id/1 => 101})) == 101
  end
end
