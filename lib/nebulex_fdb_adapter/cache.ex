defmodule NebulexFdbAdapter.Cache do
  import NebulexFdbAdapter
  use Nebulex.Cache,
    otp_app: :nebulex_fdb_adapter,
    adapter: NebulexFdbAdapter,
    gc_interval: 86_400
end
