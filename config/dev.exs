use Mix.Config

config :nebulex_fdb_adapter, NebulexFdbAdapter.Cache,
  cluster_file_path: "/etc/foundationdb/fdb.cluster",
  db_path: ["nebulex", "test"]
