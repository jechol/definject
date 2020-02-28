defmodule InjectImplTest do
  use ExUnit.Case, async: true
  use Inject

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
          add(a, b, %{} = deps)
        end

      actual_head = Inject.head_with_deps(%{head: head, env: __ENV__})
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
          add(%{} = deps)
        end

      actual_head = Inject.head_with_deps(%{head: head, env: __ENV__})
      assert Macro.to_string(actual_head) == Macro.to_string(expected_head)
    end
  end

  test "inject_remote_call" do
    remote_call =
      quote do
        Math.pow(2, x)
      end

    expected_ast =
      quote do
        (deps[{Math, :pow, 2}] || &Math.pow/2).(2, x)
      end

    expected = %{
      ast: expected_ast,
      mfas: [{{:__aliases__, [alias: false], [:Math]}, :pow, 2}]
    }

    %{ast: actual_ast, mfas: actual_mfas} = Inject.inject_remote_call(remote_call)
    assert Macro.to_string(actual_ast) == Macro.to_string(expected.ast)
    assert actual_mfas == expected.mfas
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

      actual = Inject.inject_function(%{head: head, body: body, env: __ENV__})
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
          def add(a, b, %{} = deps) do
            Inject.Check.raise_if_uninjectable_deps_injected(deps)
            Inject.Check.raise_if_unknown_deps_found([{Calc, :sum, 2}], deps)

            case a do
              false ->
                (deps[{Calc, :sum, 2}] || &Calc.sum/2).(a, b)

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
end
