defmodule DefinjectTest do
  use ExUnit.Case, async: true
  import Definject

  defmodule Nested do
    defmodule DoubleNested do
      defdelegate to_int(str), to: String, as: :to_integer
      defdelegate to_atom(str), to: String, as: :to_atom
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
          :nested_remote -> {DoubleNested.to_int("99"), DoubleNested.to_atom("hello")}
          :pipe -> "1" |> Foo.id()
          :macro -> Calc.macro_sum(10, 20)
          :capture -> &Calc.sum/2
          :kernel_plus -> Kernel.+(1, 10)
          :string_to_atom -> "foobar" |> String.to_atom()
          :string_to_integer -> "100" |> String.to_integer()
          # Local, Import
          :local -> quack()
          :import -> first([10, 20])
          :anonymous_fun -> [1, 2] |> Enum.map(&Calc.id(&1))
          :string_concat -> "#{[1, 2] |> Enum.map(&"*#{&1}*") |> Enum.join()}"
        end
      end

      definject hash(<<data::binary>>) do
        :crypto.hash(:md5, <<data::binary>>)
      end
    end

    test "original works" do
      assert Foo.bar(:mod) == :arity_0_quack
      assert Foo.bar(:remote) == 2
      assert Foo.bar(:nested_remote) == {99, :hello}
      assert Foo.bar(:pipe) == "1"
      assert Foo.bar(:macro) == 30
      assert Foo.bar(:capture).(20, 40) == 60
      assert Foo.bar(:kernel_plus) == 11
      assert Foo.bar(:string_to_atom) == :foobar
      assert Foo.bar(:string_to_integer) == 100

      assert Foo.bar(:local) == :arity_0_quack
      assert Foo.bar(:import) == 10
      assert Foo.bar(:anonymous_fun) == [1, 2]
      assert Foo.bar(:string_concat) == "*1**2*"

      assert Foo.hash("hello") ==
               <<93, 65, 64, 42, 188, 75, 42, 118, 185, 113, 157, 145, 16, 23, 197, 146>>
    end

    defmodule Baz do
      def quack, do: "baz quack"
      def to_int(_), do: "baz to_int"
      def to_atom(_), do: "baz to_atom"
    end

    test "working case" do
      assert Foo.bar(:mod, %{&Foo.quack/0 => fn -> :injected end}) == :injected
      assert Foo.bar(:mod, %{Foo => Baz}) == "baz quack"
      assert Foo.bar(:remote, %{&Enum.count/1 => fn _ -> 9999 end}) == 9999

      assert Foo.bar(:nested_remote, %{
               &DoubleNested.to_int/1 => &Baz.to_int/1,
               &DoubleNested.to_atom/1 => &Baz.to_atom/1
             }) == {"baz to_int", "baz to_atom"}

      assert Foo.bar(:nested_remote, %{DoubleNested => Baz}) == {"baz to_int", "baz to_atom"}

      assert Foo.bar(
               :nested_remote,
               mock(%{DoubleNested => Baz, &DoubleNested.to_atom/1 => :mocked})
             ) == {"baz to_int", :mocked}

      assert Foo.bar(:pipe, %{&Foo.id/1 => fn _ -> "100" end, &Enum.count/1 => fn _ -> 9999 end}) ==
               "100"

      assert Foo.bar(:macro, %{&Calc.sum/2 => fn _, _ -> 999 end, strict: false}) == 30
      assert Foo.bar(:string_to_atom, %{&String.to_atom/1 => fn _ -> :injected end}) == :injected

      assert Foo.hash("hello", %{&:crypto.hash/2 => fn _, _ -> :world end}) == :world
    end

    test "should skip capture" do
      assert_raise RuntimeError, ~r(Calc.sum/2.*unused.*Foo.bar/1), fn ->
        Foo.bar(:capture, mock(%{&Calc.sum/2 => 100}))
      end

      assert Foo.bar(:capture, mock(%{&Calc.sum/2 => 100, strict: false})).(100, 200) == 300
    end

    test "should skip anonymous function" do
      assert_raise RuntimeError, ~r(Calc.id/1.*unused.*Foo.bar/1), fn ->
        Foo.bar(:anonymous_fun, %{&Calc.id/1 => fn _ -> 100 end})
      end
    end

    test "unused module" do
      assert_raise RuntimeError, ~r/UnusedModule is unused in.*Foo.bar/, fn ->
        Foo.bar(:remote, mock(%{UnusedModule => Baz}))
      end

      assert Foo.bar(:remote, mock(%{UnusedModule => Baz, strict: false})) == 2
    end

    test "uninjectable module" do
      assert_raise RuntimeError, ~r/Uninjectable module Kernel/, fn ->
        Foo.bar(:remote, mock(%{Kernel => Baz}))
      end

      assert_raise RuntimeError, ~r/Uninjectable module :erlang/, fn ->
        Foo.bar(:remote, mock(%{:erlang => Baz}))
      end
    end

    test "unused function" do
      assert_raise RuntimeError, ~r/unused/, fn ->
        Foo.bar(:remote, mock(%{&Enum.min_max_by/3 => 100}))
      end

      assert Foo.bar(:remote, mock(%{&Enum.map/2 => 100, strict: false})) == 2
    end

    test "uninjectable module for function" do
      assert_raise RuntimeError, ~r(Uninjectable module :erlang), fn ->
        Foo.bar(:_, %{&:erlang.+/2 => fn _ -> nil end})
      end

      assert_raise RuntimeError, ~r(Uninjectable module :erlang), fn ->
        Foo.bar(:_, %{&Kernel.+/2 => fn _, _ -> 999 end})
      end

      assert_raise RuntimeError, ~r(Uninjectable module :erlang), fn ->
        Foo.bar(:_, %{&String.to_integer/1 => fn _ -> 9090 end})
      end

      assert_raise RuntimeError, ~r/Uninjectable local function/, fn ->
        Foo.bar(:_, %{&quack/0 => fn -> nil end})
      end
    end

    test "type mismatch" do
      assert_raise RuntimeError, ~r(Type mismatches), fn ->
        Foo.bar(:_, %{&Foo.id/1 => Foo})
      end

      assert_raise RuntimeError, ~r(Type mismatches), fn ->
        Foo.bar(:_, %{Foo => &Foo.id/1})
      end
    end

    test "function arity mismatch" do
      assert_raise RuntimeError, ~r(Function arity mismatches), fn ->
        Foo.bar(:_, %{&Foo.id/1 => fn -> nil end})
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
