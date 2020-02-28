defmodule Inject.Check do
  @moduledoc false
  @uninjectable [:erlang, Kernel, Macro, Module, Access]

  def raise_if_uninjectable_deps_injected(%{} = deps) do
    for {{remote_mod, _name, _arity}, _} <- Map.drop(deps, [:strict]) do
      if remote_mod in unquote(@uninjectable) do
        raise "Uninjectable module injected #{inspect(remote_mod)}"
      end
    end
  end

  def raise_if_unknown_deps_found(mfas, %{} = deps) when is_list(mfas) do
    mfas = mfas |> Enum.sort() |> Enum.uniq()

    if Map.get(deps, :strict, true) do
      for {key, _} <- Map.drop(deps, [:strict]) do
        unless key in mfas do
          raise "Unexpected injection #{inspect(key)}"
        end
      end
    end
  end
end
