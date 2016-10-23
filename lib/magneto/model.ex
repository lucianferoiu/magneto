defmodule Magneto.Model do
  require Logger
  alias Magneto.Type

  defmodule TableMetadata do
    @moduledoc false
    defstruct [:type, :storage, :keys, :attributes, :global_indexes, :local_indexess]
  end

  defmodule IndexMetadata do
    @moduledoc false
    defstruct [:type, :name, :table, :keys, :attributes]
  end

  defmacro __using__(_) do
    target = __CALLER__.module
    # Logger.debug "Using #{__MODULE__} to inject into #{target}"

    default_namespace = Application.get_env(:magneto, :namespace) || "magneto"
    table_name = String.split(Atom.to_string(target), ".") |> List.last

    Module.put_attribute(target, :namespace, default_namespace)
    Module.put_attribute(target, :table_name, table_name)
    Module.put_attribute(target, :throughput, [3,1])
    Module.register_attribute(target, :attributes, accumulate: true)
    Module.put_attribute(target, :keys, [hash: {:id, :number}]) # default pk
    Module.register_attribute(target, :local_indexes, accumulate: true)
    Module.register_attribute(target, :global_indexes, accumulate: true)
    Module.register_attribute(target, :all_indexes_def, accumulate: true)

    quote do
      import Magneto.Model
      @before_compile unquote(__MODULE__)
    end
  end

  # -----

  defmacro __before_compile__(env) do
    # Logger.debug "#{env.module} -> __before_compile__"
    target = env.module
    namespace = Module.get_attribute(target, :namespace)
    table_name = Module.get_attribute(target, :table_name)
    Module.put_attribute(target, :canonical_table_name, "#{namespace}.#{table_name}")
    Module.eval_quoted __CALLER__, [
      Magneto.Model.__def_struct__(target),
      Magneto.Model.__def_indexes__(target),
      Magneto.Model.__def_helper_funcs__(target)
    ]
  end

  # -----

  defmacro namespace(custom_ns) when is_binary(custom_ns) do
    configured_ns = Module.get_attribute(__CALLER__.module, :namespace)
    actual_ns = "#{configured_ns}.#{custom_ns}"
    Module.put_attribute(__CALLER__.module, :namespace, actual_ns)
  end
  defmacro namespace(custom_ns, :override) when is_binary(custom_ns) do
    Module.put_attribute(__CALLER__.module, :namespace, custom_ns)
  end

  # define hash and range keys
  defmacro hash(decl) do
    quote bind_quoted: [decl: decl] do
      {name, type} = case decl do
        [{name, type}] -> {name, type}
        name when is_atom(name) -> {name, :string}
        name when is_binary(name) -> {String.to_atom(name), :string}
      end
      Magneto.Model.__attribute__(__MODULE__, name, type)
      Magneto.Model.__key__(__MODULE__, :hash, name, type)
    end
  end
  defmacro partition_key(decl), do: quote do: hash(unquote(decl))

  defmacro range(decl) do
    quote bind_quoted: [decl: decl] do
      {name, type} = case decl do
        [{name, type}] -> {name, type}
        name when is_atom(name) -> {name, :number}
        name when is_binary(name) -> {String.to_atom(name), :number}
      end
      Magneto.Model.__attribute__(__MODULE__, name, type)
      Magneto.Model.__key__(__MODULE__, :range, name, type)
    end
  end
  defmacro sort_key(decl), do: quote do: range(unquote(decl))

  # define an attribute
  defmacro attribute(decl) do
    quote bind_quoted: [decl: decl] do
      {name, type} = case decl do
        [{name, type}] -> {name, type}
        name when is_atom(name) -> {name, :string}
        name when is_binary(name) -> {String.to_atom(name), :string}
      end
      Magneto.Model.__attribute__(__MODULE__, name, type)
    end
  end

  defmacro attributes(decl) do
    {list_of_attrs, _} = Code.eval_quoted(decl)
    for attr <- list_of_attrs do
      quote do: attribute([unquote(attr)])
    end
  end

  defmacro throughput(read: read, write: write) do
    quote do
      Module.put_attribute(__MODULE__, :throughput, [unquote(read), unquote(write)])
    end
  end

  # defmacro index([{:local, {:__aliases__, _ , [index_name]}}, {:sort, sort} | rest]) do
  #   # Logger.debug("Local index name: #{inspect index_name} for sort: #{sort}, rest: #{inspect rest}")
  #   Magneto.Model.__local_index__(index_name,sort,rest)
  # end
  # defmacro index([{:global, {:__aliases__, _ , [index_name]}}, {:hash, hash}, {:range, range} | rest]) do
  #   # Logger.debug("Global index name: #{inspect index_name} for hash: #{hash} and range: #{range}, rest: #{inspect rest}")
  #   Magneto.Model.__global_index__(index_name,hash,range,rest)
  # end
  defmacro index(kw_list) do
    quote do
      Module.put_attribute(__MODULE__, :all_indexes_def, unquote(kw_list))
    end
  end



  # ----

  def __attribute__(mod, name, type) do
    existing_attributes = Module.get_attribute(mod, :attributes)
    if Keyword.has_key?(existing_attributes, name) do
      raise ArgumentError, "Duplicate attribute #{name}"
    end
    check_type!(type, name)
    Module.put_attribute(mod, :attributes, {name, type})
  end

  def __key__(mod, key_type, name, type) when key_type in [:hash, :range] do
    updated_keys =
      Module.get_attribute(mod, :keys)
        |> Keyword.delete(key_type)
        |> Keyword.put(key_type, {name, type})
        |> Enum.sort
    Module.put_attribute(mod, :keys, updated_keys)
  end

  def __def_struct__(mod) do
    canonical_table_name = Module.get_attribute(mod, :canonical_table_name)
    keys = Module.get_attribute(mod, :keys)
    attribs = Module.get_attribute(mod, :attributes)
    fields = attribs |> Enum.map(fn {name, type} -> {name, Type.default_value(type)} end)

    meta = %TableMetadata{ storage: canonical_table_name,
        keys: keys, attributes: attribs}
    fields = [__meta__: Macro.escape(Macro.escape(meta))] ++ fields # double-escape for the doubly-quoted

    # quote in quote because we eval_quoted the result of the function
    quote bind_quoted: [fields: fields] do
      quote do
        defstruct unquote(fields)
      end
    end
  end

  def __def_indexes__(mod) do
    namespace = Module.get_attribute(mod, :namespace)
    table = Module.get_attribute(mod, :canonical_table_name)
    table_keys = Module.get_attribute(mod, :keys)
    table_atts = Module.get_attribute(mod, :attributes)
    all_indexes_def = Module.get_attribute(mod, :all_indexes_def)
    # all_indexes_def |> Enum.each(&IO.puts("index: #{inspect &1}"))
    all_indexes_def |> Enum.each(&Magneto.Model.__def_index__(mod, namespace, table, table_keys, table_atts, &1))
  end

  def __def_index__(mod, namespace, table, table_keys, table_atts, [{index_type, index_name} | rest]) do
    [hash: {hash,_}, range: {range,_}] = table_keys
    hash = Keyword.get(rest, :hash, hash)
    range = Keyword.get(rest, :range, range)
    projection_type = Keyword.get(rest, :projection, :keys)
    projection = projection(projection_type)
    index_name = String.split(Atom.to_string(index_name), ".") |> List.last
    index_def = %{
      index_name: "#{namespace}.indexes.#{index_name}",
      key_schema: [%{attribute_name: hash, attribute_type: "HASH"},
        %{attribute_name: range, attribute_type: "RANGE"}],
      projection: projection
    }

    case index_type do
      :local ->
        Module.put_attribute(mod, :local_indexes, Macro.escape(index_def))
        :local
      :global ->
        [read: read, write: write] = Keyword.get(rest, :throughput, [read: 2, write: 1])
        index_def = Map.put(index_def, :provisioned_throughput, %{
          read_capacity_units: read,
          write_capacity_units: write,
        })
        Module.put_attribute(mod, :global_indexes, Macro.escape(index_def))
        :global
    end

    fields = table_atts |> Enum.map(fn {name, type} -> {name, Type.default_value(type)} end)
    meta = %IndexMetadata{ type: index_type, table: table, keys: [hash, range], name: index_name,
       attributes: []}
    fields = [__meta__: Macro.escape(Macro.escape(meta))] ++ fields # double-escape for the doubly-quoted
    # Logger.debug "Setting index fields #{inspect fields}"
    quote bind_quoted: [fields: fields, index_name: index_name] do
      Logger.debug "Injecting index module #{inspect index_name}"
      quote do
        Logger.debug "Defining index module #{inspect unquote(index_name)}"
        defmodule unquote(index_name) do
          defstruct unquote(fields)
        end
      end
    end
  end

  def __def_helper_funcs__(mod) do
    namespace = Module.get_attribute(mod, :namespace)
    canonical_table_name = Module.get_attribute(mod, :canonical_table_name)
    keys = Module.get_attribute(mod, :keys)
    attribs = Module.get_attribute(mod, :attributes)
    throughput = Module.get_attribute(mod, :throughput)
    global_indexes = Module.get_attribute(mod, :global_indexes)
    local_indexes = Module.get_attribute(mod, :local_indexes)
    quote do
      def __namespace__, do: unquote(namespace)
      def __canonical_name__, do: unquote(canonical_table_name)
      def __keys__, do: unquote(keys)
      def __attributes__, do: unquote(attribs)
      def __throughput__, do: unquote(throughput)
      def __global_indexes__, do: unquote(global_indexes)
      def __local_indexes__, do: unquote(local_indexes)
    end
  end


  def __local_index__(index_name,sort,rest) do
    idx_def = %{
      index_name: to_string(index_name)
    }
  end

  # -----


  defp projection(:keys), do: %{ projection_type: "KEYS_ONLY" }
  defp projection(:all), do: %{ projection_type: "ALL" }
  defp projection(atts) when is_list(atts) do
    %{ projection_type: "INCLUDE", non_key_attributes: atts |> Enum.map(&Atom.to_string(&1))}
  end

  defp check_type!(type, name) do
    cond do
      type in [:number, :string, :boolean, :binary] ->
        {:native, type}
      type in [:date, :timestamp, :uuid, :any] ->
        {:custom, type}
      is_list(type) and length(type) == 1 ->
        [inner_type] = type
        {:composite, check_type!(inner_type, name)}
      is_map(type) ->
        {:composite, Enum.map(type, fn {n,t} -> check_type!(t, n) end) }
      is_atom(type) ->
        if Code.ensure_compiled?(type) and function_exported?(type, :type, 0) do
          {:composite, type}
        else
          raise ArgumentError, "invalid model #{inspect type} for attribute #{inspect name}"
        end
      true ->
        raise ArgumentError, "invalid type #{inspect type} for attribute #{inspect name}"
    end
  end


end
