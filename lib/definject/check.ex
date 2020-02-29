defmodule Definject.Check do
  @moduledoc false
  @uninjectable [:erlang, Kernel, Macro, Module, Access]

  def validate_deps(valid_captures, %{} = deps) do
    valid_captures = valid_captures |> Enum.sort() |> Enum.uniq()

    for {capture, _} <- Map.drop(deps, [:strict]) do
      {:type, type} = Function.info(capture, :type)

      if type == :local do
        raise "Local function cannot be injected #{inspect(capture)}"
      else
        {:module, remote_mod} = Function.info(capture, :module)

        if remote_mod in unquote(@uninjectable) do
          raise "Uninjectable module #{inspect(remote_mod)} for #{inspect(capture)}"
        else
          if Map.get(deps, :strict, true) do
            unless capture in valid_captures do
              raise "Unused injection found #{inspect(capture)}. Add `strict: false` to disable this."
            end
          end
        end
      end
    end
  end
end
