defmodule CAITest do
  use ExUnit.Case
  doctest CAI

  test "greets the world" do
    assert CAI.hello() == :world
  end
end
