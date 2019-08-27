defmodule Skout.YAML.Encoder do
  alias RDF.NS.SKOS
  alias RDF.{Graph, Description}

  def encode(outline, opts \\ []) do
    {:ok,
     """
     #{preamble(outline, opts) |> String.trim()}
     ---
     #{body(outline, opts)}
     """}
  end

  def preamble(outline, _opts) do
    outline.manifest
    |> Map.from_struct()
    |> Enum.reject(fn {key, value} -> is_nil(value) or key in [:materialization] end)
    |> Enum.map(fn {key, value} ->
      """
      #{to_string(key)}: #{value}
      """
    end)
    |> Enum.join()
  end

  def body(outline, opts) do
    outline
    |> Skout.Materialization.top_concepts()
    |> concept_hierarchy(outline, 0, opts)
  end

  defp concept_hierarchy(concepts, outline, depth, opts) do
    concepts
    |> Enum.map(fn concept ->
      description = Graph.description(outline.skos, concept)

      (Description.get(description, SKOS.prefLabel()) |> List.first() |> to_string()) <>
        ":\n" <>
        (concept
         |> narrower_concepts(outline.skos)
         |> concept_hierarchy(outline, depth + 1, opts)
         |> case do
           "" -> ""
           next_level -> indentation(depth + 1) <> next_level
         end)
    end)
    |> Enum.join(indentation(depth))
  end

  defp narrower_concepts(concept, graph) do
    graph
    |> SPARQL.execute_query(
      """
      SELECT ?concept WHERE {
        <#{concept}> skos:narrower ?concept .
      }
      """,
      default_prefixes: %{skos: SKOS}
    )
    |> SPARQL.Query.Result.get(:concept)
    |> List.wrap()
  end

  defp indentation(0), do: ""
  defp indentation(depth), do: String.duplicate("  ", depth - 1) <> "- "
end
