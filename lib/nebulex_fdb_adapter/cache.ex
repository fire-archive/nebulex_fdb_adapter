defmodule NebulexFdbAdapter.Cache do
  import NebulexFdbAdapter
  use Nebulex.Cache,
    otp_app: :nebulex_fdb_adapter,
    adapter: NebulexFdbAdapter,
    cluster_file_path: "/etc/foundationdb/fdb.cluster",
    db_path: ["nebulex", "test"],
    gc_interval: 86_400
end
