defmodule Definject.Check do
  @moduledoc false

  @uninjectable [:erlang, Kernel]

  def validate_deps(%{} = deps, used_captures, {mod, name, arity}) do
    if Application.get_env(:definject, :trace, false) do
      IO.puts("Validating #{deps |> inspect} against #{used_captures |> inspect}")
    end

    used_captures = used_captures |> Enum.sort() |> Enum.uniq()
    strict = Map.get(deps, :strict, true)
    injected_deps = Map.drop(deps, [:strict])

    for {capture, _} <- injected_deps do
      with :ok <- confirm_type_is_external(capture),
           :ok <- confirm_module_is_injectable(capture),
           :ok <- confirm_capture_is_used(capture, used_captures, strict) do
        :ok
      else
        {:error, :local} ->
          raise "Local function #{inspect(capture)} cannot be injected "

        {:error, {:uninjectable, module}} ->
          raise "Uninjectable module #{module} for #{inspect(capture)}"

        {:error, :unused} ->
          raise "#{inspect(capture)} is unused in #{mod}.#{name}/#{arity}. Add `strict: false` to disable this."
      end
    end
  end

  defp confirm_type_is_external(capture) do
    case :erlang.fun_info(capture, :type) do
      {:type, :external} ->
        :ok

      {:type, :local} ->
        {:error, :local}
    end
  end

  defp confirm_module_is_injectable(capture) do
    case :erlang.fun_info(capture, :module) do
      {:module, module} when module in @uninjectable ->
        {:error, {:uninjectable, module}}

      {:module, _} ->
        :ok
    end
  end

  defp confirm_capture_is_used(capture, used_captures, strict) do
    if not strict or capture in used_captures do
      :ok
    else
      {:error, :unused}
    end
  end
end
