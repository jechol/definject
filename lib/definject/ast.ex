defmodule Definject.AST do
  @moduledoc false

  def unquote_alias({:__aliases__, [alias: false], atoms}) do
    atoms |> Module.concat()
  end

  def unquote_alias({:__aliases__, [alias: mod], _atoms}) do
    mod
  end

  def unquote_alias({:__aliases__, _, atoms}) do
    atoms |> Module.concat()
  end

  def unquote_alias(atom) when is_atom(atom) do
    atom
  end

  def quote_function_capture({mod, name, arity}) do
    mf = {{:., [], [mod, name]}, [], []}
    mfa = {:/, [], [mf, arity]}
    {:&, [], [mfa]}
  end
end
