defmodule Definject.InjectTest do
  use ExUnit.Case, async: true
  require Definject.Inject
  alias Definject.Inject
  alias Definject.AST

  describe "call_for_clause" do
    test "with parenthesis" do
      head =
        quote do
          add(a, b)
        end

      exp_head =
        quote do
          add(a, b, deps)
        end

      actual_head = Inject.call_for_clause(head)
      assert Macro.to_string(actual_head) == Macro.to_string(exp_head)
    end

    test "without parenthesis" do
      head =
        quote do
          add
        end

      exp_head =
        quote do
          add(deps)
        end

      actual_head = Inject.call_for_clause(head)
      assert Macro.to_string(actual_head) == Macro.to_string(exp_head)
    end

    test "with when" do
      head =
        quote do
          add(a = 1, b) when (is_number(a) and is_number(b)) or is_string(a)
        end

      exp_head =
        quote do
          add(a = 1, b, deps) when (is_number(a) and is_number(b)) or is_string(a)
        end

      actual_head = Inject.call_for_clause(head)
      assert Macro.to_string(actual_head) == Macro.to_string(exp_head)
    end

    test "binary pattern matching" do
      head =
        quote do
          add(<<data::binary>>)
        end

      exp_head =
        quote do
          add(<<data::binary>>, deps)
        end

      actual_head = Inject.call_for_clause(head)
      assert Macro.to_string(actual_head) == Macro.to_string(exp_head)
    end
  end

  describe "process_body_recursively" do
    test "capture is not expanded" do
      body =
        quote do
          &Calc.sum/2
        end

      {:ok, actual} = Inject.process_body_recusively(body, __ENV__)
      assert_inject(actual, {body, [], []})
    end

    test "access is not expanded" do
      body =
        quote do
          conn.assigns
        end

      {:ok, actual} = Inject.process_body_recusively(body, __ENV__)
      assert_inject(actual, {body, [], []})
    end

    test ":erlang is not expanded" do
      body =
        quote do
          :erlang.+(100, 200)
          Kernel.+(100, 200)
        end

      {:ok, actual} = Inject.process_body_recusively(body, __ENV__)
      assert_inject(actual, {body, [], []})
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

      exp_ast =
        quote do
          &Calc.sum/2

          (
            import(Calc)
            sum(10, 20)
          )

          case 1 == 1 do
            x when x == true ->
              Map.get(deps, &Math.pow/2, :erlang.make_fun(Map.get(deps, Math, Math), :pow, 2)).(
                2,
                x
              )
          end
        end

      {:ok, actual} = Inject.process_body_recusively(body, __ENV__)
      assert_inject(actual, {exp_ast, [&Math.pow/2], [Math]})
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

      exp_ast =
        quote do
          Map.get(deps, &Calc.to_int/1, :erlang.make_fun(Map.get(deps, Calc, Calc), :to_int, 1)).(
            a
          ) >>>
            fn a_int ->
              Map.get(
                deps,
                &Calc.to_int/1,
                :erlang.make_fun(Map.get(deps, Calc, Calc), :to_int, 1)
              ).(b) >>> fn b_int -> a_int + b_int end
            end
        end

      {:ok, actual} = Inject.process_body_recusively(body, __ENV__)
      assert_inject(actual, {exp_ast, [&Calc.to_int/1, &Calc.to_int/1], [Calc, Calc]})
    end

    test "operator case 2" do
      body =
        quote do
          Calc.to_int(a) >>> fn a_int -> (fn b_int -> a_int + b_int end).(Calc.to_int(b)) end
        end

      exp_ast =
        quote do
          Map.get(deps, &Calc.to_int/1, :erlang.make_fun(Map.get(deps, Calc, Calc), :to_int, 1)).(
            a
          ) >>>
            fn a_int ->
              (fn b_int -> a_int + b_int end).(
                Map.get(
                  deps,
                  &Calc.to_int/1,
                  :erlang.make_fun(Map.get(deps, Calc, Calc), :to_int, 1)
                ).(b)
              )
            end
        end

      {:ok, actual} = Inject.process_body_recusively(body, __ENV__)
      assert_inject(actual, {exp_ast, [&Calc.to_int/1, &Calc.to_int/1], [Calc, Calc]})
    end
  end

  describe "inject_function" do
    test "success case" do
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
          Module.register_attribute(__MODULE__, :definjected, accumulate: true)

          unless {:add, 2} in Module.get_attribute(__MODULE__, :definjected) do
            def add(a, b, deps \\ %{})
            @definjected {:add, 2}
          end

          def add(a, b, deps) do
            Definject.Check.validate_deps(
              deps,
              {[&Calc.sum/2], [Calc]},
              {Definject.InjectTest, :add, 2}
            )

            case a do
              false ->
                Map.get(deps, &Calc.sum/2, :erlang.make_fun(Map.get(deps, Calc, Calc), :sum, 2)).(
                  a,
                  b
                )

              true ->
                import Calc
                sum(a, b)
            end
          end
        end

      actual = Inject.inject_function(head, body, env_with_macros())
      assert Macro.to_string(actual) == Macro.to_string(expected)
    end

    test "Compile error case" do
      assert_raise CompileError, ~r(import/require/use), fn ->
        :code.priv_dir(:definject)
        |> Path.join("import_in_inject.ex")
        |> Code.eval_file()
      end
    end
  end

  defp env_with_macros do
    import Calc
    macro_sum(1, 2)
    __ENV__
  end

  defp assert_inject({ast, captures_ast, mods}, {exp_ast, exp_captures, exp_mods}) do
    assert Macro.to_string(ast) == Macro.to_string(exp_ast)
    assert captures_ast |> Enum.map(&AST.unquote_function_capture/1) == exp_captures
    assert mods == exp_mods
  end
end
