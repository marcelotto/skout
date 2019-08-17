defmodule SkoutTest do
  use ExUnit.Case
  doctest Skout

  test "greets the world" do
    assert Skout.hello() == :world
  end
end
