defmodule Definject.MostComplexTest do
  defmodule Complex do
    definject div(a, b)
    definject div(a, b \\ 1)

    definject div(a, 1) do
      a
    end

    definject div(a, b) do
      if b == 0 do
        raise :div_by_ero
      else
        a / b
      end
    rescue
      :div_by_zero -> :error
    end
  end
end
