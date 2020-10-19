defmodule Definject.UseTest do
  use ExUnit.Case, async: true
  import Definject

  defmodule WithNormalFunction do
    use Definject

    def add(a, b), do: Calc.sum(a, b)
  end

  test "with normal function" do
    assert WithNormalFunction.add(1, 1) == 2
    assert WithNormalFunction.add(1, 1, mock(%{&Calc.sum/2 => 99})) == 99
  end

  defmodule WithBodylessClause do
    use Definject

    def add(a, b \\ 0)

    def add(a, b), do: Calc.sum(a, b)
  end

  test "with bodyless clause" do
    assert WithBodylessClause.add(1, 1) == 2
    assert WithBodylessClause.add(1, 1, mock(%{&Calc.sum/2 => 99})) == 99
  end
end
