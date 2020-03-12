defmodule Definject.RescueTest do
  import Definject

  defmodule Rescue do
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
