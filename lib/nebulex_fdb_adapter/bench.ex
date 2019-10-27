defmodule NebulexFdbAdapter.Bench.NebulexFdb do
  # See https://github.com/cabol/nebulex_examples/tree/master/nebulex_bench

  @cache NebulexFdbAdapter.Cache

  def new(_state) do
    {:ok, %{}}
  end

  def run(:put, key_gen, value_gen, state) do
    value = value_gen.()
    ^value = @cache.set(key_gen.(), value)
    {:ok, state}
  end

  def run(:get, key_gen, _value_gen, state) do
    @cache.get(key_gen.())
    {:ok, state}
  end
end
