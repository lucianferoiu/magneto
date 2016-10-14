defmodule Magneto.Operations.DML do
  alias Magneto.Type
  require Logger

  defmacro get(mod, [{kw, hash_key_value}]) when kw in [:for, :hash, :with] do
    quote do: get_item(unquote(mod), hash: unquote(hash_key_value))
  end

  defmacro get(mod, [{kw, hash_key_value}, {:and, range_key_value}]) when kw in [:for, :hash, :with] do
    quote do: get_item(unquote(mod), hash: unquote(hash_key_value), range: unquote(range_key_value))
  end

  defmacro put(values, into: module) do
    quote do: put_item(unquote(module), unquote(values))
  end

  defmacro into(module), do: quote do: unquote(module)
  defmacro from(module), do: quote do: unquote(module)

  def put_item(model,values), do: do_put(model, values)

  def get_item(model, hash: hash_key_value, range: range_key_value) do
    keys = cast_keys(model, hash_key_value, range_key_value)
    # Logger.debug("keys: #{inspect keys}")
    do_get(model, keys)
  end
  def get_item(model, hash: hash_key_value) do
    keys = cast_keys(model, hash_key_value)
    # Logger.debug("keys: #{inspect keys}")
    do_get(model, keys)
  end

  # -----

  defp do_put(model, values) do
    table_name = apply(model, :__canonical_name__, [])
    with encoded <- values, # TODO encode custom types
         req <- ExAws.Dynamo.put_item(table_name, encoded),
         {:ok, result } <- ExAws.request(req),
     do: result
  end

  defp do_get(model, keys) do
    table_name = apply(model, :__canonical_name__, [])
    with req <- ExAws.Dynamo.get_item(table_name, keys),
        #  ok <- Logger.debug("req: #{inspect req}"),
         res <- ExAws.request(req),
        #  ok <- Logger.debug("res: #{inspect res}"),
         {:ok, %{ "Item" => data} } <- res,
        #  ok <- Logger.debug("data: #{inspect data}"),
         decoded <- ExAws.Dynamo.Decoder.decode(data, as: model),
        #  ok <- Logger.debug("decoded: #{inspect decoded}"),
     do: decoded #TODO add cast struct to conform to attribute types
  end


  defp cast_keys(model,hash_val,range_val) do
    keys_spec = apply(model, :__keys__, [])
    # Logger.debug("keys_spec: #{inspect keys_spec} for #{hash_val} and #{range_val}")
    key_values =
      with {:ok, {hname, htype}} <- Keyword.fetch(keys_spec, :hash),
          #  ok <- Logger.debug("{hname,htype}: #{hname},#{htype}"),
           dynamo_hash_val <- Type.cast_to_dynamo_db(hash_val, htype),
          #  ok <- Logger.debug("dynamo_hash_val: #{inspect dynamo_hash_val}"),
           {:ok, {rname, rtype}} <- Keyword.fetch(keys_spec, :range),
          #  ok <- Logger.debug("{rname,rtype}: #{rname},#{rtype}"),
           dynamo_range_val <- Type.cast_to_dynamo_db(range_val, rtype),
          #  ok <- Logger.debug("dynamo_range_val: #{inspect dynamo_range_val}"),
       do: [{hname, dynamo_hash_val}, {rname, dynamo_range_val}]
    if :error == key_values, do: raise ArgumentError, "Wrong key values hash: #{inspect hash_val}, range: #{inspect range_val} for #{model} - expected keys of spec #{inspect keys_spec}"
    # Logger.debug("key_values: #{inspect key_values}")
    key_values
  end
  defp cast_keys(model, hash_val) do
    keys_spec = apply(model, :__keys__, [])
    # Logger.debug("keys_spec: #{inspect keys_spec} for #{hash_val}")
    key_values =
      with {:ok, {hname, htype}} <- Keyword.fetch(keys_spec, :hash),
      # ok <- Logger.debug("{hname,htype}: #{hname},#{htype}"),
         dynamo_hash_val <- Type.cast_to_dynamo_db(hash_val, htype),
        #  ok <- Logger.debug("dynamo_hash_val: #{inspect dynamo_hash_val}"),
       do: [{hname, dynamo_hash_val}]
     if Keyword.has_key?(keys_spec, :range), do: raise ArgumentError, "Wrong key values hash: #{inspect hash_val} for #{model} - expected keys of spec #{inspect keys_spec}"
    #  Logger.debug("key_values: #{inspect key_values}")
     key_values
  end

end
