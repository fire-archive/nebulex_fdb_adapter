defmodule Mix.Tasks.Bench do
  use Mix.Task

  def run(_) do
    NebulexFdbAdapter.Cache.start_link()
    :basho_bench.start()
    :basho_bench.setup_benchmark([])
    :basho_bench.run_benchmark(["./config/bench/nebulex_fdb.config"])
  end
end
