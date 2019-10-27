# NebulexFdbAdapter

**TODO: Add description**

## Benchmarking

```
mix -iex -S
NebulexFdbAdapter.Bench.bench
Rscript deps/basho_bench*/priv/summary.r -i ./tests/current/
```


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `nebulex_fdb_adapter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nebulex_fdb_adapter, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/nebulex_fdb_adapter](https://hexdocs.pm/nebulex_fdb_adapter).

