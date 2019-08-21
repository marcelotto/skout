defmodule Skout.YAML.Decoder do
  alias Skout.{Outline, Manifest}
  alias RDF.NS.SKOS

  def decode(yaml_string, opts) do
    with {:ok, map} <- parse_yaml(yaml_string) do
      build_outline(map, opts)
    end
  end

  defp parse_yaml(yaml_string) do
    YamlElixir.read_from_string(yaml_string)
  end

  defp build_outline(map, opts) do
    with {:ok, manifest} <- build_manifest(map, opts) do
      Outline.new(manifest)
      |> build_skos(map, opts)
    end
  end

  defp build_manifest(_map, opts) do
    {:ok, %Manifest{base_iri: Keyword.get(opts, :base_iri)}}
  end

  defp build_skos(outline, map, opts) do
    Enum.reduce_while(map, {:ok, outline}, fn
      {label, narrower_labels}, {:ok, outline} ->
        Enum.reduce_while(narrower_labels, {:ok, outline}, fn
          hierarchy, {:ok, outline} when is_map(hierarchy) ->
            [{narrower_label, next_level}] = Map.to_list(hierarchy)

            with {:ok, outline} <-
                   Outline.add(outline, {label, SKOS.narrower(), narrower_label}) do
              if next_level do
                build_skos(outline, hierarchy, opts)
              else
                outline
              end
              |> cont_or_halt()
            end

          narrower_label, {:ok, outline} ->
            outline
            |> Outline.add({label, SKOS.narrower(), narrower_label})
            |> cont_or_halt()
        end)
        |> cont_or_halt()
    end)
  end

  defp cont_or_halt(result) do
    case result do
      {:ok, outline} ->
        {:cont, {:ok, outline}}

      {:error, error} ->
        {:halt, {:error, error}}
    end
  end
end
