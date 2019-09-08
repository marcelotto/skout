defmodule Skout.Document do
  @moduledoc """
  A structure for Skout documents for terse descriptions of SKOS concept schemes.

  A Skout document consists of a graph with the description of the [SKOS](http://www.w3.org/TR/skos-reference)
  concept scheme and its concepts and a manifest with general settings for the
  YAML serialization.

  """

  defstruct [:manifest, :skos]

  alias Skout.{Manifest, Materialization}
  alias RDF.Graph
  alias RDF.NS.{SKOS, RDFS}
  alias Skout.NS.DC

  import Skout.Helper

  @doc """
  Creates a new document with the given settings.

  The following settings for the manifest are available:

  - `base_iri`: The base IRI to be used for the concepts.
    This is the only required setting.
  - `iri_normalization`: The normalization method which is applied to the labels
    before they are concatenated to the `base_iri`.
    Must be one of `:camelize` or `underscore` and defaults to `camelize`.
  - `default_language`: The language-tag used for the produced `skos:prefLabel`
    statements.
  - `materialization`: Another struct with flag settings controlling which
    statements should be materialized.
    The following flags are available: `:rdf_type, :in_scheme, :inverse_hierarchy, :inverse_related`.

  Return the constructed document in an `:ok` tuple in success case, otherwise an
  `:error` tuple.
  """
  def new(manifest) do
    with {:ok, manifest} <- Manifest.new(manifest) do
      {:ok,
       %__MODULE__{
         manifest: manifest,
         skos:
           Graph.new(
             prefixes: %{
               "" => manifest.base_iri,
               skos: SKOS,
               rdfs: RDFS,
               dct: DC
             }
           )
       }}
    end
  end

  @doc """
  Creates a new document with the given settings.

  As opposed to `new/1` this returns the document directly or raises an exception
  in the error case.
  """
  def new!(manifest) do
    case new(manifest) do
      {:ok, document} -> document
      {:error, error} -> raise error
    end
  end

  @doc false
  def finalize(%__MODULE__{} = document) do
    add(document, Materialization.infer_top_concepts(document))
  end

  @doc """
  Adds `triples` to the SKOS graph of `document`.

  Note, that this might materialize some forward chained statements.

  Returns the updated document in an `:ok` tuple in success case, otherwise an
  `:error` tuple.
  """
  def add(document, triples)

  def add(%__MODULE__{} = document, triple) when is_tuple(triple) do
    if RDF.Triple.valid?(triple) do
      {:ok,
       add_to_graph(
         document,
         Materialization.infer(triple, document.manifest)
       )}
    else
      {:error, "invalid triple: #{inspect(triple)}"}
    end
  end

  def add(%__MODULE__{} = document, triples) when is_list(triples) do
    Enum.reduce_while(triples, {:ok, document}, fn triple, {:ok, document} ->
      document
      |> add(triple)
      |> cont_or_halt()
    end)
  end

  @doc """
  Adds `triples` to the SKOS graph of `document`.

  As opposed to `add/2` this returns the updated document directly or raises an
  exception in the error case.
  """
  def add!(manifest, triples) do
    case add(manifest, triples) do
      {:ok, document} -> document
      {:error, error} -> raise error
    end
  end

  @doc false
  def update_graph(%__MODULE__{} = document, fun) do
    %__MODULE__{document | skos: fun.(document.skos)}
  end

  defp add_to_graph(%__MODULE__{} = document, data) do
    update_graph(document, &Graph.add(&1, data))
  end

  @doc """
  Reads a document from a YAML string.

  You can pass in all the options mentioned in `new/1` overwriting the values
  in the preamble.

  Returns the document in an `:ok` tuple in success case, otherwise an `:error`
  tuple.
  """
  defdelegate from_yaml(yaml, opts \\ []), to: Skout.YAML.Decoder, as: :decode

  @doc """
  Reads a document from a YAML string.

  You can pass in all the options mentioned in `new/1` overwriting the values
  in the preamble.

  As opposed to `from_yaml/2` this returns the document directly or raises an
  exception in the error case.
  """
  defdelegate from_yaml!(yaml, opts \\ []), to: Skout.YAML.Decoder, as: :decode!

  @doc """
  Returns the YAML serialization of `document`.

  Returns the YAML string in an `:ok` tuple in success case, otherwise an `:error`
  tuple.
  """
  defdelegate to_yaml(document, opts \\ []), to: Skout.YAML.Encoder, as: :encode

  @doc """
  Returns the YAML serialization of `document`.

  As opposed to `to_yaml/2` this returns the YAML string directly or raises an
  exception in an error case.
  """
  defdelegate to_yaml!(document, opts \\ []), to: Skout.YAML.Encoder, as: :encode!

  @doc """
  Reads a document from an `RDF.Graph`.

  You can pass in all the options mentioned in `new/1` overwriting the values
  in the preamble.

  Returns the document in an `:ok` tuple in success case, otherwise an `:error`
  tuple.
  """
  defdelegate from_rdf(graph, opts \\ []), to: Skout.RDF.Import, as: :call

  @doc """
  Reads a document from an `RDF.Graph`.

  As opposed to `from_rdf/2` this returns the document directly or raises an
  exception in an error case.
  """
  defdelegate from_rdf!(graph, opts \\ []), to: Skout.RDF.Import, as: :call!

  @doc """
  Returns the RDF graph of the SKOS concept scheme of `document`.

  Note that other than the other conversion functions this one doesn't return
  the result in an `:ok` tuple, since it can't fail.
  """
  def to_rdf(%__MODULE__{} = document), do: document.skos
end
