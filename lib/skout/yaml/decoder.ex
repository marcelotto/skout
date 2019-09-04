defmodule Skout.YAML.Decoder do
  alias Skout.{Outline, Manifest, IriBuilder}
  alias RDF.NS.SKOS
  alias RDF.IRI

  import Skout.Helper

  def decode(yaml_string, opts \\ []) do
    with {:ok, preamble, body} <- parse_yaml(yaml_string),
         {concept_scheme, preamble} <-
           (if Keyword.has_key?(opts, :concept_scheme) do
              {
                Keyword.get(opts, :concept_scheme),
                Map.delete(preamble, "concept_scheme")
              }
            else
              Map.pop(preamble, "concept_scheme", true)
            end),
         {:ok, manifest} <- build_manifest(preamble, opts),
         {:ok, outline} <- Outline.new(manifest),
         {:ok, outline} <- build_concept_scheme(outline, concept_scheme, opts),
         {:ok, outline} <- build_skos(outline, body, opts) do
      Outline.finalize(outline)
    end
  end

  defp parse_yaml(yaml_string) do
    case YamlElixir.read_all_from_string(yaml_string) do
      {:ok, [preamble, body]} ->
        {:ok, preamble, body}

      {:ok, [body]} ->
        {:ok, %{}, body}

      {:ok, []} ->
        {:ok, %{}, %{}}

      {:ok, [_preamble | _multiple_bodies]} ->
        # TODO: How to handle multiple docs? Just merge them?
        raise """
        Multiple documents are not supported yet.
        Please raise an issue on https://github.com/marcelotto/skout/issues with your use case."
        """

      error ->
        error
    end
  end

  defp build_manifest(preamble, opts) do
    preamble
    # TODO: maybe we want to limit to_existing_atom
    |> atomize_keys()
    |> Map.new(fn
      {:base, base_iri} ->
        {:base_iri, base_iri}

      {:materialization, opts} when is_list(opts) ->
        {:materialization, Enum.reduce(opts, %{}, fn opt, opts -> Map.merge(opts, opt) end)}

      other ->
        other
    end)
    |> Map.merge(Map.new(opts))
    |> Manifest.new()
  end

  defp build_concept_scheme(outline, concept_scheme_description, opts)
       when is_map(concept_scheme_description) do
    case Map.pop(concept_scheme_description, "id", true) do
      {id, _} when id in [false, nil] ->
        {:error, "id field with IRI of concept scheme is missing"}

      {id, description} ->
        with {:ok, outline} <- build_concept_scheme(outline, id, opts) do
          add_description(outline, outline.manifest.concept_scheme, description, opts)
        end
    end
  end

  defp build_concept_scheme(outline, concept_scheme, _opts) do
    concept_scheme_iri = concept_scheme_iri(concept_scheme, outline.manifest)

    {:ok,
     %Outline{
       outline
       | manifest: %Manifest{outline.manifest | concept_scheme: concept_scheme_iri},
         skos: RDF.Graph.add(outline.skos, concept_scheme_statements(concept_scheme_iri))
     }}
  end

  defp concept_scheme_iri(false, _), do: false
  defp concept_scheme_iri(true, manifest), do: manifest.base_iri

  defp concept_scheme_iri("<" <> concept_scheme, manifest),
    do: concept_scheme |> String.slice(0..-2) |> concept_scheme_iri(manifest)

  defp concept_scheme_iri(concept_scheme, manifest) do
    if IRI.absolute?(concept_scheme) do
      IRI.new(concept_scheme)
    else
      IriBuilder.from_label(concept_scheme, manifest)
    end
  end

  defp build_skos(outline, map, opts) do
    Enum.reduce_while(map, {:ok, outline}, fn
      {concept, children}, {:ok, outline} ->
        Enum.reduce_while(children, {:ok, outline}, fn
          hierarchy, {:ok, outline} when is_map(hierarchy) ->
            add_concept(outline, concept, hierarchy, opts)
            |> cont_or_halt()

          {child, nil}, {:ok, outline} ->
            add_concept(outline, concept, child, opts)
            |> cont_or_halt()

          {child, hierarchy}, {:ok, outline} ->
            add_concept(outline, concept, child, hierarchy, opts)
            |> cont_or_halt()

          child, {:ok, outline} ->
            add_concept(outline, concept, child, opts)
            |> cont_or_halt()
        end)
        |> cont_or_halt()
    end)
  end

  defp add_concept(outline, concept, child, %{} = hierarchy, opts) do
    add_concept(outline, concept, %{child => hierarchy}, opts)
  end

  defp add_concept(outline, concept, %{} = hierarchy, opts) do
    case Map.to_list(hierarchy) do
      [{child, nil}] ->
        add_concept(outline, concept, child, opts)

      [{child, _}] ->
        case add_concept(outline, concept, child, opts) do
          {:ok, :hierarchy, outline} ->
            build_skos(outline, hierarchy, opts)

          {:ok, :description, outline} ->
            add_hierarchy_embedded_description(outline, concept, hierarchy, opts)

          {:error, _} = error ->
            error
        end
    end
  end

  defp add_concept(outline, concept, ":" <> _, _) do
    with {:ok, outline} <-
           Outline.add(outline, label_statement(concept, outline.manifest)) do
      {:ok, :description, outline}
    end
  end

  defp add_concept(outline, concept, narrower, _) do
    with {:ok, outline} <-
           Outline.add(outline, label_statement(concept, outline.manifest)),
         {:ok, outline} <-
           Outline.add(outline, label_statement(narrower, outline.manifest)),
         {:ok, outline} <-
           Outline.add(outline, narrower_statement(concept, narrower, outline.manifest)) do
      {:ok, :hierarchy, outline}
    end
  end

  defp add_description(outline, concept, description, opts) do
    Enum.reduce_while(description, {:ok, outline}, fn
      {property, objects}, outline ->
        add_description_statements(outline, concept, property, objects, opts)
        |> cont_or_halt()
    end)
  end

  defp add_hierarchy_embedded_description(outline, concept, description, opts) do
    Enum.reduce_while(description, {:ok, outline}, fn
      {":" <> property, objects}, outline ->
        add_description_statements(outline, concept, property, objects, opts)
        |> cont_or_halt()
    end)
  end

  defp add_description_statements(outline, concept, property, objects, _opts) do
    objects
    |> List.wrap()
    |> Enum.reduce_while(outline, fn object, {:ok, outline} ->
      with {:ok, statement} <-
             generic_statement(concept, property, object, outline.manifest) do
        Outline.add(outline, statement)
      end
      |> cont_or_halt()
    end)
  end

  defp generic_statement(subject, predicate, object, manifest) do
    with {:ok, predicate_iri} <- IriBuilder.predicate(predicate, manifest),
         {:ok, object_term} <- Manifest.object_term(object, predicate_iri, manifest) do
      {:ok,
       {
         IriBuilder.from_label(subject, manifest),
         predicate_iri,
         object_term
       }}
    end
  end

  defp concept_scheme_statements(false), do: []

  defp concept_scheme_statements(concept_scheme_iri) do
    {concept_scheme_iri, RDF.type(), SKOS.ConceptScheme}
  end

  defp label_statement(label, manifest) do
    {
      IriBuilder.from_label(label, manifest),
      SKOS.prefLabel(),
      Manifest.term_to_literal(label, manifest)
    }
  end

  defp narrower_statement(a, b, manifest) do
    {
      IriBuilder.from_label(a, manifest),
      SKOS.narrower(),
      IriBuilder.from_label(b, manifest)
    }
  end
end
