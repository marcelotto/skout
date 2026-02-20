defmodule Skout.CLI do
  @moduledoc false

  alias Skout.Document

  @version File.read!("VERSION") |> String.trim()

  @rdf_file_types ~w[turtle ntriples nquads jsonld]a
  @file_types [:skout | @rdf_file_types]
  @file_type_mapping %{
    yml: :skout,
    yaml: :skout,
    skout: :skout,
    nt: :ntriples,
    ntriples: :ntriples,
    nq: :nquads,
    nquads: :nquads,
    ttl: :turtle,
    turtle: :turtle,
    json: :jsonld,
    jsonld: :jsonld,
    rdf: :turtle
  }

  @iri_normalization_methods ~w[camelize underscore]

  def start(_type, _args) do
    if System.get_env("__BURRITO") == "1" do
      Burrito.Util.Args.get_arguments()
      |> main()
    else
      {:ok, self()}
    end
  end

  def main(argv) do
    case parse_opts(argv) do
      cli when is_map(cli) -> run(cli)
      code when is_integer(code) -> code
    end
    |> halt()
  end

  defp run(cli) do
    input = cli.args.input_file
    output = cli.args.output_file

    opts =
      cli.options
      |> Map.drop(~w[input_type output_type])
      |> Enum.reject(fn {_, value} -> is_nil(value) end)
      |> Keyword.new()

    input_type = file_type(cli.options.input_type, input)

    output_type =
      file_type(cli.options.output_type, output) ||
        (!output && default_output_type(input_type)) ||
        nil

    case document(input_type, input, opts) do
      {:ok, document} ->
        result =
          if output,
            do: write_to_file(output_type, output, document, opts),
            else: write_to_stdout(output_type, document, opts)

        case result do
          :ok ->
            if output, do: IO.puts("Done.")
            0

          error ->
            print_error(error)
            1
        end

      error ->
        print_error(error)
        1
    end
  end

  def parse_opts(argv) do
    Optimus.new!(
      name: "skout",
      description: "CLI for Skout",
      version: @version,
      author: "Marcel Otto",
      about: "Translate SKOS concept schemes in Skout YAML to RDF serializations or vice versa.",
      allow_unknown_args: false,
      parse_double_dash: true,
      args: [
        input_file: [
          value_name: "INPUT_FILE",
          help: "Either a Skout YAML document or an RDF serialization of a concept scheme",
          required: true,
          parser: :string
        ],
        output_file: [
          value_name: "OUTPUT_FILE",
          help: "Output file path. When omitted, output is written to stdout.",
          required: false,
          parser: :string
        ]
      ],
      options: [
        input_type: [
          value_name: "INPUT_TYPE",
          short: "-i",
          long: "--input_type",
          help:
            "The input type which might be required if it can not be inferred from the input file extension (one of #{Enum.join(@file_types, ", ")}",
          parser: :string,
          required: false
        ],
        output_type: [
          value_name: "OUTPUT_TYPE",
          short: "-o",
          long: "--output_type",
          help:
            "The output type which might be required if it can not be inferred from the output file extension (one of #{Enum.join(@file_types, ", ")}",
          parser: :string,
          required: false
        ],
        base_iri: [
          value_name: "BASE_IRI",
          short: "-b",
          long: "--base_iri",
          help: "The base IRI the be used for the concepts",
          parser: :string,
          required: false
        ],
        concept_scheme: [
          value_name: "CONCEPT_SCHEME",
          short: "-s",
          long: "--concept_scheme",
          help: "The IRI of the concept scheme",
          parser: :string,
          required: false
        ],
        iri_normalization: [
          value_name: "IRI_NORMALIZATION",
          short: "-n",
          long: "--iri_normalization",
          help:
            "The IRI normalization method (one of #{Enum.join(@iri_normalization_methods, ", ")})",
          parser: fn
            method when method in @iri_normalization_methods ->
              {:ok, method}

            _ ->
              {:error, "must be one of #{Enum.join(@iri_normalization_methods, ", ")}"}
          end,
          required: false
        ],
        default_language: [
          value_name: "DEFAULT_LANGUAGE",
          short: "-l",
          long: "--default_language",
          help: "The language-tag to be used for the generated skos:prefLabels",
          parser: :string,
          required: false
        ]
      ]
    )
    |> Optimus.parse!(argv, &halt/1)
  end

  defp file_type(nil, nil), do: nil
  defp file_type(type, nil), do: Map.get(@file_type_mapping, String.to_atom(type))

  defp file_type(type, input) do
    (type && Map.get(@file_type_mapping, String.to_atom(type))) ||
      Map.get(
        @file_type_mapping,
        input
        |> Path.extname()
        |> String.trim_leading(".")
        |> String.to_atom()
      )
  end

  defp default_output_type(:skout), do: :turtle
  defp default_output_type(rdf_type) when rdf_type in @rdf_file_types, do: :skout
  defp default_output_type(_), do: nil

  defp document(nil, _, _), do: {:error, "Unknown input type"}

  defp document(:skout, from, opts), do: document_from_yaml(from, opts)

  defp document(input_type, from, opts) when input_type in @rdf_file_types,
    do: document_from_rdf(from, input_type, opts)

  defp document_from_yaml(from, opts) do
    case File.read(from) do
      {:ok, content} -> Document.from_yaml(content, opts)
      error -> file_access_error(error, from)
    end
  end

  def document_from_rdf(from, format, opts) do
    case RDF.Serialization.read_file(from, Keyword.put(opts, :format, format)) do
      {:ok, graph} -> Document.from_rdf(graph, opts)
      error -> file_access_error(error, from)
    end
  end

  defp write_to_file(nil, _, _, _), do: {:error, "Unknown output type"}

  defp write_to_file(:skout, to, document, opts) do
    with {:ok, content} <- Document.to_yaml(document, opts) do
      case File.write(to, content, opts) do
        :ok -> :ok
        error -> file_access_error(error, to)
      end
    end
  end

  defp write_to_file(output_type, to, document, opts) when output_type in @rdf_file_types do
    document
    |> Document.to_rdf()
    |> RDF.Serialization.write_file(
      to,
      opts
      |> Keyword.put(:format, output_type)
      |> Keyword.put(:force, true)
      |> Keyword.drop(~w[base base_iri]a)
    )
    |> case do
      :ok -> :ok
      error -> file_access_error(error, to)
    end
  end

  defp write_to_stdout(nil, _, _), do: {:error, "Unknown output type"}

  defp write_to_stdout(:skout, document, opts) do
    with {:ok, content} <- Document.to_yaml(document, opts) do
      IO.write(content)
      :ok
    end
  end

  defp write_to_stdout(output_type, document, opts) when output_type in @rdf_file_types do
    with {:ok, content} <-
           document
           |> Document.to_rdf()
           |> RDF.Serialization.write_string(
             opts
             |> Keyword.put(:format, output_type)
             |> Keyword.drop(~w[base base_iri]a)
           ) do
      IO.write(content)
      :ok
    end
  end

  defp print_error({:error, error}), do: IO.puts(error)

  defp file_access_error({:error, :enoent}, file), do: {:error, "File #{file} not found"}
  defp file_access_error({:error, :eisdir}, file), do: {:error, "File #{file} is a directory"}
  defp file_access_error({:error, :eacces}, file), do: {:error, "Permission error on #{file}"}
  defp file_access_error({:error, :enospc}, _), do: {:error, "No space left on the device"}
  defp file_access_error({:error, :enomem}, _), do: {:error, "Out of memory"}
  defp file_access_error(error, _), do: error

  if Mix.env() == :test do
    defp halt(code), do: code
  else
    defp halt(code), do: System.halt(code)
  end
end
