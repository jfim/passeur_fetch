defmodule PasseurFetch.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: PasseurFetch.Finch}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: PasseurFetch.Supervisor)
  end
end
