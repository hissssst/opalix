defmodule Opalix.Connection.Pool do

  @moduledoc """
  Connection pool with registry with
  random worker anycast selection mechanism
  """

  alias Opalix.Connection, as: OpaConnection
  use Supervisor

  @compile {:inline, worker_name: 1, random_worker: 0}

  @type size         :: pos_integer()
  @type path         :: String.t()
  @type body         :: String.t()
  @type content_type :: String.t()
  @type option ::
   {:size, size()}
    | OpaConnection.option()

  @type worker_name :: {:via, Registry, {__MODULE__.Registry, pos_integer()}}

  # Public API

  @doc """
  Perform delete request to Open Policy Agent
  """
  @spec delete(path()) :: OpaConnection.reply()
  def delete(path) do
    random_worker()
    |> GenServer.call({:request, "DELETE", path})
  end

  @doc """
  Perform get request to Open Policy Agent
  """
  @spec get(path()) :: OpaConnection.reply()
  def get(path) do
    random_worker()
    |> GenServer.call({:request, "GET", path})
  end

  @doc """
  Perform put request to Open Policy Agent
  """
  @spec put(path(), body(), content_type()) :: OpaConnection.reply()
  def put(path, body, content_type) do
    random_worker()
    |> GenServer.call({:request, "PUT", path, body, content_type})
  end

  @doc """
  Perform patch request to Open Policy Agent
  """
  @spec patch(path(), body(), content_type()) :: OpaConnection.reply()
  def patch(path, body, content_type) do
    random_worker()
    |> GenServer.call({:request, "PATCH", path, body, content_type})
  end

  @doc """
  Perform post request to Open Policy Agent
  """
  @spec post(path(), body(), content_type()) :: OpaConnection.reply()
  def post(path, body, content_type) do
    random_worker()
    |> GenServer.call({:request, "POST", path, body, content_type})
  end

  # Supervisor / Registry API

  @spec start_link([option()]) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {size, opts} = Keyword.pop!(opts, :size)

    workers_supervisor_spec = %{
      id: :workers_supervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [workers_specs(size, opts), [strategy: :one_for_one]]}
    }

    children = [
      {Registry, keys: :unique, name: __MODULE__.Registry},
      workers_supervisor_spec
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  # Helpers

  @spec workers_specs(size(), [OpaConnection.option()])
    :: [Supervisor.child_spec()]
  defp workers_specs(size, opts) do
    Enum.map(1..size, fn i ->
      {OpaConnection, [{:name, worker_name(i)} | opts]}
    end)
  end

  @spec worker_name(pos_integer()) :: worker_name()
  defp worker_name(index) do
    {:via, Registry, {__MODULE__.Registry, index}}
  end

  @spec random_worker() :: worker_name()
  defp random_worker() do
    __MODULE__.Registry
    |> Registry.count()
    |> :rand.uniform()
    |> worker_name()
  end

end
