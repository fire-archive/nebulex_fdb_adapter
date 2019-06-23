defmodule NebulexFdbAdapter.TestCache do
  use Nebulex.Cache,
    otp_app: :nebulex_fdb_adapter,
    adapter: NebulexFdbAdapter
end
