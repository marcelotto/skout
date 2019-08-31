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
    |> MapSet.new()
    |> concepts(outline, 0, MapSet.new(), opts)
  end

  defp concepts(concepts, outline, depth, visited, opts) do
    if MapSet.disjoint?(visited, concepts) do
      concepts
      |> Enum.map(fn concept -> concept(concept, outline, depth, visited, opts) end)
      |> Enum.join(indentation(depth))
    else
      raise "concept scheme contains a circle through #{
              inspect(MapSet.intersection(concepts, visited) |> MapSet.to_list())
            }"
    end
  end

  defp concept(concept, outline, depth, visited, opts) do
    description = Graph.description(outline.skos, concept)

    label =
      Description.get(description, SKOS.prefLabel())
      |> case do
        nil -> raise "Missing label for concept #{concept}"
        [label] -> to_string(label)
      end

    label <>
      ":\n" <>
      (concept
       |> narrower_concepts(outline.skos)
       |> MapSet.new()
       |> concepts(outline, depth + 1, MapSet.put(visited, concept), opts)
       |> case do
         "" -> ""
         next_level -> indentation(depth + 1) <> next_level
       end)
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
