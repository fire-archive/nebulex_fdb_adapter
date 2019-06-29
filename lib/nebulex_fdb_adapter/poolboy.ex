defmodule NebulexFdbAdapter.Pool do
  @moduledoc false

  use Application

  defp poolboy_config do
    [
      {:name, {:local, :worker}},
      {:worker_module, NebulexFdbAdapter.Worker},
      {:size, 100},
      {:max_overflow, 2}
    ]
  end

  def start(_type, _args) do
    children = [
      :poolboy.child_spec(:worker, poolboy_config())
    ]

    opts = [strategy: :one_for_one, name: NebulexFdbAdapter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
