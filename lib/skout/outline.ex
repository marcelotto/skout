defmodule Skout.Outline do
  defstruct [:manifest, :skos]

  alias Skout.{Manifest, Materialization}
  alias RDF.Graph
  alias RDF.NS.{SKOS, RDFS}
  alias Skout.NS.DC

  import Skout.Helper

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

  def new!(manifest) do
    case new(manifest) do
      {:ok, outline} -> outline
      {:error, error} -> raise error
    end
  end

  def finalize(%__MODULE__{} = outline) do
    add(outline, Materialization.infer_top_concepts(outline))
  end

  def add(%__MODULE__{} = outline, triple) when is_tuple(triple) do
    if RDF.Triple.valid?(triple) do
      {:ok,
       add_to_graph(
         outline,
         Materialization.infer(triple, outline.manifest)
       )}
    else
      {:error, "invalid triple: #{inspect(triple)}"}
    end
  end

  def add(%__MODULE__{} = outline, triples) when is_list(triples) do
    Enum.reduce_while(triples, {:ok, outline}, fn triple, {:ok, outline} ->
      outline
      |> add(triple)
      |> cont_or_halt()
    end)
  end

  def add!(manifest, triples) do
    case add(manifest, triples) do
      {:ok, outline} -> outline
      {:error, error} -> raise error
    end
  end

  def update_graph(%__MODULE__{} = outline, fun) do
    %__MODULE__{outline | skos: fun.(outline.skos)}
  end

  def add_to_graph(%__MODULE__{} = outline, data) do
    update_graph(outline, &Graph.add(&1, data))
  end

  defdelegate from_yaml(yaml, opts \\ []), to: Skout.YAML.Decoder, as: :decode
  defdelegate from_yaml!(yaml, opts \\ []), to: Skout.YAML.Decoder, as: :decode!
  defdelegate to_yaml(outline, opts \\ []), to: Skout.YAML.Encoder, as: :encode
  defdelegate to_yaml!(outline, opts \\ []), to: Skout.YAML.Encoder, as: :encode!

  defdelegate from_rdf(graph, opts \\ []), to: Skout.RDF.Import, as: :call
  defdelegate from_rdf!(graph, opts \\ []), to: Skout.RDF.Import, as: :call!

  @doc """
  Returns the RDF graph of the SKOS concept scheme of `outline`.

  Note that other than the other conversion functions this one doesn't return
  the result in an ok tuple, since it can't fail.
  """
  def to_rdf(%__MODULE__{} = outline), do: outline.skos
end
