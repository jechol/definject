defmodule Definject.Check do
  @moduledoc false

  @uninjectable [:erlang, Kernel]

  def validate_deps(%{} = deps, {used_captures, used_mods}, {mod, name, arity}) do
    outer_function = "#{mod}.#{name}/#{arity}"
    used_captures = used_captures |> Enum.sort() |> Enum.uniq()
    used_mods = used_mods |> Enum.sort() |> Enum.uniq()

    strict = Map.get(deps, :strict, true)
    dep_keys = deps |> Map.keys() |> Enum.uniq() |> List.delete(:strict)

    # dep_captures = dep_keys |> Map.filter(&is_function/1)
    # dep_mods = dep_keys |> Map.filter(&is_atom/1)

    if Application.get_env(:definject, :trace, false) do
      IO.puts(
        "Validating depedencies for #{dep_keys |> inspect} against #{
          {used_captures, used_mods} |> inspect
        }"
      )
    end

    for key <- dep_keys do
      with :ok <- validate_injectable(key),
           :ok <- validate_used(key, {used_captures, used_mods}, strict: strict) do
        :ok
      else
        {:error, {:uninjectable_local, function}} ->
          raise "Uninjectable local function #{function |> inspect}."

        {:error, {:uninjectable_module, module}} ->
          raise "Uninjectable module #{module |> inspect}. #{@uninjectable |> inspect} cannot be injected."

        {:error, {:unused, key}} ->
          raise "#{inspect(key)} is unused in #{outer_function}. Add `strict: false` to disable this."
      end
    end
  end

  defp validate_injectable(capture) when is_function(capture) do
    with :ok <- validate_type_is_external(capture) do
      {:module, mod} = :erlang.fun_info(capture, :module)
      validate_injectable(mod)
    end
  end

  defp validate_injectable(mod) when is_atom(mod) do
    if mod in @uninjectable do
      {:error, {:uninjectable_module, mod}}
    else
      :ok
    end
  end

  defp validate_type_is_external(capture) do
    case :erlang.fun_info(capture, :type) do
      {:type, :external} ->
        :ok

      {:type, :local} ->
        {:error, {:uninjectable_local, capture}}
    end
  end

  defp validate_used(_, _, strict: false) do
    :ok
  end

  defp validate_used(key, {used_captures, used_mods}, strict: true) do
    if key in (used_captures ++ used_mods) do
      :ok
    else
      {:error, {:unused, key}}
    end
  end
end
