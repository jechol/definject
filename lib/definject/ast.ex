defmodule Definject.AST do
  @moduledoc false

  def is_module_ast({:__aliases__, _, _}), do: true
  def is_module_ast(atom) when is_atom(atom), do: true
  def is_module_ast(_), do: false

  def unquote_module_ast({:__aliases__, [alias: false], atoms}) do
    atoms |> Module.concat()
  end

  def unquote_module_ast({:__aliases__, [alias: mod], _atoms}) do
    mod
  end

  def unquote_module_ast({:__aliases__, _, atoms}) do
    atoms |> Module.concat()
  end

  def unquote_module_ast(atom) when is_atom(atom) do
    atom
  end

  def quote_function_capture({mod, name, arity}) do
    mf = {{:., [], [mod, name]}, [], []}
    mfa = {:/, [], [mf, arity]}
    {:&, [], [mfa]}
  end

  def unquote_function_capture({:&, _, [{:/, _, [{{:., _, [mod, name]}, _, _}, arity]}]}) do
    mod = unquote_module_ast(mod)
    :erlang.make_fun(mod, name, arity)
  end

  defmodule Param do
    @moduledoc false

    defmodule Pattern do
      @moduledoc false

      def get_var_name({name, _, module} = param, _index)
          when is_atom(name) and is_atom(module) do
        param
      end

      def get_var_name({:=, _, [{name, _, module} = param, _right_pattern]}, _index)
          when is_atom(name) and is_atom(module) do
        param
      end

      def get_var_name({:=, _, [_left_pattern, {name, _, module} = param]}, _index)
          when is_atom(name) and is_atom(module) do
        param
      end

      def get_var_name({:=, _, [_left_pattern, {:=, _, _} = nested_pattern]}, index) do
        get_var_name(nested_pattern, index)
      end

      def get_var_name(_param, index) do
        {:"var#{index}", [], nil}
      end
    end

    # for head

    def remove_pattern({:\\, ctx, [pattern, value]}, index) do
      {:\\, ctx, [Pattern.get_var_name(pattern, index), value]}
    end

    def remove_pattern(param, index) do
      Pattern.get_var_name(param, index)
    end

    # for clause

    def remove_default({:\\, _, [param, _default]}) do
      param
    end

    def remove_default(param) do
      param
    end
  end
end
