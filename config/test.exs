use Mix.Config

config :nebulex_fdb_adapter, NebulexFdbAdapter.TestCache,
  cluster_file_path: "C:\\ProgramData\\foundationdb\\fdb.cluster",
  db_path: ["nebulex", "test"]