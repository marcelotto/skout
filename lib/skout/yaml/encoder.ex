defmodule Skout.YAML.Encoder do
  alias Skout.{Outline, IriBuilder, Materialization}
  alias RDF.NS.{SKOS, RDFS}
  alias Skout.NS.DC
  alias RDF.{Graph, Description, IRI, Literal}

  import RDF.Sigils

  @concept_description_blueprint [
    # Schema
    RDF.type(),
    RDFS.subClassOf(),
    # Lexical labels
    SKOS.altLabel(),
    SKOS.hiddenLabel(),
    SKOS.notation(),
    # Documentation
    SKOS.definition(),
    SKOS.example(),
    SKOS.scopeNote(),
    SKOS.changeNote(),
    SKOS.historyNote(),
    SKOS.note(),
    SKOS.editorialNote(),
    DC.creator(),
    RDFS.isDefinedBy(),
    RDFS.seeAlso(),
    # Collections
    SKOS.member(),
    SKOS.memberList(),
    # Semantic relations
    SKOS.related(),
    SKOS.narrower(),
    # Mapping properties
    SKOS.exactMatch(),
    SKOS.closeMatch(),
    SKOS.narrowMatch(),
    SKOS.broadMatch(),
    SKOS.relatedMatch(),
    SKOS.mappingRelation()
  ]

  @known_properties IriBuilder.known_properties()
                    |> Enum.map(fn
                      # title is for concept schemes only
                      {:title, _} -> nil
                      {property, iri} -> {iri, property}
                    end)
                    |> Enum.reject(&is_nil/1)
                    |> Map.new()

  unless @known_properties |> Map.drop(@concept_description_blueprint) |> Enum.empty?() do
    raise """
    The following known properties are missing in the concept description blueprint:
    - #{
      @known_properties
      |> Map.drop(@concept_description_blueprint)
      |> Enum.map(fn {property, _} -> to_string(property) end)
      |> Enum.join("\n- ")
    }
    """
  end

  @props_with_range_concept Materialization.semantic_relations() ++
                              Materialization.props_with_range_concept()

  @line_length 80

  def encode(outline, opts \\ []) do
    {:ok,
     """
     #{preamble(outline, opts) |> String.trim()}
     ---
     #{body(outline, opts)}
     """}
  end

  def encode!(outline, opts \\ []) do
    case encode(outline, opts) do
      {:ok, yaml} -> yaml
      {:error, error} -> raise error
    end
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
    |> Materialization.top_concepts()
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

    concept_label(concept, description) <>
      ":\n" <>
      Enum.map_join(@concept_description_blueprint, fn property ->
        statement(concept, property, description, outline, depth, visited, opts)
      end)
  end

  defp concept_label(concept, %Outline{} = outline) do
    if description = Graph.description(outline.skos, concept) do
      concept_label(concept, description)
    end
  end

  defp concept_label(concept, %Description{} = description) do
    description
    |> Description.get(SKOS.prefLabel())
    |> case do
      nil -> raise "Missing label for concept #{concept}"
      [label] -> to_string(label)
    end
  end

  defp statement(concept, property, description, outline, depth, visited, opts) do
    if objects = Description.get(description, property) do
      do_statement(concept, property, objects, outline, depth, visited, opts)
    else
      ""
    end
  end

  defp do_statement(
         concept,
         unquote(Macro.escape(SKOS.narrower())),
         narrower_concepts,
         outline,
         depth,
         visited,
         opts
       ) do
    narrower_concepts
    |> MapSet.new()
    |> concepts(outline, depth + 1, MapSet.put(visited, concept), opts)
    |> case do
      "" -> ""
      next_level -> indentation(depth + 1) <> next_level
    end
  end

  defp do_statement(_, unquote(Macro.escape(RDF.type())), objects, outline, depth, _, opts) do
    filtered_objects = objects -- [RDF.iri(SKOS.Concept)]

    if not Enum.empty?(filtered_objects) do
      generic_statement(RDF.type(), filtered_objects, outline, depth, opts)
    else
      ""
    end
  end

  defp do_statement(_, property, objects, outline, depth, _, opts) do
    generic_statement(property, objects, outline, depth, opts)
  end

  defp generic_statement(property, objects, outline, depth, opts) do
    if key = Map.get(@known_properties, property) do
      object_terms =
        objects
        |> Enum.map(fn object -> object_term(property, object, outline, opts) end)
        |> Enum.reject(&is_nil/1)

      indentation(depth + 1) <>
        ":#{key}:" <>
        objects(object_terms, depth) <>
        "\n"
    else
      # unknown properties are simply ignored
      ""
    end
  end

  defp object_term(property, %IRI{} = object, outline, opts)
       when property in @props_with_range_concept do
    case object_term(nil, object, outline, opts) do
      ":" <> term -> term
      other -> other
    end
  end

  defp object_term(_, %IRI{} = object, outline, _opts) do
    label = concept_label(object, outline)

    if label && to_string(object) == to_string(outline.manifest.base_iri) <> label do
      ":#{label}"
    else
      "<#{object}>"
    end
  end

  defp object_term(property, %Literal{} = object, _, _)
       when property in @props_with_range_concept do
    raise "Literal used as object on property #{property} with skos:Concept range: #{object}"
  end

  defp object_term(_, %Literal{} = object, _outline, _) do
    to_string(object)
  end

  defp object_term(_, %RDF.BlankNode{}, _, _), do: nil

  defp objects([object_term], _), do: " " <> object_term

  defp objects(object_terms, depth) do
    if objects_fit_on_line?(object_terms, depth) do
      " [" <>
        Enum.join(object_terms, ", ") <>
        "]"
    else
      "\n" <>
        indentation(depth + 2) <>
        Enum.join(object_terms, "\n" <> indentation(depth + 2))
    end
  end

  defp objects_fit_on_line?(objects, depth) do
    Enum.reduce(
      objects,
      depth |> indentation() |> String.length(),
      fn object, length ->
        length + String.length(object) + 2
      end
    ) <= @line_length
  end

  defp indentation(0), do: ""
  defp indentation(depth), do: String.duplicate("  ", depth - 1) <> "- "
end
