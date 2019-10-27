defmodule NebulexFdbAdapterTest do
  use ExUnit.Case
  doctest NebulexFdbAdapter

  alias NebulexFdbAdapter.TestCache, as: Cache

  setup_all do
    Cache.start_link()
    NebulexFdbAdapter.Pool.start(nil, nil)
    :ok
  end

  test "get an unknown key" do
    Cache.delete("test")
    assert Cache.get("test") == nil
  end

  test "get a  key" do
    Cache.get("test")
  end

  test "set, get, and delete" do
    assert Cache.delete("test") == "test"
    assert Cache.set("test", "hello") == "hello"
    assert Cache.get("test") == "hello"
    assert Cache.delete("test") == "test"
    assert Cache.get("test") == nil
  end

  test "set, get, and delete number" do
    assert Cache.set("float_number", 100.0) == 100.0
    assert Cache.delete("float_number") == "float_number"
    assert Cache.set("float_number", 100.0) == 100.0
    assert Cache.get("float_number") == 100.0
  end

  test "set and get many" do
    assert Cache.set("1", "one") == "one"
    assert Cache.set("2", "two") == "two"
    assert Cache.set("3", "three") == "three"
    assert Cache.get_many(["1", "2", "3"]) == %{"1" => "one", "2" => "two", "3" => "three"}
  end

  test "has unknown key" do
    assert Cache.delete("appleappleapple") == "appleappleapple"
    assert Cache.has_key?("appleappleapple") == false
  end

  test "has key" do
    assert Cache.set("1", "one") == "one"
    assert Cache.has_key?("1") == true
  end

  test "take key" do
    assert Cache.set("take", "one") == "one"
    assert Cache.take("take") == "one"
  end

  test "take number key" do
    assert Cache.set("take", 1) == 1
    assert Cache.take("take") == 1
  end

  test "update counter" do
    assert Cache.set("counter", 2) == 2
    assert Cache.update_counter("counter", -1) == 1
    assert Cache.update_counter("counter", 1) == 2
  end

  test "set many and get many" do
    assert Cache.set_many(%{"1" => "one", "2" => "two", "3" => "three"})
    assert Cache.get_many(["1", "2", "3"]) == %{"1" => "one", "2" => "two", "3" => "three"}
  end
end
