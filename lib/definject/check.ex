defmodule Definject.Check do
  @moduledoc false

  @uninjectable [:erlang, Kernel, Kernel.Utils]

  def validate_deps(deps, {used_captures, used_mods}, {mod, name, arity}) do
    outer_function = "#{mod}.#{name}/#{arity}"
    used_captures = used_captures |> Enum.uniq()
    used_mods = used_mods |> Enum.uniq()

    strict = Map.get(deps, :strict, true)
    deps = deps |> Map.drop([:strict])

    if Application.get_env(:definject, :trace, false) do
      IO.puts(
        "Validating depedencies for #{deps |> Map.keys() |> inspect} against #{
          {used_captures, used_mods} |> inspect
        }"
      )
    end

    for {key, value} <- deps do
      with :ok <- validate_injectable_function_or_module(key),
           :ok <- validate_used(key, {used_captures, used_mods}, strict: strict),
           :ok <- validate_same_type(key, value),
           :ok <- validate_same_arity(key, value) do
        :ok
      else
        {:error, {:uninjectable_local, function}} ->
          raise "Uninjectable local function #{function |> inspect}."

        {:error, {:uninjectable_module, module}} ->
          raise "Uninjectable module #{module |> inspect}. #{@uninjectable |> inspect} cannot be injected."

        {:error, {:unused, key}} ->
          raise "#{inspect(key)} is unused in #{outer_function}. Add `strict: false` to disable this."

        {:error, :type_mismatch} ->
          raise "Type mismatches between #{inspect(key)} and #{inspect(value)}."

        {:error, :arity_mismatch} ->
          raise "Function arity mismatches between #{inspect(key)} and #{inspect(value)}."
      end
    end
  end

  defp validate_injectable_function_or_module(fun = mod) do
    cond do
      is_function(fun) -> validate_injectable_function(fun)
      is_atom(mod) -> validate_injectable_module(mod)
    end
  end

  defp validate_injectable_function(fun) when is_function(fun) do
    with :ok <- validate_type_is_external(fun) do
      {:module, mod} = :erlang.fun_info(fun, :module)
      validate_injectable_module(mod)
    end
  end

  defp validate_injectable_module(mod) when is_atom(mod) do
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

  defp validate_same_type(f1, f2) when is_function(f1) and is_function(f2), do: :ok
  defp validate_same_type(m1, m2) when is_atom(m1) and is_atom(m2), do: :ok
  defp validate_same_type(_, _), do: {:error, :type_mismatch}

  defp validate_same_arity(m1, m2) when is_atom(m1) and is_atom(m2), do: :ok

  defp validate_same_arity(f1, f2) when is_function(f1) and is_function(f2) do
    {:arity, a1} = :erlang.fun_info(f1, :arity)
    {:arity, a2} = :erlang.fun_info(f2, :arity)

    if a1 == a2 do
      :ok
    else
      {:error, :arity_mismatch}
    end
  end
end
