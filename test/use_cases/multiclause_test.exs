defmodule Definject.MulticlauseTest do
  import Definject

  defmodule Multi do
    definject add(a, 0), do: Calc.id(a)
    definject add(a, b), do: Calc.sum(a, b)
  end
end
