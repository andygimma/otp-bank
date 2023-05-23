defmodule Bank.Server do
  @moduledoc """
  This supervisor is responsible for:
  - A supervisor monitoring bank processes.
  - A Registry providing a key-value store for bank processes.
  """
  use Application

  @registry :bank_registry

  def start() do
    children = [
      {Bank.BankSupervisor, []},
      {Registry, [keys: :unique, name: @registry]}
    ]

    # :one_for_one strategy: if a child process crashes, only that process is restarted.
    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
