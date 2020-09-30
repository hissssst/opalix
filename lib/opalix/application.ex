defmodule Opalix.Application do

  @moduledoc """
  Application which starts the opalix pool
  """

  use Application

  def start(_type, _args) do

    # Workaround to start local server in testing enviroment
    if Mix.env() == :test do
      Port.open({:spawn, "opa run --server test/test.rego"}, [])
      Process.sleep(2_000)
    end

    configuration = Application.get_env(:opalix, :connection_pool)
    children = [
      {Opalix.Connection.Pool, configuration}
    ]

    opts = [strategy: :one_for_one, name: Opalix.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
