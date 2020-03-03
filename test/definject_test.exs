defmodule InjectTest do
  use ExUnit.Case, async: true
  import Definject

  defmodule Nested do
    defmodule DoubleNested do
      def to_int(str), do: String.to_integer(str)
    end
  end

  alias Nested.DoubleNested

  describe "definject" do
    def quack(), do: nil

    defmodule Foo do
      import List, only: [first: 1]
      require Calc

      def quack(), do: :arity_0_quack
      def quack(_), do: :arity_1_quack

      def id(v), do: v

      definject bar(type) when is_atom(type) do
        case type do
          # Remote
          :mod -> __MODULE__.quack()
          :remote -> Enum.count([1, 2])
          :nested_remote -> DoubleNested.to_int("99")
          :pipe -> "1" |> Foo.id()
          :macro -> Calc.macro_sum(10, 20)
          :capture -> &Calc.sum/2
          :kernel_plus -> Kernel.+(1, 10)
          :string_to_atom -> "foobar" |> String.to_atom()
          :string_to_integer -> "100" |> String.to_integer()
          # Local, Import
          :local -> quack()
          :import -> first([10, 20])
        end
      end

      definject hash(<<data::binary>>) do
        :crypto.hash(:md5, <<data::binary>>)
      end
    end

    test "original works" do
      assert Foo.bar(:mod) == :arity_0_quack
      assert Foo.bar(:remote) == 2
      assert Foo.bar(:nested_remote) == 99
      assert Foo.bar(:pipe) == "1"
      assert Foo.bar(:macro) == 30
      assert Foo.bar(:capture).(20, 40) == 60
      assert Foo.bar(:kernel_plus) == 11
      assert Foo.bar(:string_to_atom) == :foobar
      assert Foo.bar(:string_to_integer) == 100

      assert Foo.bar(:local) == :arity_0_quack
      assert Foo.bar(:import) == 10

      assert Foo.hash("hello") ==
               <<93, 65, 64, 42, 188, 75, 42, 118, 185, 113, 157, 145, 16, 23, 197, 146>>
    end

    test "working case" do
      assert Foo.bar(:mod, %{&Foo.quack/0 => fn -> :injected end}) == :injected
      assert Foo.bar(:remote, %{&Enum.count/1 => fn _ -> 9999 end}) == 9999
      assert Foo.bar(:nested_remote, %{&DoubleNested.to_int/1 => fn _ -> 6 end}) == 6

      assert Foo.bar(:pipe, %{&Foo.id/1 => fn _ -> "100" end, &Enum.count/1 => fn _ -> 9999 end}) ==
               "100"

      assert Foo.bar(:macro, %{&Calc.sum/2 => fn _, _ -> 999 end, strict: false}) == 30
      assert Foo.bar(:string_to_atom, %{&String.to_atom/1 => fn _ -> :injected end}) == :injected

      assert Foo.hash("hello", %{&:crypto.hash/2 => fn _, _ -> :world end}) == :world
    end

    test "capture" do
      assert_raise RuntimeError, ~r(unused.*Foo.bar/1), fn ->
        Foo.bar(:capture, mock(%{&Calc.sum/2 => 100}))
      end

      assert Foo.bar(:capture, mock(%{&Calc.sum/2 => 100, strict: false})).(100, 200) == 300
    end

    test "unused" do
      assert_raise RuntimeError, ~r/unused/, fn ->
        Foo.bar(:remote, mock(%{&Enum.map/2 => 100}))
      end

      assert Foo.bar(:remote, mock(%{&Enum.map/2 => 100, strict: false})) == 2
    end

    test "local" do
      assert_raise RuntimeError, ~r/Local/, fn ->
        Foo.bar(:local, %{&quack/0 => fn -> nil end})
      end
    end

    test "uninjectable" do
      assert_raise RuntimeError, ~r/Uninjectable/, fn ->
        Foo.bar(:remote, %{&:erlang.+/2 => fn _ -> nil end})
      end

      assert_raise RuntimeError, ~r/Uninjectable/, fn ->
        Foo.bar(:remote, %{&Kernel.+/2 => fn _, _ -> 999 end})
      end

      assert_raise RuntimeError, ~r/Uninjectable/, fn ->
        Foo.bar(:remote, %{&String.to_integer/1 => fn _ -> 9090 end})
      end
    end
  end

  test "mock" do
    m = mock(%{&Enum.count/1 => (fn -> 100 end).(), &Enum.map/2 => 200, strict: false})

    assert m[:strict] == false

    f1 = m[&Enum.count/1]
    f2 = m[&Enum.map/2]

    assert :erlang.fun_info(f1)[:arity] == 1
    assert :erlang.fun_info(f2)[:arity] == 2

    assert f1.(nil) == 100
    assert f2.(nil, nil) == 200
  end
end
