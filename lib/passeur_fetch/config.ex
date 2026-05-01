defmodule PasseurFetch.Config do
  @moduledoc "Runtime configuration read from environment variables."

  @host_env "PASSE_PARTOUT_HOST"
  @token_env "PASSE_PARTOUT_BEARER_TOKEN"

  @spec passe_partout_host() :: String.t() | nil
  def passe_partout_host, do: System.get_env(@host_env)

  @spec passe_partout_bearer_token() :: String.t() | nil
  def passe_partout_bearer_token, do: System.get_env(@token_env)
end
