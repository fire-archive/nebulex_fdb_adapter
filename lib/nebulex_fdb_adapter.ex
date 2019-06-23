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

  alias FDB.{Directory, Transaction, Database}
  alias FDB.Coder.{Subspace}

  ## Adapter

  @impl true
  defmacro __before_compile__(env) do
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
      FDB.Cluster.create(cluster_file_path)
      |> FDB.Database.create()

    root = Directory.new()

    dir =
      Database.transact(db, fn tr ->
        Directory.create_or_open(root, tr, db_path)
      end)
    subspace = Subspace.new(dir)
    coder = Transaction.Coder.new(subspace)
    connected_db = FDB.Database.set_defaults(db, %{coder: coder})
    :ets.new(:nebulex_fdb_adapter, [:set, :public, {:read_concurrency, true}, :named_table])
    true = :ets.insert(:nebulex_fdb_adapter, {:db, connected_db})
    {:ok, []}
  end

  @impl true
  def get(cache, key, opts) do
    FDB.Database.transact(cache.__db__,
      fn transaction ->
        FDB.Transaction.get(transaction, key)
      end
    )
  end

  @impl true
  def set(cache, %Object{key: key, value: value}, _opts) do
    FDB.Database.transact(cache.__db__,
    fn transaction ->
      FDB.Transaction.set(transaction, key, value)
    end
    )
  end

  @impl true
  def delete(cache, key, _opts) do
    FDB.Database.transact(cache.__db__,
    fn transaction ->
      FDB.Transaction.clear(transaction, key)
    end
    )
  end

  # Database.transact(db, fn tr ->
  #   Directory.list(root, tr, ["nebulex"])
  # end)
end
