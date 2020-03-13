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

  def remove_pattern_matching({:=, _, [{name, _, module} = param, _pattern]})
      when is_atom(name) and is_atom(module) do
    param
  end

  def remove_pattern_matching({:=, _, [_pattern, next_pattern]}) do
    remove_pattern_matching(next_pattern)
  end

  def remove_pattern_matching(param) do
    param |> IO.inspect()
  end

  def remove_default_value({:\\, _, [param, _default]}) do
    param
  end

  def remove_default_value(param) do
    param
  end
end
