defmodule NebulexFdbAdapter.Bench do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(NebulexFdbAdapter.Cache, [])
    ]

    opts = [strategy: :one_for_one, name: Hello.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def bench() do
    :basho_bench.start()
    :basho_bench.setup_benchmark([])
    :basho_bench.run_benchmark(["./config/bench/nebulex_fdb.config"])
  end
end
