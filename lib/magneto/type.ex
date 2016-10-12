defmodule Magneto.Type do
  def default_value(type), do: default_value_for_type(type)

  def dynamo_db_type(magneto_type), do: _dynamo_db_type(magneto_type)

  def cast_to_dynamo_db(value, magneto_type), do: value

  def cast_to_magneto(value, dynamo_db_type), do: value

  # --- private functions

  defp default_value_for_type(:number), do: 0
  defp default_value_for_type(:string), do: nil
  defp default_value_for_type(:boolean), do: true
  defp default_value_for_type(:uuid), do: nil
  defp default_value_for_type(:date), do: nil # evaluated at compile time, the current time would be wrong
  defp default_value_for_type(:timestamp), do: nil # evaluated at compile time, the current time would be wrong
  defp default_value_for_type(atom) when is_atom(atom) do
    cond do
      Code.ensure_compiled?(atom) and function_exported?(atom, :type, 0) ->
        Code.eval_string "%#{Atom.to_string(atom)}{}"
      true -> nil
    end
  end
  defp default_value_for_type(_list) when is_list(_list), do: []
  defp default_value_for_type(_map) when is_map(_map), do: %{}
  defp default_value_for_type(_), do: nil

  defp _dynamo_db_type(:number), do: :number
  defp _dynamo_db_type(:string), do: :string
  defp _dynamo_db_type(:boolean), do: :boolean
  defp _dynamo_db_type(:binary), do: :blob
  defp _dynamo_db_type([:string]), do: :string_set
  defp _dynamo_db_type([:number]), do: :number_set
  defp _dynamo_db_type([:binary]), do: :blob_set
  defp _dynamo_db_type(_list) when is_list(_list), do: :list
  defp _dynamo_db_type(_map) when is_map(_map), do: :map
  defp _dynamo_db_type(atom) when is_atom(atom) do
    cond do
      Code.ensure_compiled?(atom) and function_exported?(atom, :type, 0) -> :map
      true -> :null
    end
  end
  defp _dynamo_db_type(_), do: :string

end
