defmodule MagnetoTest do
  use ExUnit.Case
  doctest Magneto

  test "magneto config" do
    assert Application.get_env(:magneto, :namespace) != nil
  end
end
