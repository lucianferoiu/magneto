defmodule Magneto.Operations.Query do

  alias Magneto.Type
  require Logger

  defmacro query(model, [{:for, hash_value} | clauses]) do
    do_query(model,hash_value,clauses)
  end

  defmacro scan(expr), do: Logger.debug "scan: #{inspect expr}"
  defmacro scan(entity, clauses) do
    Logger.debug "scan: \n#{inspect entity}\n#{inspect clauses}"
    {:__aliases__,_,[model]} = entity
    {model,_} = Code.eval_quoted(entity, [], __CALLER__) #Macro.expand(entity, __CALLER__)
    Code.ensure_compiled(model)
    {table, opts} = do_scan(model, clauses)
    quote bind_quoted: [table: table, opts: opts, model: model] do
      with req <- ExAws.Dynamo.scan(table, opts),
           ok <- Logger.debug("req: #{inspect req}"),
           res <- ExAws.request(req),
           ok <- Logger.debug("res: #{inspect res}"),
           {:ok, data } <- res,
           ok <- Logger.debug("data: #{inspect data}"),
           decoded <- ExAws.Dynamo.Decoder.decode(data, as: model),
           ok <- Logger.debug("decoded: #{inspect decoded}"),
       do: decoded #TODO add cast struct to conform to attribute types
    end
  end


  # -----

  defp do_query(model, hash_value, where_clause) do
    quote do

    end
  end

  def do_scan(model,clauses) do
    # table_name = apply(model, :__canonical_name__, [])
    Logger.debug "Scanning #{inspect model} -> before meta"
    meta = struct(model)
    Logger.debug "Scanning #{inspect model} -> meta: #{inspect meta}"
    %{ :__meta__ => %{:storage => table_name}} = meta
    opts = Enum.map(clauses, &do_clause/1)

    {table_name, []} #TODO
  end

  defp do_clause({:limit, limit}) when is_integer(limit) and limit > 0, do: {:limit, limit}
  defp do_clause({:where, where_ast}) do
    Macro.postwalk(where_ast, fn node -> Logger.debug "==> #{inspect node}" end)
  end

  defp pre(node, acc) do
    {node, acc}
  end
  defp post(node, acc) do
    {node, acc}
  end


end
