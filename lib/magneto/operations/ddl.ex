defmodule Magneto.Operations.DDL do

  alias Magneto.Common
  alias Magneto.Type
  require Logger

  def create(model) do
    Code.ensure_compiled(model)
    table_name = apply(model, :__canonical_name__, [])
    keys = apply(model, :__keys__, [])
    keys_schema = pk_schema(keys)
    keys_spec = pk_spec(keys)
    [read, write] = apply(model, :__throughput__, [])
    local_indexes = apply(model, :__local_indexes__, [])
    global_indexes = apply(model, :__global_indexes__, [])
    # Logger.debug "creating table with indexes: local=#{inspect local_indexes}, global=#{inspect global_indexes}"

    table_name
        |> ExAws.Dynamo.create_table(keys_schema, keys_spec, read, write, local_indexes, global_indexes)
        |> ExAws.request
  end

  def destroy(model) do
    Code.ensure_compiled(model)
    apply(model, :__canonical_name__, [])
        |> ExAws.Dynamo.delete_table
        |> ExAws.request
  end

  def describe(model) do
    Code.ensure_compiled(model)
    apply(model, :__canonical_name__, [])
        |> ExAws.Dynamo.describe_table
        |> ExAws.request
  end


  # ----- private functions

  defp pk_schema([hash: {hname, htype}, range: {rname, rtype}]), do: [{hname, :hash}, {rname, :range}]
  defp pk_schema([hash: {hname, htype}]), do: [{hname, :hash}]

  defp pk_spec([hash: {hname, htype}, range: {rname, rtype}]) do
    [{hname, Type.dynamo_db_type(htype)}, {rname, Type.dynamo_db_type(rtype)}]
  end
  defp pk_spec([hash: {hname, htype}]) do
    [{hname, Type.dynamo_db_type(htype)}]
  end

end
