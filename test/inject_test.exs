defmodule InjectTest do
  use ExUnit.Case, async: true
  use Inject

  describe "definject use cases" do
    defmodule Foo do
      import List, only: [first: 1]
      require Calc

      def quack(), do: :arity_0_quack
      def quack(_), do: :arity_1_quack

      definject bar(type) do
        case type do
          :local -> quack()
          :mod -> __MODULE__.quack()
          :remote -> Enum.count([1, 2])
          :import -> first([10, 20])
          :pipe -> "1" |> String.to_integer() |> Kernel.+(1)
          :macro -> Calc.macro_sum(10, 20)
        end
      end
    end

    test "original works" do
      assert Foo.bar(:local) == :arity_0_quack
      assert Foo.bar(:mod) == :arity_0_quack
      assert Foo.bar(:remote) == 2
      assert Foo.bar(:import) == 10
      assert Foo.bar(:pipe) == 2
      assert Foo.bar(:macro) == 30
    end

    test "injected works" do
      assert Foo.bar(:mod, %{{Foo, :quack, 0} => fn -> :injected end}) == :injected

      assert Foo.bar(:mod, %{{Foo, :quack, 1} => fn -> :injected end, strict: false}) ==
               :arity_0_quack

      assert Foo.bar(:remote, %{{Enum, :count, 1} => fn _ -> 9999 end}) == 9999
      assert Foo.bar(:pipe, %{{String, :to_integer, 1} => fn _ -> 100 end}) == 101

      assert_raise RuntimeError, ~r/Uninjectable/, fn ->
        Foo.bar(:pipe, %{{Kernel, :+, 2} => fn _, _ -> 999 end})
      end

      assert_raise RuntimeError, ~r/Unexpected/, fn ->
        Foo.bar(:pipe, %{{Hello, :world, 0} => fn -> :wrong_key end})
      end

      assert Foo.bar(:pipe, %{{Hello, :world, 0} => fn -> :wrong_key end, strict: false}) == 2

      assert Foo.bar(:macro, %{{Calc, :sum, 2} => fn _, _ -> 999 end, strict: false}) == 30
    end
  end

  test "mock" do
    assert %{{A, :a, 0} => f1, {B, :b, 1} => f2} =
             mock(%{&A.a/0 => (fn -> 100 end).(), &B.b/1 => 200})

    assert :erlang.fun_info(f1)[:arity] == 0
    assert :erlang.fun_info(f2)[:arity] == 1

    assert f1.() == 100
    assert f2.(:not_used) == 200
  end
end
