defmodule NebulexFdbAdapterTest do
  use ExUnit.Case
  doctest NebulexFdbAdapter

  alias NebulexFdbAdapter.TestCache, as: Cache

  setup do
    {:ok, pid} = Cache.start_link()
    # Cache.flush()
    :ok

    on_exit(fn ->
      _ = :timer.sleep(100)
      if Process.alive?(pid), do: Cache.stop(pid)
    end)
  end

  test "get an unknown key" do
    Cache.delete("test")
    assert Cache.get("test") == nil
  end

  test "set, get, delete" do
    assert Cache.set("test", "test") == "test"
    assert Cache.get("test") == "test"
    assert Cache.delete("test") == nil
    assert Cache.get("test") == nil
  end
end
