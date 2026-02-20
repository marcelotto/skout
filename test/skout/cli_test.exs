defmodule Skout.CLITest do
  use ExUnit.Case, async: true

  import Skout.CLI.Helper

  @moduletag :tmp_dir

  setup context do
    if tmp_dir = context[:tmp_dir] do
      cwd = File.cwd!()
      File.cd!(tmp_dir)
      on_exit(fn -> File.cd!(cwd) end)
    end

    :ok
  end

  describe "YAML to RDF conversion with output file" do
    test "YAML to Turtle" do
      assert {0, output} = capture_cli("#{example("vehicle_types.yml")} vehicle_types.ttl")
      assert output =~ "Done."
      assert File.exists?("vehicle_types.ttl")

      content = File.read!("vehicle_types.ttl")
      assert content =~ "skos:ConceptScheme"
      assert content =~ "Pedal cycles"
    end

    test "YAML to N-Triples" do
      assert {0, _output} = capture_cli("#{example("vehicle_types.yml")} vehicle_types.nt")
      assert File.exists?("vehicle_types.nt")

      content = File.read!("vehicle_types.nt")
      assert content =~ "http://www.w3.org/2004/02/skos/core#ConceptScheme"
    end

    test "YAML to JSON-LD" do
      assert {0, _output} = capture_cli("#{example("vehicle_types.yml")} vehicle_types.json")
      assert File.exists?("vehicle_types.json")
    end

    test "explicit --output_type overrides extension" do
      assert {0, _output} =
               capture_cli("#{example("vehicle_types.yml")} output.rdf --output_type ntriples")

      content = File.read!("output.rdf")
      assert content =~ "http://www.w3.org/2004/02/skos/core#ConceptScheme"
    end
  end

  describe "RDF to YAML conversion with output file" do
    test "Turtle to YAML" do
      assert {0, output} = capture_cli("#{test_data("vehicle_types.ttl")} output.yml")
      assert output =~ "Done."
      assert File.exists?("output.yml")

      content = File.read!("output.yml")
      assert content =~ "base_iri:"
      assert content =~ "Pedal cycles"
    end
  end

  describe "stdout output (no output file)" do
    test "YAML input defaults to Turtle on stdout" do
      assert {0, output} = capture_cli("#{example("vehicle_types.yml")}")
      refute output =~ "Done."
      assert output =~ "skos:ConceptScheme"
      assert output =~ "Pedal cycles"
    end

    test "YAML input with --output_type ntriples" do
      assert {0, output} = capture_cli("#{example("vehicle_types.yml")} --output_type ntriples")

      assert output =~ "http://www.w3.org/2004/02/skos/core#ConceptScheme"
    end

    test "RDF input defaults to YAML on stdout" do
      assert {0, output} = capture_cli("#{test_data("vehicle_types.ttl")} --input_type turtle")
      assert output =~ "base_iri:"
      assert output =~ "Pedal cycles"
    end
  end

  describe "error handling" do
    test "nonexistent input file returns exit code 1" do
      assert {1, output} = capture_cli("nonexistent.yml output.ttl")
      assert output =~ "not found"
    end

    test "unknown output extension without --output_type returns exit code 1" do
      assert {1, output} = capture_cli("#{example("vehicle_types.yml")} output.xyz")
      assert output =~ "Unknown output type"
    end
  end

  describe "format detection" do
    test "infers input type from .yml extension" do
      assert {0, _output} = capture_cli("#{example("vehicle_types.yml")} output.ttl")
      assert File.exists?("output.ttl")
    end

    test "infers input type from .ttl extension" do
      assert {0, output} = capture_cli("#{test_data("vehicle_types.ttl")}")
      assert output =~ "base_iri:"
    end

    test "explicit --input_type overrides extension" do
      assert {0, output} = capture_cli("#{test_data("vehicle_types.ttl")} --input_type turtle")
      assert output =~ "base_iri:"
    end
  end
end
