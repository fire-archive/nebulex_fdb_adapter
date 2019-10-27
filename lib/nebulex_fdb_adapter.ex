defmodule NebulexFdbAdapter do
  @moduledoc """
  Documentation for NebulexFdbAdapter.
  """

  # Inherit default transaction implementation
  use Nebulex.Adapter.Transaction

  # Provide Cache Implementation
  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Queryable

  alias FDB.{Directory, Transaction, Database, Future}
  alias FDB.Coder.{Subspace}

  ## Adapter

  @impl true
  defmacro __before_compile__(env) do
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
    FDB.start(610)
    cluster_file_path = Keyword.fetch!(opts, :cluster_file_path)
    db_path = Keyword.fetch!(opts, :db_path)

    db = Database.create(cluster_file_path)

    root = Directory.new()

    dir =
      Database.transact(db, fn tr ->
        Directory.create_or_open(root, tr, db_path)
      end)

    subspace = Subspace.new(dir)
    coder = Transaction.Coder.new(subspace)
    connected_db = Database.set_defaults(db, %{coder: coder})

    :ets.new(:nebulex_fdb_adapter, [
      :set,
      :public,
      {:write_concurrency, true},
      {:read_concurrency, true},
      :named_table
    ])

    true = :ets.insert(:nebulex_fdb_adapter, {:db, connected_db})
    {:ok, []}
  end

  @impl true

  def all(_cache, _query, _opts) do
    raise "Not Implemented."
  end

  @impl true
  def get(cache, key, _opts) do
    ets_key = :erlang.term_to_binary(key)

    ets_value =
      Database.transact(
        cache.__db__,
        fn transaction ->
          Transaction.get(transaction, ets_key)
        end
      )

    value =
      case ets_value do
        nil -> nil
        value -> :erlang.binary_to_term(value, [:safe])
      end

    %Nebulex.Object{key: key, value: value}
  end

  @impl true
  def get_many(cache, list, _opts) do
    values =
      Enum.map(list, fn key ->
        key = :erlang.term_to_binary(key)

        Database.transact(
          cache.__db__,
          fn transaction ->
            Transaction.get_q(transaction, key)
          end
        )
      end)

    Enum.zip(list, values)
    |> List.foldr(%{}, fn {key, future}, acc ->
      ets_value = Future.await(future)
      value =
        case ets_value do
          nil -> nil
          ets_value -> :erlang.binary_to_term(ets_value, [:safe])
        end

      Map.put(acc, key, %Nebulex.Object{key: key, value: value})
    end)
  end

  @impl true
  def set_many(cache, list, _opts) do
    values =
      Enum.map(list, fn %Nebulex.Object{key: key, value: value} ->
        value = :erlang.term_to_binary(value)
        key = :erlang.term_to_binary(key)
        transaction = FDB.Transaction.create(cache.__db__)
        :ok = FDB.Transaction.set(transaction, key, value)
        Transaction.commit_q(transaction)
      end)

    result =
      Enum.zip(list, values)
      |> Enum.reduce([], fn {key, future}, acc ->
        ets_value = Future.await(future)
        case ets_value do
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
  def set(cache, %Nebulex.Object{key: key, value: value}, _opts) do
    key = :erlang.term_to_binary(key)
    value = :erlang.term_to_binary(value)

    err =
      FDB.Database.transact(
        cache.__db__,
        fn transaction ->
          Transaction.set(transaction, key, value)
        end
      )

    case err do
      :ok -> true
      nil -> false
    end
  end

  @impl true
  def has_key?(cache, key) do
    ets_key = :erlang.term_to_binary(key)

    ets_value =
      Database.transact(
        cache.__db__,
        fn transaction ->
          Transaction.get(transaction, ets_key)
        end
      )

    case ets_value do
      nil -> false
      _ -> true
    end
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
    key = :erlang.term_to_binary(key)

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
    key = :erlang.term_to_binary(key)

    value =
      FDB.Database.transact(
        cache.__db__,
        fn transaction ->
          future = Transaction.get_q(transaction, key)
          Transaction.clear(transaction, key)
          Future.await(future)
        end
      )

    case value do
      nil -> nil
      value -> %Nebulex.Object{key: key, value: :erlang.binary_to_term(value, [:safe])}
    end
  end

  @impl true
  def update_counter(cache, key, incr, _opts) do
    key = :erlang.term_to_binary(key)

    FDB.Database.transact(
      cache.__db__,
      fn transaction ->
        ets_value = Transaction.get(transaction, key)

        case ets_value do
          nil ->
            nil

          _ ->
            orig_value = :erlang.binary_to_term(ets_value, [:safe])
            new_value = orig_value + incr
            ets_new_value = :erlang.term_to_binary(new_value)
            err = Transaction.set(transaction, key, ets_new_value)

            case err do
              :ok -> new_value
              _ -> nil
            end
        end
      end
    )
  end

  # Database.transact(db, fn tr ->
  #   Directory.list(root, tr, ["nebulex"])
  # end)
end
