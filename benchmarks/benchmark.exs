for file <- File.ls!("test/support") do
  {file, Code.require_file("../test/support/" <> file, __DIR__)}
end

defmodule Benchee.Formatters.FDB do
  @behaviour Benchee.Formatter

  def format(suite, _) do
    concurrency = suite.configuration.parallel

    Enum.map(suite.scenarios, fn s ->
      stats = s.run_time_data.statistics

      ops_scale =
        cond do
          s.job_name =~ "10 op" -> 10 * concurrency
          s.job_name =~ "get_many" -> 10 * concurrency
          s.job_name =~ "set_many" -> 10 * concurrency
          true -> concurrency
        end

      %{
        name: s.job_name,
        concurrency: concurrency,
        ops: ops_scale * stats.ips,
        # average: stats.average,
        # max: stats.maximum,
        # min: stats.minimum,
        # deviation: stats.std_dev_ratio
      }
    end)
  end

  def write(scenarios, _) do
    pattern = "~*s~*s~*s~*s~*s~*s~*s\n"
    widths = [15, 15, 10, 13, 10, 10, 12]

    format(pattern, widths, [
      "name",
      "concurrency",
      "ops/s",
      "average ms",
      "max ms",
      "min ms",
      "deviation"
    ])

    Enum.each(scenarios, fn s ->
      File.write!("result.ndjson", [Jason.encode!(s), "\n"], [:append])

      format(pattern, widths, [
        s.name,
        to_string(s.concurrency),
        to_string(trunc(s.ops)),
        Float.to_string(Float.round(s.average, 3)),
        Float.to_string(Float.round(s.max, 3)),
        Float.to_string(Float.round(s.min, 3)),
        to_charlist(" ±" <> Float.to_string(Float.round(s.deviation, 2)) <> "%")
      ])
    end)
  end

  defp format(pattern, widths, values) do
    args =
      Enum.with_index(values)
      |> Enum.map(fn {value, i} ->
        [Enum.at(widths, i), value]
      end)
      |> Enum.concat()

    :io.fwrite(pattern, args)
  end
end

{:ok, _cache} = NebulexFdbAdapter.TestCache.start_link()
{:ok, _pool} = NebulexFdbAdapter.Pool.start(nil, nil)

# https://github.com/ananthakumaran/fdb/blob/master/bench.exs#L75
defmodule Utils do
  @key_size 0..100_000
  @keys Enum.map(@key_size, fn _ -> "fdb:" <> :crypto.strong_rand_bytes(12) end)
        |> List.to_tuple()

  @value_size 0..10000
  @values Enum.map(@value_size, fn _ -> :crypto.strong_rand_bytes(Enum.random(8..100)) end)
          |> List.to_tuple()

  def random_value do
    elem(@values, Enum.random(@value_size))
  end

  def random_key do
    elem(@keys, Enum.random(@key_size))
  end
end

inputs = %{
  "Distributed Cache" => NebulexFdbAdapter.TestCache
}

benchmarks = %{
  "get" => fn {cache} ->
    cache.get(Utils.random_key())
  end,
  "set" => fn {cache} ->
    cache.set(Utils.random_key(), Utils.random_value())
  end,
  "add" => fn {cache} ->
    cache.add(Utils.random_key(), Utils.random_value())
  end,
  # "replace" => fn {cache, random} ->
  #   cache.replace(random, random)
  # end,
  # "add_or_replace!" => fn {cache, random} ->
  #   cache.add_or_replace!(random, random)
  # end,
  # "get_many" => fn {cache, _random} ->
  #   cache.get_many(1..10)
  # end,
  # "set_many" => fn {cache, _random} ->
  #   cache.set_many(bulk)
  #   cache.set_many(1..10)
  # end,
  "delete" => fn {cache} ->
    cache.delete(Utils.random_key())
  end,
  "take" => fn {cache} ->
    cache.take(Utils.random_key())
  end,
  "has_key?" => fn {cache} ->
    cache.has_key?(Utils.random_key())
  end,
  # "size" => fn {cache, _random} ->
  #   cache.size()
  # end,
  # "object_info" => fn {cache, random} ->
  #   cache.object_info(random, :ttl)
  # end,
  # "expire" => fn {cache, random} ->
  #   cache.expire(random, 1)
  # end,
  # "get_and_update" => fn {cache, random} ->
  #   cache.get_and_update(random, &Dist.get_and_update_fun/1)
  # end,
  # "update" => fn {cache, random} ->
  #   cache.update(random, 1, &Kernel.+(&1, 1))
  # end,
  # "update_counter" => fn {cache} ->
  #   cache.update_counter(Utils.random_key(), 1)
  # end,
  # "all" => fn {cache, _random} ->
  #   cache.all()
  # end,
  # "transaction" => fn {cache, random} ->
  #   cache.transaction(
  #     fn ->
  #       cache.update_counter(random, 1)
  #       :ok
  #     end,
  #     keys: [random]
  #   )
  # end
}

Benchee.run(
  benchmarks,
  inputs: inputs,
  before_scenario: fn cache ->
    {cache}
  end,
  parallel: 100,
  time: 10,
  formatters: [
    Benchee.Formatters.FDB,
  ],
  print: [
    fast_warning: false
  ]
)
