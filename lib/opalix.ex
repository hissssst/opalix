defmodule Opalix do

  @moduledoc """
  Documentation for `Opalix`.
  """

  alias Opalix.Connection.Pool

  @type document    :: Map.t()
  @type patch       :: Map.t()
  @type document_id :: String.t()
  @type package     :: String.t()
  @type rule        :: String.t()
  @type policy_id   :: String.t()
  @type policy      :: String.t()
  @type result      :: {:ok, Map.t()} | {:error, reason()}
  @type reason      ::
    {:http_error, term()}
    | {:transport_error, term()}
    | {:handling_error, term()}
    | {:bad_status, term()}
    | {:encoding_error, term()}

  # Public API

  ### Document API

  @doc """
  Wrapper for
  https://www.openpolicyagent.org/docs/latest/rest-api/#get-a-document
  """
  @spec get_document(package(), rule()) :: result()
  def get_document(package, rule) do
    path  = "/v1/data" <> to_path(package, rule)

    Pool.get(path)
    |> handle_response()
  end

  @doc """
  Wrapper for
  https://www.openpolicyagent.org/docs/latest/rest-api/#get-a-document-with-input
  """
  @spec get_document(package(), rule(), document()) :: result()
  def get_document(package, rule, input) do
    path  = "/v1/data" <> to_path(package, rule)

    case to_input(input) do
      {:ok, input} ->
        Pool.post(path, input, "application/json")
        |> handle_response()

      {:error, reason} ->
        {:error, {:encoding_error, reason}}
    end
  end

  @doc """
  Wrapper for
  https://www.openpolicyagent.org/docs/latest/rest-api/#create-or-overwrite-a-document
  """
  @spec create_or_overwrite_document(document_id(), document()) ::
    {:ok, :success}
    | {:ok, :not_modified}
    | result()
  def create_or_overwrite_document(id, document) do
    path = "/v1/data/" <> id
    case Jason.encode(document) do
      {:ok, document} ->
        Pool.post(path, document, "application/json")
        |> handle_response()
        |> case do
          {:error, {:bad_status, 204}} ->
            {:ok, :success}

          {:error, {:bad_status, 304}} ->
            {:ok, :not_modified}

          other ->
            other
        end
      {:error, _} ->
        {:error, :encoding_error}
    end
  end

  @doc """
  Wrapper for
  https://www.openpolicyagent.org/docs/latest/rest-api/#patch-a-document
  """
  @spec patch_document(document_id(), patch()) :: :ok | result()
  def patch_document(id, patch) do
    path = "/v1/data/" <> id
    case Jason.encode(patch) do
      {:ok, patch} ->
        Pool.patch(path, patch, "application/json-patch+json")
        |> handle_response()
        |> case do
          {:error, {:bad_status, 204}} ->
            :ok

          other ->
            other
        end
      {:error, _} ->
        {:error, :encoding_error}
    end
  end

  @doc """
  Wrapper for
  https://www.openpolicyagent.org/docs/latest/rest-api/#delete-a-document
  """
  @spec delete_document(document_id()) :: result()
  def delete_document(id) do
    path  = "/v1/data" <> id

    Pool.delete(path)
    |> handle_response()
    |> case do
      {:error, {:bad_status, 204}} ->
        :ok

      other ->
        other
    end
  end

  ### Policy API

  @doc """
  Wrapper for
  https://www.openpolicyagent.org/docs/latest/rest-api/#list-policies
  """
  @spec list_policies() :: result()
  def list_policies() do
    Pool.get("/v1/policies")
    |> handle_response()
  end

  @doc """
  Wrapper for
  https://www.openpolicyagent.org/docs/latest/rest-api/#get-a-policy
  """
  @spec get_policy(policy_id()) :: result()
  def get_policy(id) do
    Pool.get("/v1/policies/" <> id)
    |> handle_response()
  end

  @doc """
  Wrapper for
  https://www.openpolicyagent.org/docs/latest/rest-api/#create-or-update-a-policy
  """
  @spec create_or_update_policy(policy_id(), policy()) :: result()
  def create_or_update_policy(id, policy) do
    Pool.put("/v1/policies/" <> id, policy, "text/plain")
    |> handle_response()
  end

  @doc """
  Wrapper for
  https://www.openpolicyagent.org/docs/latest/rest-api/#delete-a-policy
  """
  @spec delete_policy(policy_id()) :: result()
  def delete_policy(id) do
    Pool.delete("/v1/policies/" <> id)
    |> handle_response()
  end

  # Helpers

  @spec to_path(package(), rule()) :: String.t()
  defp to_path(package, rule) do
    package = String.replace(package, ".", "/")
    "/#{package}/#{rule}"
  end

  @spec to_input(Map.t()) :: {:ok, String.t()} | {:error, term()}
  defp to_input(input) do
    case Jason.encode(input) do
      {:ok, encoded} ->
        {:ok, ~s({"input":#{encoded}})}

      error ->
        error
    end
  end

  @spec handle_response(Opalix.Connection.reply()) :: result()
  defp handle_response({:ok, %{status: 200, body: body}}) do
    case Jason.decode(body) do
      {:ok, %{"result" => result}} ->
        {:ok, result}

      error ->
        error
    end
  end
  defp handle_response({:error, %Mint.HTTPError{reason: reason}}) do
    {:error, {:http_error, reason}}
  end
  defp handle_response({:error, %Mint.TransportError{reason: reason}}) do
    {:error, {:transport_error, reason}}
  end
  defp handle_response({:error, %{status: status}, :bad_status}) do
    {:error, {:bad_status, status}}
  end
  defp handle_response({:error, request, reason}) do
    {:error, {:handling_error, reason, request}}
  end

end
