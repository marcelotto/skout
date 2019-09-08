defmodule Skout.RDF.Import do
  alias Skout.Document
  alias RDF.NS.SKOS

  def call(graph, opts \\ []) do
    with {:ok, concept_scheme} <- determine_concept_scheme(graph, opts),
         concepts = concepts(graph, concept_scheme),
         {:ok, base_iri} <- determine_base_iri(concepts, opts),
         {:ok, document} <-
           Document.new(
             opts
             |> Keyword.put(:concept_scheme, concept_scheme)
             |> Keyword.put(:base_iri, base_iri)
           ),
         {:ok, document} <- extract_skos(graph, concepts, document) do
      {:ok, document}
    end
  end

  def call!(graph, opts \\ []) do
    case call(graph, opts) do
      {:ok, document} -> document
      {:error, error} -> raise error
    end
  end

  defp extract_skos(graph, concepts, document) do
    Document.add(
      document,
      Enum.reduce(graph.descriptions, [], fn {subject, description}, triples ->
        if subject in concepts do
          triples ++ RDF.Description.triples(description)
        else
          triples
        end
      end)
    )
  end

  defp concepts(graph, _concept_scheme) do
    graph
    |> SPARQL.execute_query(
      """
      SELECT DISTINCT ?concept WHERE {
        { ?concept a skos:Concept . }
        UNION { ?concept skos:related ?other_concept . }
        UNION { ?concept skos:broader ?other_concept . }
        UNION { ?concept skos:narrower ?other_concept . }
        UNION { ?concept skos:broaderTransitive ?other_concept . }
        UNION { ?concept skos:narrowerTransitive ?other_concept . }
        UNION { ?concept skos:semanticRelation ?other_concept . }
        UNION { ?other_concept skos:related ?concept . }
        UNION { ?other_concept skos:broader ?concept . }
        UNION { ?other_concept skos:narrower ?concept . }
        UNION { ?other_concept skos:broaderTransitive ?concept . }
        UNION { ?other_concept skos:narrowerTransitive ?concept . }
        UNION { ?other_concept skos:semanticRelation ?concept . }

        UNION { ?concept skos:topConceptOf ?concept_scheme . }
        UNION { ?concept_scheme skos:hasTopConcept ?concept . }
        UNION { ?collection skos:member ?concept . }
      }
      """,
      default_prefixes: %{skos: SKOS, rdfs: RDF.NS.RDFS}
    )
    |> SPARQL.Query.Result.get(:concept)
    |> List.wrap()
  end

  defp determine_base_iri(concepts, opts) do
    if Keyword.has_key?(opts, :base_iri) do
      Keyword.get(opts, :base_iri)
    else
      detect_base_iri(concepts)
    end
    |> validate_base_iri(concepts)
  end

  defp detect_base_iri([]), do: nil

  defp detect_base_iri(concepts) do
    Enum.find(concepts, fn concept ->
      not (concept |> to_string() |> String.ends_with?(~w[# /]))
    end)
    |> do_detect_base_iri()
  end

  defp do_detect_base_iri(nil), do: nil

  defp do_detect_base_iri(concept) do
    concept
    |> to_string()
    |> String.reverse()
    |> String.split("#", parts: 2)
    |> case do
      [_, base_iri] ->
        String.reverse(base_iri) <> "#"

      [original] ->
        original
        |> String.split("/", parts: 2)
        |> case do
          [_, base_iri] -> String.reverse(base_iri) <> "/"
          [_] -> nil
        end
    end
  end

  defp validate_base_iri(nil, _) do
    {:error, "could not determine a base iri"}
  end

  defp validate_base_iri(base_iri, concepts) do
    base = to_string(base_iri)

    not_matching =
      Enum.reject(concepts, fn concept ->
        concept
        |> to_string()
        |> String.starts_with?(base)
      end)

    if Enum.empty?(not_matching) do
      {:ok, base_iri}
    else
      {:error,
       """
       Skout requires that all concepts belong into the same namespace.
       The following do not belong to the #{base} namespace:
       #{Enum.join(not_matching, "\n- ")}
       """}
    end
  end

  defp determine_concept_scheme(graph, opts) do
    if Keyword.has_key?(opts, :concept_scheme) do
      {:ok, Keyword.get(opts, :concept_scheme)}
    else
      detect_concept_scheme(graph)
    end
  end

  defp detect_concept_scheme(graph) do
    graph
    |> SPARQL.execute_query(
      """
      SELECT DISTINCT ?concept_scheme WHERE {
        { ?concept_scheme a skos:ConceptScheme . }
        UNION { ?concept skos:inScheme ?concept_scheme . }
        UNION { ?concept skos:topConceptOf ?concept_scheme . }
        UNION { ?concept_scheme skos:hasTopConcept ?concept . }
      }
      """,
      default_prefixes: %{skos: SKOS, rdfs: RDF.NS.RDFS}
    )
    |> SPARQL.Query.Result.get(:concept_scheme)
    |> case do
      nil ->
        {:ok, nil}

      [] ->
        {:ok, nil}

      [concept_scheme] ->
        {:ok, concept_scheme}

      concept_schemes ->
        {:error,
         "could not determine a unique skos:ConceptScheme: found #{
           Enum.join(concept_schemes, ", ")
         }. Please provide one with the :concept_scheme option"}
    end
  end
end
