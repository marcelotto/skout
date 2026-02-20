defmodule Skout.CLI.Helper do
  @moduledoc false

  import ExUnit.CaptureIO

  @examples_path Path.absname("examples")
  @test_data_path Path.absname("test/data")

  def capture_cli(args) when is_binary(args) do
    args
    |> OptionParser.split()
    |> capture_cli()
  end

  def capture_cli(args) when is_list(args) do
    with_io(fn -> Skout.CLI.main(args) end)
  end

  def example(filename), do: Path.join(@examples_path, filename)
  def test_data(filename), do: Path.join(@test_data_path, filename)
end
