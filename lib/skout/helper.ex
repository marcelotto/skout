defmodule Skout.Helper do
  @moduledoc false

  def atomize_keys(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      other -> other
    end)
  end

  def cont_or_halt(result) do
    case result do
      {:ok, document} ->
        {:cont, {:ok, document}}

      {:ok, _, document} ->
        {:cont, {:ok, document}}

      {:error, error} ->
        {:halt, {:error, error}}
    end
  end

  def properties(mod) do
    :functions
    |> mod.__info__()
    |> Enum.filter(fn {fun, arity} ->
      arity == 0 and not (fun |> to_string() |> String.starts_with?("_"))
    end)
    |> Enum.map(fn {fun, _} -> fun end)
  end
end
