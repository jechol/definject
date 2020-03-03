defmodule Definject.Check do
  @moduledoc false
  @uninjectable quote(do: [:erlang])

  def validate_deps(%{} = deps, used_captures, {mod, name, arity}) do
    if Application.get_env(:definject, :trace, false) do
      IO.puts("Validating #{deps |> inspect} against #{used_captures |> inspect}")
    end

    used_captures = used_captures |> Enum.sort() |> Enum.uniq()
    strict = Map.get(deps, :strict, true)
    injected_deps = Map.drop(deps, [:strict])

    for {capture, _} <- injected_deps do
      with :ok <- confirm_type_is_external(capture),
           :ok <- confirm_module_is_injectable(capture) do
        confirm_capture_is_used(capture, %{strict: strict, used_captures: used_captures})
      end
    end
  end

  defp confirm_type_is_external(capture) do
    case :erlang.fun_info(capture, :type) do
      {:type, :local} ->
        raise "Local function cannot be injected #{inspect(capture)}"

      {:type, :external} ->
        :ok
    end
  end

  defp confirm_module_is_injectable(capture) do
    case :erlang.fun_info(capture, :module) do
      {:module, module} when module in @uninjectable ->
        raise "Uninjectable module #{inspect(module)} for #{inspect(capture)}"

      {:module, _} ->
        :ok
    end
  end

  defp confirm_capture_is_used(_, %{strict: false}) do
    :ok
  end

  defp confirm_capture_is_used(capture, %{strict: true, used_captures: used_captures}) do
    if capture not in used_captures do
      raise "Unused injection found #{inspect(capture)}. Add `strict: false` to disable this."
    else
      :ok
    end
  end
end
