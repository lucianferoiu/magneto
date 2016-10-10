defmodule Magneto.Operations do

  require Magneto.Operations.DML
  alias ExAws.Dynamo
  alias Magneto.Operations.DML
  alias Magneto.Operations.DDL

  # --- DDL
  defmacro create(model) do
    quote do
      Magneto.Operations.DDL.create(unquote(model))
    end
  end

  # --- DML

  def get(model, with: hash_key_value, and: range_key_value), do: get(model, hash: hash_key_value, range: range_key_value)
  def get(model, hash: hash_key_value, range: range_key_value) do
    DML.get(model,hash_key_value,range_key_value)
  end





end
