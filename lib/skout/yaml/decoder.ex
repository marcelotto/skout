defmodule Skout.YAML.Decoder do
  @moduledoc false

  alias Skout.{Document, Manifest, IriBuilder}
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
         {:ok, document} <- Document.new(manifest),
         {:ok, document} <- build_concept_scheme(document, concept_scheme, opts),
         {:ok, document} <- build_skos(document, body, opts) do
      Document.finalize(document)
    end
  end

  def decode!(yaml_string, opts \\ []) do
    case decode(yaml_string, opts) do
      {:ok, document} -> document
      {:error, error} -> raise error
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

  defp build_concept_scheme(document, concept_scheme_description, opts)
       when is_map(concept_scheme_description) do
    case Map.pop(concept_scheme_description, "id", true) do
      {id, _} when id in [false, nil] ->
        {:error, "id field with IRI of concept scheme is missing"}

      {id, description} ->
        with {:ok, document} <- build_concept_scheme(document, id, opts) do
          add_description(document, document.manifest.concept_scheme, description, opts)
        end
    end
  end

  defp build_concept_scheme(document, concept_scheme, _opts) do
    concept_scheme_iri = concept_scheme_iri(concept_scheme, document.manifest)

    {:ok,
     %Document{
       document
       | manifest: %Manifest{document.manifest | concept_scheme: concept_scheme_iri},
         skos: RDF.Graph.add(document.skos, concept_scheme_statements(concept_scheme_iri))
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

  defp build_skos(document, map, opts) do
    Enum.reduce_while(map, {:ok, document}, fn
      {concept, children}, {:ok, document} ->
        Enum.reduce_while(children, {:ok, document}, fn
          hierarchy, {:ok, document} when is_map(hierarchy) ->
            add_concept(document, concept, hierarchy, opts)
            |> cont_or_halt()

          {child, nil}, {:ok, document} ->
            add_concept(document, concept, child, opts)
            |> cont_or_halt()

          {child, hierarchy}, {:ok, document} ->
            add_concept(document, concept, child, hierarchy, opts)
            |> cont_or_halt()

          child, {:ok, document} ->
            add_concept(document, concept, child, opts)
            |> cont_or_halt()
        end)
        |> cont_or_halt()

      hierarchy, {:ok, document} when is_map(hierarchy) ->
        document
        |> build_skos(hierarchy, opts)
        |> cont_or_halt()

      concept, {:ok, document} ->
        add_concept(document, concept, opts)
        |> cont_or_halt()
    end)
  end

  defp add_concept(document, concept, _) do
    with {:ok, document} <-
           Document.add(document, concept_statements(concept, document.manifest)) do
      {:ok, :description, document}
    end
  end

  defp add_concept(document, concept, child, %{} = hierarchy, opts) do
    add_concept(document, concept, %{child => hierarchy}, opts)
  end

  defp add_concept(document, concept, %{} = hierarchy, opts) do
    case Map.to_list(hierarchy) do
      [{child, nil}] ->
        add_concept(document, concept, child, opts)

      [{child, _}] ->
        case add_concept(document, concept, child, opts) do
          {:ok, :hierarchy, document} ->
            build_skos(document, hierarchy, opts)

          {:ok, :description, document} ->
            add_hierarchy_embedded_description(document, concept, hierarchy, opts)

          {:error, _} = error ->
            error
        end
    end
  end

  defp add_concept(document, concept, ":" <> _, opts),
    do: add_concept(document, concept, opts)

  defp add_concept(document, concept, narrower, _) do
    with {:ok, document} <-
           Document.add(document, concept_statements(concept, document.manifest)),
         {:ok, document} <-
           Document.add(document, concept_statements(narrower, document.manifest)),
         {:ok, document} <-
           Document.add(document, narrower_statement(concept, narrower, document.manifest)) do
      {:ok, :hierarchy, document}
    end
  end

  defp add_description(document, concept, description, opts) do
    Enum.reduce_while(description, {:ok, document}, fn
      {property, objects}, document ->
        add_description_statements(document, concept, property, objects, opts)
        |> cont_or_halt()
    end)
  end

  defp add_hierarchy_embedded_description(document, concept, description, opts) do
    Enum.reduce_while(description, {:ok, document}, fn
      {":" <> property, objects}, document ->
        add_description_statements(document, concept, property, objects, opts)
        |> cont_or_halt()
    end)
  end

  defp add_description_statements(document, concept, property, objects, _opts) do
    objects
    |> List.wrap()
    |> Enum.reduce_while(document, fn object, {:ok, document} ->
      with {:ok, statement} <-
             generic_statement(concept, property, object, document.manifest) do
        Document.add(document, statement)
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

  defp concept_statements(label, manifest) do
    [
      {IriBuilder.from_label(label, manifest), RDF.type(), RDF.iri(SKOS.Concept)},
      {
        IriBuilder.from_label(label, manifest),
        Manifest.label_property(manifest),
        Manifest.term_to_literal(label, manifest)
      }
      | if(manifest.additional_concept_class,
          do:
            {IriBuilder.from_label(label, manifest), RDF.type(),
             manifest.additional_concept_class}
        )
        |> List.wrap()
    ]
  end

  defp narrower_statement(a, b, manifest) do
    {
      IriBuilder.from_label(a, manifest),
      SKOS.narrower(),
      IriBuilder.from_label(b, manifest)
    }
  end
end
