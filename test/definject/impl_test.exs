defmodule InjectImplTest do
  use ExUnit.Case, async: true
  require Definject.Impl
  alias Definject.Impl

  describe "head_with_deps" do
    test "with parenthesis" do
      {:definject, _, [head, _]} =
        quote do
          definject add(a, b) do
            nil
          end
        end

      expected_head =
        quote do
          add(a, b, %{} = deps \\ %{})
        end

      actual_head = Impl.head_with_deps(%{head: head, env: __ENV__})
      assert Macro.to_string(actual_head) == Macro.to_string(expected_head)
    end

    test "without parenthesis" do
      {:definject, _, [head, _]} =
        quote do
          definject add do
            nil
          end
        end

      expected_head =
        quote do
          add(%{} = deps \\ %{})
        end

      actual_head = Impl.head_with_deps(%{head: head, env: __ENV__})
      assert Macro.to_string(actual_head) == Macro.to_string(expected_head)
    end
  end

  # test "when remote capture" do
  #   {:&, _,
  #    [
  #      {:/, _,
  #       [
  #         {{:., _, [_remote_mod, :pow]}, _, []} = remote_call_wo_parens,
  #         2
  #       ]}
  #    ]} =
  #     quote do
  #       &Math.pow/2
  #     end

  #   %{ast: actual_ast, captures: actual_captures} =
  #     Impl.inject_remote_call(remote_call_wo_parens)

  #   assert Macro.to_string(actual_ast) == "Math.pow"
  #   assert actual_captures == []
  # end

  test "expand_macros_recursively" do
    require Calc

    body =
      quote do
        Calc.macro_sum(10, 20)
      end

    expected_body =
      quote do
        import Calc
        sum(10, 20)
      end

    actual_ast = Impl.expand_macros_recursively(body, __ENV__)
    assert Macro.to_string(actual_ast) == Macro.to_string(expected_body)
  end

  test "inject_remote_calls_recursively" do
    body =
      quote do
        Math.pow(2, x)
      end

    expected_ast =
      quote do
        (deps[&Math.pow/2] || (&Math.pow/2)).(2, x)
      end

    expected_captures =
      quote do
        [&Math.pow/2]
      end

    {actual_ast, actual_captures} = Impl.inject_remote_calls_recursively(body)
    assert Macro.to_string(actual_ast) == Macro.to_string(expected_ast)
    assert Macro.to_string(actual_captures) == Macro.to_string(expected_captures)
  end

  test "remove_nested_captures_recursively" do
    body =
      quote do
        a = &Calc.sum/2
        b = String.to_integer("string")
        c = Calc.sum()
      end

    # Elixir formatter makes it hard to build wrong AST with `quote`. So keep this as string.
    expected_after_inject =
      "(\n  a = &(deps[&Calc.sum/0] || &Calc.sum/0.() / 2)\n  b = deps[&String.to_integer/1] || &String.to_integer/1.(\"string\")\n  c = deps[&Calc.sum/0] || &Calc.sum/0.()\n)"

    {actual_after_inject, captures} = Impl.inject_remote_calls_recursively(body)

    assert Macro.to_string(actual_after_inject) == expected_after_inject

    # Remove nested captures.

    expected_after_remove_nest =
      quote do
        a = &Calc.sum/2
        b = (deps[&String.to_integer/1] || (&String.to_integer/1)).("string")
        c = (deps[&Calc.sum/0] || (&Calc.sum/0)).()
      end

    {actual_after_remove_nest, nested_captures} =
      Impl.remove_nested_captures_recursively(actual_after_inject)

    assert Macro.to_string(actual_after_remove_nest) ==
             Macro.to_string(expected_after_remove_nest)

    assert captures |> Enum.count() == 3
    assert nested_captures |> Enum.count() == 1
    assert Enum.count(captures -- nested_captures) == 2
  end

  describe "import in definject" do
    test "direct import is not allowed" do
      {:def, _, [head, [do: body]]} =
        quote do
          def add(a, b) do
            import Calc

            sum(a, b)
          end
        end

      expected =
        quote do
          raise "Cannot import/require/use inside definject. Move it to module level."
        end

      actual = Impl.inject_function(%{head: head, body: body, env: __ENV__})
      assert Macro.to_string(actual) == Macro.to_string(expected)
    end

    test "import in expanded macro is allowed" do
      {:def, _, [head, [do: body]]} =
        quote do
          def add(a, b) do
            case a do
              false -> Calc.sum(a, b)
              true -> Calc.macro_sum(a, b)
            end
          end
        end

      expected =
        quote do
          def add(a, b, %{} = deps \\ %{}) do
            Definject.Check.validate_deps([&Calc.sum/2], deps)

            case a do
              false ->
                (deps[&Calc.sum/2] || (&Calc.sum/2)).(a, b)

              true ->
                import Calc
                sum(a, b)
            end
          end
        end

      actual = Impl.inject_function(%{head: head, body: body, env: env_with_macros()})
      assert Macro.to_string(actual) == Macro.to_string(expected)
    end

    defp env_with_macros do
      import Calc
      macro_sum(1, 2)
      __ENV__
    end
  end
end
