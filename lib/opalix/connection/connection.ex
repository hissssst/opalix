defmodule Opalix.Connection do

  @moduledoc """
  Connection implementing connection to Open Policy Agent
  This connection performs two requests with OPA flavour
  """

  use Connection
  require Logger

  @compile {:inline, new_response: 1}

  @enforce_keys [:hostname, :scheme, :port]
  defstruct [
    conn:              :disconnected,
    reconnect_timeout: 2000,
    requests:          %{}
  ] ++ @enforce_keys

  @type state :: %__MODULE__{
    conn:              Mint.HTTP.t() | :disconnected,
    port:              non_neg_integer(),
    hostname:          String.t(),
    scheme:            :http | :https,
    reconnect_timeout: pos_integer(),
    requests:          %{}
  }

  @type option ::
    {:port, non_neg_integer()}
    | {:name, __MODULE__.Pool.worker_name()}
    | {:hostname, String.t()}
    | {:scheme, :http | :https}
    | {:reconnect_timeout, pos_integer()}

  @type response :: %{
    from: GenServer.from(),
    body: String.t(),
    status: pos_integer() | nil
  }

  @type reply ::
    {:ok, response()}
    | {:error, response(), term()}
    | {:error, Mint.Types.error()}

  @options_keys ~w(port hostname scheme reconnect_timeout)a

  # Connection

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop!(opts, :name)
    Connection.start_link(__MODULE__, Keyword.take(opts, @options_keys), name: name)
  end

  def init(opts) do
    state = struct!(__MODULE__, opts)
    {:connect, :init, state}
  end

  def connect(_, %{
    hostname: hostname,
    scheme: scheme,
    port: port,
    reconnect_timeout: rto
  } = state) do
    case Mint.HTTP.connect(scheme, hostname, port) do
      {:ok, conn} ->
        {:ok, %{state | conn: conn}}
      {:error, err} ->
        Logger.error("Failed to connect with #{inspect err, pretty: true}")
        {:backoff, rto, state}
    end
  end

  def disconnect(_, %{conn: conn} = state) do
    {:ok, _} = Mint.HTTP.close(conn)
    {:connect, :reconnect, %{state | conn: :disconnected, requests: %{}}}
  end

  # POST/PUT/PATCH methods with "content-type" header
  def handle_call({:request, method, path, input, type}, from, %{conn: conn} = state) do
    Mint.HTTP.request(conn, method, path, content_type(type), input)
    |> put_response(from, state)
  end

  # GET/DELETE methods without bodies
  def handle_call({:request, method, path}, from, %{conn: conn} = state) do
    Mint.HTTP.request(conn, method, path, [], nil)
    |> put_response(from, state)
  end

  def handle_info(message, %{conn: conn} = state) do
    case Mint.HTTP.stream(conn, message) do
      :unknown ->
        Logger.error("Received undefined message: #{inspect message, pretty: true}")
      {:ok, conn, responses} ->
        state = Enum.reduce(responses, %{state | conn: conn}, &process_response/2)
        {:noreply, state}
    end
  end

  def child_spec(opts) do
    {_, _, {_, index}} = Keyword.get(opts, :name)
    %{
      id: {__MODULE__, index},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 1000
    }
  end

  # Helpers

  @spec put_response(
    {:ok, Mint.HTTP.t(), Mint.Types.request_ref()} | {:error, Mint.HTTP.t(), Mint.Types.error()},
    GenServer.from(), state()
  ) :: {:reply, term(), state()} | {:noreply, state()}
  defp put_response({:ok, conn, ref}, from, %{requests: requests} = state) do
    {:noreply, %{state | conn: conn, requests: Map.put(requests, ref, new_response(from))}}
  end
  defp put_response({:error, conn, reason}, _from, state) do
    {:reply, {:error, reason}, %{state | conn: conn}}
  end

  @spec process_response(Mint.Types.response(), state()) :: state()
  def process_response({:status, ref, 200}, %{requests: reqs} = state) do
    case reqs do
      %{^ref => request} ->
        %{state | requests: %{reqs | ref => %{request | status: 200}}}

      _ ->
        state
    end
  end
  def process_response({:status, ref, status}, %{requests: requests} = state) do
    case requests do
      %{^ref => %{from: from} = request} ->
        GenServer.reply(from, {:error, %{request | status: status}, :bad_status})
        %{state | requests: Map.delete(requests, ref)}

      _ ->
        state
    end
  end
  def process_response({:headers, _, _}, state), do: state
  def process_response({:data, ref, data}, %{requests: requests} = state) do
    case requests do
      %{^ref => %{body: body} = request} ->
        %{state | requests: %{requests | ref => %{request | body: body <> data}}}

      _ ->
        state
    end
  end
  def process_response({:done, ref}, %{requests: requests} = state) do
    {%{from: from} = request, requests} = Map.pop(requests, ref)
    GenServer.reply(from, {:ok, request})
    %{state | requests: requests}
  end
  def process_response({:error, ref, reason}, %{requests: requests} = state) do
    {%{from: from} = request, requests} = Map.pop(requests, ref)
    GenServer.reply(from, {:error, request, reason})
    %{state | requests: requests}
  end

  @spec new_response(GenServer.from()) :: response()
  defp new_response(from) do
    %{from: from, status: nil, body: ""}
  end

  @spec content_type(content_type :: String.t()) :: [{String.t(), String.t()}]
  defp content_type(type) do
    [{"content-type", type}]
  end

end
