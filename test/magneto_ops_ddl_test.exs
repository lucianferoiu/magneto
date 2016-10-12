defmodule MagnetoOpsDDLTest do
  use ExUnit.Case
  use Magneto
  doctest Magneto.Operations
  require Logger

  defmodule StructModel do
    use Magneto.Model
    hash ssn: :number
    attribute age: :number
    attributes name: :string, email: :string, enabled: :boolean
    attribute last_login: :timestamp
  end

  test "model create and destroy" do
    {:ok, c} = create StructModel
    # Logger.debug "StructModel: #{inspect c}"
    %{"TableDescription" => %{"TableName" => tbl}} = c
    assert tbl == StructModel.__canonical_name__
    {:ok, desc} = describe StructModel
    # Logger.debug "StructModel: #{inspect desc}"
    %{"Table" => %{"TableName" => tbl}} = desc
    assert tbl == StructModel.__canonical_name__
    {:ok, d} = destroy StructModel
    # Logger.debug "StructModel: #{inspect d}"
    %{"TableDescription" => %{"TableName" => tbl}} = d
    assert tbl == StructModel.__canonical_name__
  end



end
