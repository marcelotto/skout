defmodule Skout.YAML.Decoder do
  alias Skout.{Outline, Manifest, IriBuilder}
  alias RDF.NS.SKOS
  alias RDF.IRI

  import Skout.Helper

  def decode(yaml_string, opts \\ []) do
    with {:ok, preamble, body} <- parse_yaml(yaml_string),
         {concept_scheme, preamble} <- Map.pop(preamble, "concept_scheme", true),
         {:ok, manifest} <- build_manifest(preamble, opts),
         {:ok, outline} <- Outline.new(manifest),
         {:ok, outline} <- build_concept_scheme(outline, concept_scheme) do
      build_skos(outline, body, opts)
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

      {:ok, [preamble | multiple_bodies]} ->
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

  defp build_concept_scheme(outline, concept_scheme) do
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

  defp concept_scheme_iri(concept_scheme, manifest) do
    if IRI.absolute?(concept_scheme) do
      IRI.new(concept_scheme)
    else
      IriBuilder.from_label(concept_scheme, manifest)
    end
  end

  defp build_skos(outline, map, opts) do
    Enum.reduce_while(map, {:ok, outline}, fn
      {label, narrower_labels}, {:ok, outline} ->
        Enum.reduce_while(narrower_labels, {:ok, outline}, fn
          hierarchy, {:ok, outline} when is_map(hierarchy) ->
            [{narrower_label, next_level}] = Map.to_list(hierarchy)

            with {:ok, outline} <-
                   Outline.add(outline, label_statement(label, outline.manifest)),
                 {:ok, outline} <-
                   Outline.add(outline, label_statement(narrower_label, outline.manifest)),
                 {:ok, outline} <-
                   Outline.add(
                     outline,
                     narrower_statement(label, narrower_label, outline.manifest)
                   ) do
              if next_level do
                build_skos(outline, hierarchy, opts)
              else
                outline
              end
            end
            |> cont_or_halt()

          narrower_label, {:ok, outline} ->
            with {:ok, outline} <-
                   Outline.add(outline, label_statement(narrower_label, outline.manifest)) do
              outline
              |> Outline.add(narrower_statement(label, narrower_label, outline.manifest))
            end
            |> cont_or_halt()
        end)
        |> cont_or_halt()
    end)
  end

  defp concept_scheme_statements(false), do: []

  defp concept_scheme_statements(concept_scheme_iri) do
    {concept_scheme_iri, RDF.type(), SKOS.ConceptScheme}
  end

  defp narrower_statement(a, b, manifest) do
    {
      IriBuilder.from_label(a, manifest),
      SKOS.narrower(),
      IriBuilder.from_label(b, manifest)
    }
  end

  defp label_statement(label, manifest) do
    {
      IriBuilder.from_label(label, manifest),
      SKOS.prefLabel(),
      Manifest.term_to_literal(label, manifest)
    }
  end
end
