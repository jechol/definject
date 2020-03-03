defmodule DefInject.InjectTest do
  use ExUnit.Case, async: true
  require Definject.Inject
  alias Definject.Inject

  describe "head_with_deps" do
    test "with parenthesis" do
      head =
        quote do
          add(a, b)
        end

      expected_head =
        quote do
          add(a, b, %{} = deps \\ %{})
        end

      actual_head = Inject.head_with_deps(head)
      assert Macro.to_string(actual_head) == Macro.to_string(expected_head)
    end

    test "without parenthesis" do
      head =
        quote do
          add
        end

      expected_head =
        quote do
          add(%{} = deps \\ %{})
        end

      actual_head = Inject.head_with_deps(head)
      assert Macro.to_string(actual_head) == Macro.to_string(expected_head)
    end

    test "with when" do
      head =
        quote do
          add(a = 1, b) when (is_number(a) and is_number(b)) or is_string(a)
        end

      expected_head =
        quote do
          add(a = 1, b, %{} = deps \\ %{}) when (is_number(a) and is_number(b)) or is_string(a)
        end

      actual_head = Inject.head_with_deps(head)
      assert Macro.to_string(actual_head) == Macro.to_string(expected_head)
    end

    test "binary pattern matching" do
      head =
        quote do
          add(<<data::binary>>)
        end

      expected_head =
        quote do
          add(<<data::binary>>, %{} = deps \\ %{})
        end

      actual_head = Inject.head_with_deps(head)
      assert Macro.to_string(actual_head) == Macro.to_string(expected_head)
    end
  end

  describe "process_body_recursively" do
    test "capture is not expanded" do
      body =
        quote do
          &Calc.sum/2
        end

      expected_ast = body

      {:ok, {actual_ast, actual_captures}} = Inject.process_body_recusively(body, __ENV__)
      assert Macro.to_string(actual_ast) == Macro.to_string(expected_ast)
      assert actual_captures == []
    end

    test "indirect import is allowed" do
      require Calc

      body =
        quote do
          &Calc.sum/2
          Calc.macro_sum(10, 20)

          case 1 == 1 do
            x when x == true -> Math.pow(2, x)
          end
        end

      expected_ast =
        quote do
          &Calc.sum/2

          (
            import Calc
            sum(10, 20)
          )

          case 1 == 1 do
            x when x == true -> (deps[&Math.pow/2] || (&Math.pow/2)).(2, x)
          end
        end

      expected_captures = quote do: [&Math.pow/2]

      {:ok, {actual_ast, actual_captures}} = Inject.process_body_recusively(body, __ENV__)
      assert Macro.to_string(actual_ast) == Macro.to_string(expected_ast)
      assert Macro.to_string(actual_captures) == Macro.to_string(expected_captures)
    end

    test "direct import is not allowed" do
      body =
        quote do
          import Calc

          sum(a, b)
        end

      {:error, :modifier} = Inject.process_body_recusively(body, __ENV__)
    end

    test "operator case 1" do
      body =
        quote do
          Calc.to_int(a) >>> fn a_int -> Calc.to_int(b) >>> fn b_int -> a_int + b_int end end
        end

      expected_ast =
        quote do
          (deps[&Calc.to_int/1] || (&Calc.to_int/1)).(a) >>>
            fn
              a_int ->
                (deps[&Calc.to_int/1] || (&Calc.to_int/1)).(b) >>>
                  fn
                    b_int -> a_int + b_int
                  end
            end
        end

      expected_captures = [&Calc.to_int/1, &Calc.to_int/1]

      {:ok, {actual_ast, actual_captures}} = Inject.process_body_recusively(body, __ENV__)
      assert Macro.to_string(actual_ast) == Macro.to_string(expected_ast)
      assert Macro.to_string(actual_captures) == Macro.to_string(expected_captures)
    end

    test "operator case 2" do
      body =
        quote do
          Calc.to_int(a) >>> fn a_int -> (fn b_int -> a_int + b_int end).(Calc.to_int(b)) end
        end

      expected_ast =
        quote do
          (deps[&Calc.to_int/1] || (&Calc.to_int/1)).(a) >>>
            fn a_int ->
              (fn b_int ->
                 a_int + b_int
               end).((deps[&Calc.to_int/1] || (&Calc.to_int/1)).(b))
            end
        end

      expected_captures = [&Calc.to_int/1, &Calc.to_int/1]

      {:ok, {actual_ast, actual_captures}} = Inject.process_body_recusively(body, __ENV__)
      assert Macro.to_string(actual_ast) == Macro.to_string(expected_ast)
      assert Macro.to_string(actual_captures) == Macro.to_string(expected_captures)
    end
  end

  test "inject_function" do
    {:definject, _, [head, [do: body]]} =
      quote do
        definject add(a, b) do
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

    actual = Inject.inject_function(%{head: head, body: body, env: env_with_macros()})
    assert Macro.to_string(actual) == Macro.to_string(expected)
  end

  defp env_with_macros do
    import Calc
    macro_sum(1, 2)
    __ENV__
  end
end
