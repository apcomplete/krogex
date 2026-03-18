defmodule Krogex.Client do
  @moduledoc false

  require Logger

  alias Krogex
  alias Krogex.TokenStore

  @type request_opts :: [params: map() | keyword(), json: term(), headers: [{binary(), binary()}]]

  @spec request(Krogex.t(), atom(), String.t(), request_opts()) ::
          :ok | {:ok, term()} | {:error, term()}
  def request(%Krogex{} = client, method, path, opts \\ []) do
    request_with_token(client, method, path, current_token(client), opts, true)
  end

  @spec fetch_token(Krogex.t(), map(), String.t() | nil) :: {:ok, Krogex.t()} | {:error, term()}
  def fetch_token(%Krogex{} = client, params, token_name \\ nil) do
    grant_type = params["grant_type"] || "unknown"
    Logger.debug("[Krogex] Fetching token via #{grant_type}")

    headers = [
      authorization_header(client),
      {"content-type", "application/x-www-form-urlencoded"}
    ]

    body = URI.encode_query(params)

    req_opts =
      Keyword.merge([headers: headers, body: body, decode_body: true], client.req_options)

    case Req.post(token_url(client), req_opts) do
      {:ok, %{status: status, body: token_info}} when status in 200..299 and is_map(token_info) ->
        Logger.debug("[Krogex] Token fetch successful (#{grant_type})")
        token_info = TokenStore.normalize(token_info)
        persisted_name = token_name || client.token_name

        with :ok <- maybe_save_token(persisted_name, token_info, client) do
          {:ok,
           Krogex.put_token(%{client | token_name: persisted_name}, token_info, persisted_name)}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[Krogex] Token fetch failed: HTTP #{status}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("[Krogex] Token fetch error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec request_with_token(Krogex.t(), atom(), String.t(), map() | nil, request_opts(), boolean()) ::
          :ok | {:ok, term()} | {:error, term()}
  defp request_with_token(_client, _method, _path, nil, _opts, _retry?),
    do: {:error, :missing_token}

  defp request_with_token(%Krogex{} = client, method, path, token_info, opts, retry?) do
    params = Keyword.get(opts, :params, %{})
    json = Keyword.get(opts, :json)
    extra_headers = Keyword.get(opts, :headers, [])

    req_opts =
      [
        url: request_url(client, path),
        method: method,
        params: params,
        headers:
          [
            {"authorization", "Bearer #{token_info["access_token"]}"},
            {"accept", "application/json"}
          ] ++ extra_headers,
        decode_body: true
      ]
      |> maybe_put_json(json)
      |> Keyword.merge(client.req_options)

    case Req.request(req_opts) do
      {:ok, %{status: 204}} ->
        :ok

      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: 401, body: body}} when retry? ->
        Logger.info("[Krogex] Received 401, attempting token refresh")
        maybe_refresh_and_retry(client, method, path, body, opts)

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[Krogex] API error: HTTP #{status} on #{method} #{path}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("[Krogex] Request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp maybe_refresh_and_retry(%Krogex{} = client, method, path, _body, opts) do
    case refresh_saved_token(client) do
      {:ok, refreshed} ->
        Logger.debug("[Krogex] Token refresh successful, retrying request")
        request_with_token(refreshed, method, path, refreshed.token_info, opts, false)

      {:error, reason} ->
        Logger.warning("[Krogex] Token refresh failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp refresh_saved_token(%Krogex{token_name: nil}), do: {:error, :token_refresh_unavailable}

  defp refresh_saved_token(%Krogex{} = client) do
    Logger.debug("[Krogex] Attempting to refresh token: #{client.token_name}")

    with {:ok, token_info} <- client.token_store.load(client.token_name, client.token_store_opts),
         refresh_token when is_binary(refresh_token) <- token_info["refresh_token"] do
      fetch_token(
        %{client | token_info: token_info},
        %{"grant_type" => "refresh_token", "refresh_token" => refresh_token},
        client.token_name
      )
    else
      nil ->
        Logger.debug("[Krogex] No refresh token available")
        {:error, :token_refresh_unavailable}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp current_token(%Krogex{token_info: token_info, token_name: nil}) do
    token_info
  end

  defp current_token(%Krogex{} = client) do
    persisted_token =
      if is_binary(client.token_name) do
        case client.token_store.load(client.token_name, client.token_store_opts) do
          {:ok, saved} -> saved
          _ -> nil
        end
      end

    cond do
      is_map(persisted_token) and not TokenStore.expired?(persisted_token) ->
        persisted_token

      is_map(client.token_info) and not TokenStore.expired?(client.token_info) ->
        client.token_info

      is_map(persisted_token) ->
        persisted_token

      true ->
        client.token_info
    end
  end

  defp token_url(%Krogex{} = client), do: request_url(client, "/v1/connect/oauth2/token")

  defp request_url(%Krogex{} = client, path) do
    URI.merge(client.base_url <> "/", String.trim_leading(path, "/")) |> to_string()
  end

  defp authorization_header(%Krogex{} = client) do
    basic = Base.encode64(client.client_id <> ":" <> client.client_secret)
    {"authorization", "Basic #{basic}"}
  end

  defp maybe_put_json(opts, nil), do: opts
  defp maybe_put_json(opts, json), do: Keyword.put(opts, :json, json)

  defp maybe_save_token(nil, _token_info, _client), do: :ok

  defp maybe_save_token(token_name, token_info, %Krogex{} = client) do
    client.token_store.save(token_name, token_info, client.token_store_opts)
  end
end
