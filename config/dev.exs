use Mix.Config

config :nebulex_fdb_adapter, NebulexFdbAdapter.TestCache,
  cluster_file_path: "/usr/local/etc/foundationdb/fdb.cluster",
  db_path: ["nebulex", "test"]
