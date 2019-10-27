defmodule NebulexFdbAdapter.MixProject do
  use Mix.Project

  def project do
    [
      app: :nebulex_fdb_adapter,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp nebulex_opts do
    if System.get_env("NBX_TEST") do
      [github: "cabol/nebulex", tag: "v1.0.1"]
    else
      "~> 1.1"
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:fdb, github: "ananthakumaran/fdb", branch: "master"},
      # This is because the adapter tests need some support modules and shared
      # tests from nebulex dependency, and the hex dependency doesn't include
      # the test folder. Hence, to run the tests it is necessary to fetch
      # nebulex dependency directly from GH.
      {:nebulex, nebulex_opts()},
      {:basho_bench, github: "mrallen1/basho_bench", branch: "mra-rebar3"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
