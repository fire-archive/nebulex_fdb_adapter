for file <- File.ls!("test/support") do
  {file, Code.require_file("../test/support/" <> file, __DIR__)}
end

{:ok, _cache} = NebulexFdbAdapter.TestCache.start_link()
{:ok, _pool} = NebulexFdbAdapter.Pool.start(nil, nil)
# init caches
Enum.each(1..5000, fn x ->
  NebulexFdbAdapter.TestCache.set(x, x)
end)

# samples
keys = Enum.to_list(1..1_000_000)
bulk = for x <- 1..10, do: {x, x}

inputs = %{
  "Distributed Cache" => NebulexFdbAdapter.TestCache
}

benchmarks = %{
  "get" => fn {cache, random} ->
    cache.get(random)
  end,
  "set" => fn {cache, random} ->
    cache.set(random, random)
  end,
  "add" => fn {cache, random} ->
    cache.add(random, random)
  end,
  # "replace" => fn {cache, random} ->
  #   cache.replace(random, random)
  # end,
  # "add_or_replace!" => fn {cache, random} ->
  #   cache.add_or_replace!(random, random)
  # end,
  "get_many" => fn {cache, _random} ->
    cache.get_many(1..10)
  end,
  "set_many" => fn {cache, _random} ->
    cache.set_many(bulk)
  end,
  "delete" => fn {cache, random} ->
    cache.delete(random)
  end,
  "take" => fn {cache, random} ->
    cache.take(random)
  end,
  "has_key?" => fn {cache, random} ->
    cache.has_key?(random)
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
  "update_counter" => fn {cache, _random} ->
    cache.update_counter(:counter, 1)
  end,
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
    {cache, Enum.random(keys)}
  end,
  parallel: 1,
  time: 10,
  formatters: [
    Benchee.Formatters.Console,
    Benchee.Formatters.HTML
  ],
  print: [
    fast_warning: false
  ]
)
