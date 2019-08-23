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
      {:ok, outline} ->
        {:cont, {:ok, outline}}

      {:error, error} ->
        {:halt, {:error, error}}
    end
  end
end
