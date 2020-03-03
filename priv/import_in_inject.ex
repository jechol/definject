defmodule ImportInInject do
  import Definject

  definject str_to_atom(str) do
    import Calc
    to_int(str)
  end
end
