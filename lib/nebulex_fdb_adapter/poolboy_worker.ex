defmodule NebulexFdbAdapter.Worker do
  use GenServer
  alias Nebulex.Object
  alias Nebulex.Object

  alias FDB.{Directory, Transaction, Database, Future}
  alias FDB.Coder.{Subspace}

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [])
  end

  def init(_opt) do
    {:ok, nil}
  end

  def handle_call({:get, cache, key, _opts}, _from, state) do
    ets_key = :erlang.term_to_binary(key)

    ets_value =
      Database.transact(
        cache.__db__,
        fn transaction ->
          Transaction.get(transaction, ets_key)
        end
      )

    value =
      case ets_value do
        nil -> nil
        value -> :erlang.binary_to_term(value, [:safe])
      end

    {:reply, %Object{key: key, value: value}, state}
  end

  def handle_call({:delete, cache, key, _opts}, _from, state) do
    key = :erlang.term_to_binary(key)

    result =
      FDB.Database.transact(
        cache.__db__,
        fn transaction ->
          Transaction.clear(transaction, key)
        end
      )

    {:reply, result, state}
  end

  def handle_call({:set, cache, %Object{key: key, value: value}, _opts}, _from, state) do
    key = :erlang.term_to_binary(key)
    value = :erlang.term_to_binary(value)

    err =
      FDB.Database.transact(
        cache.__db__,
        fn transaction ->
          Transaction.set(transaction, key, value)
        end
      )

    result =
      case err do
        :ok -> true
        nil -> false
      end

    {:reply, result, state}
  end

  def handle_call({:get_many, cache, list, _opts}, _from, state) do
    values =
      Enum.map(list, fn key ->
        key = :erlang.term_to_binary(key)

        Database.transact(
          cache.__db__,
          fn transaction ->
            Transaction.get_q(transaction, key)
          end
        )
      end)

    result =
      Enum.zip(list, values)
      |> List.foldr(%{}, fn {key, future}, acc ->
        ets_value = Future.await(future)

        value =
          case ets_value do
            nil -> nil
            ets_value -> :erlang.binary_to_term(ets_value, [:safe])
          end

        Map.put(acc, key, %Object{key: key, value: value})
      end)

    {:reply, result, state}
  end

  def handle_call({:set_many, cache, list, _opts}, _from, state) do
    values =
      Enum.map(list, fn %Object{key: key, value: value} ->
        value = :erlang.term_to_binary(value)
        key = :erlang.term_to_binary(key)
        transaction = FDB.Transaction.create(cache.__db__)
        :ok = FDB.Transaction.set(transaction, key, value)
        Transaction.commit_q(transaction)
      end)

    result =
      Enum.zip(list, values)
      |> Enum.reduce([], fn {key, future}, acc ->
        ets_value = Future.await(future)

        case ets_value do
          :ok -> acc
          _ -> acc ++ [key]
        end
      end)

    result =
      case result do
        [] -> :ok
        _ -> {:error, result}
      end

    {:reply, result, state}
  end

  def handle_call({:has_key, cache, key}, _from, state) do
    ets_key = :erlang.term_to_binary(key)

    ets_value =
      Database.transact(
        cache.__db__,
        fn transaction ->
          Transaction.get(transaction, ets_key)
        end
      )

    result =
      case ets_value do
        nil -> false
        _ -> true
      end

    {:reply, result, state}
  end

  def handle_call({:take, cache, key}, _from, state) do
    key = :erlang.term_to_binary(key)

    value =
      FDB.Database.transact(
        cache.__db__,
        fn transaction ->
          future = Transaction.get_q(transaction, key)
          Transaction.clear(transaction, key)
          Future.await(future)
        end
      )

    result =
      case value do
        nil -> nil
        value -> %Object{key: key, value: :erlang.binary_to_term(value, [:safe])}
      end

    {:reply, result, state}
  end

  def handle_call({:update_counter, cache, key, incr, _opts}, _from, state) do
    key = :erlang.term_to_binary(key)

    result =
      FDB.Database.transact(
        cache.__db__,
        fn transaction ->
          ets_value = Transaction.get(transaction, key)

          case ets_value do
            nil ->
              nil

            _ ->
              orig_value = :erlang.binary_to_term(ets_value, [:safe])
              new_value = orig_value + incr
              ets_new_value = :erlang.term_to_binary(new_value)
              err = Transaction.set(transaction, key, ets_new_value)

              case err do
                :ok -> new_value
                _ -> nil
              end
          end
        end
      )

    {:reply, result, state}
  end
end
