defmodule NebulexFdbAdapter do
  @moduledoc """
  Documentation for NebulexFdbAdapter.
  """

  # Inherit default transaction implementation
  use Nebulex.Adapter.Transaction

  # Provide Cache Implementation
  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Queryable

  alias Nebulex.Object

  alias FDB.{Directory, Transaction, Database, Cluster, Future}
  alias FDB.Coder.{Subspace}

  ## Adapter

  @impl true
  defmacro __before_compile__(env) do
    # TODO move to init
    :ok = FDB.start(600)
    cache = env.module
    config = Module.get_attribute(cache, :config)
    path = Keyword.fetch!(config, :db_path)
    cluster_file_path = Keyword.fetch!(config, :cluster_file_path)

    quote do
      def __db_path__, do: unquote(path)

      def __cluster_file_path__, do: unquote(cluster_file_path)

      def __db__ do
        :ets.lookup_element(:nebulex_fdb_adapter, :db, 2)
      end
    end
  end

  @impl true
  def init(opts) do
    cluster_file_path = Keyword.fetch!(opts, :cluster_file_path)
    db_path = Keyword.fetch!(opts, :db_path)

    db =
      Cluster.create(cluster_file_path)
      |> Database.create()

    root = Directory.new()

    dir =
      Database.transact(db, fn tr ->
        Directory.create_or_open(root, tr, db_path)
      end)

    subspace = Subspace.new(dir)
    coder = Transaction.Coder.new(subspace)
    connected_db = Database.set_defaults(db, %{coder: coder})
    :ets.new(:nebulex_fdb_adapter, [:set, :public, {:read_concurrency, true}, :named_table])
    true = :ets.insert(:nebulex_fdb_adapter, {:db, connected_db})
    {:ok, []}
  end

  @impl true

  def all(_cache, _query, _opts) do
    raise "Not Implemented."
  end

  @impl true
  def get(cache, key, _opts) do
    value = Database.transact(
      cache.__db__,
      fn transaction ->
        Transaction.get(transaction, key)
      end
    )
    case value do
    nil -> nil
    _ -> :erlang.binary_to_term(value, [:safe])
    end
  end

  @impl true
  def get_many(cache, list, _opts) do
    values =
      Enum.map(list, fn key ->
        Database.transact(
          cache.__db__,
          fn transaction ->
            Transaction.get(transaction, key)
          end
        )
      end)

    Enum.zip(list, values)
    |> List.foldr(%{}, fn {key, value}, acc ->
      value = :erlang.binary_to_term(value, [:safe])
      Map.put(acc, key, %Object{key: key, value: value})
    end)
  end

  @impl true
  def set_many(cache, list, _opts) do
    keys = Enum.map(list, fn
      %Object{key: key} -> key
   end)

    values =
      Enum.map(list, fn %Object{key: key, value: value} ->
        value = :erlang.term_to_binary(value)
        Database.transact(
          cache.__db__,
          fn transaction ->
            Transaction.set(transaction, key, value)
          end
        )
      end)

    result =
      Enum.zip(keys, values)
      |> Enum.reduce([], fn {key, value}, acc ->
        case value do
          :ok -> acc
          _ -> acc ++ [key]
        end
      end)

    case result do
      [] -> :ok
      _ -> {:error, result}
    end
  end

  @impl true
  def set(cache, %Object{key: key, value: value}, _opts) do
    value = :erlang.term_to_binary(value)
    FDB.Database.transact(
      cache.__db__,
      fn transaction ->
        Transaction.set(transaction, key, value)
      end
    )
  end

  @impl true
  def has_key?(cache, key) do
    get(cache, key, []) != nil
  end

  @impl true
  def size(_cache) do
    raise "Not Implemented."
  end

  @impl true
  def flush(_cache) do
    raise "Not Implemented."
  end

  @impl true
  def delete(cache, key, _opts) do
    FDB.Database.transact(
      cache.__db__,
      fn transaction ->
        Transaction.clear(transaction, key)
      end
    )
  end

  @impl true
  def expire(_cache, _key, _ttl) do
    raise "Not Implemented. Will be implemented on need."
  end

  @impl true
  def object_info(_cache, _key, _attr) do
    raise "Not Implemented. Will be implemented on need."
  end

  @impl true
  def stream(_cache, _query, _opts) do
    raise "Not Implemented. Will be implemented on need."
  end

  @impl true
  def take(cache, key, _opts) do
    value =
      FDB.Database.transact(
        cache.__db__,
        fn transaction ->
          future = Transaction.get_q(transaction, key)
          Transaction.clear(transaction, key)
          Future.await(future)
        end
      )
    value = :erlang.binary_to_term(value, [:safe])
    %Object{key: key, value: value}
  end

  @impl true
  def update_counter(cache, key, incr, _opts) do
    FDB.Database.transact(
      cache.__db__,
      fn transaction ->
        orig_value = Transaction.get(transaction, key)
        |> :erlang.binary_to_term([:safe])
        new_value = orig_value + incr
        ets_value = :erlang.term_to_binary(new_value)
        err = Transaction.set(transaction, key, ets_value)
        case err do
          :ok -> new_value
          _ -> nil
        end
      end
    )
  end

  # Database.transact(db, fn tr ->
  #   Directory.list(root, tr, ["nebulex"])
  # end)
end
