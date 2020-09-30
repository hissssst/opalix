defmodule OpalixTest do
  use ExUnit.Case
  doctest Opalix

  test "adhoc test" do
    assert {:ok, true} = Opalix.get_document("opa.examples", "allow_request", %{example: %{flag: true}})
  end

end
