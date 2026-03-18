defmodule Krogex.Authorization do
  @moduledoc """
  OAuth helpers for Kroger authentication.
  """

  alias Krogex
  alias Krogex.Client

  @default_user_token "kroger_user"

  @doc """
  Builds the Kroger authorization URL for the authorization code flow.

  ## Options

  - `:state` - Optional state parameter for CSRF protection
  - `:banner` - Optional banner chain code
  - `:code_challenge` - PKCE code challenge
  - `:code_challenge_method` - PKCE method (defaults to "S256" if code_challenge provided)
  """
  @spec authorization_url(Krogex.t(), String.t(), keyword()) :: String.t()
  def authorization_url(%Krogex{} = client, scope, opts \\ []) do
    if is_nil(client.redirect_uri) do
      raise ArgumentError, "redirect_uri is required for authorization code flow"
    end

    params =
      %{
        "scope" => scope,
        "client_id" => client.client_id,
        "redirect_uri" => client.redirect_uri,
        "response_type" => "code"
      }
      |> maybe_put("state", opts[:state])
      |> maybe_put("banner", opts[:banner])
      |> maybe_put("code_challenge", opts[:code_challenge])
      |> maybe_put(
        "code_challenge_method",
        opts[:code_challenge_method] || if(opts[:code_challenge], do: "S256")
      )

    client.base_url
    |> URI.merge("/v1/connect/oauth2/authorize")
    |> Map.update!(:query, fn _ -> URI.encode_query(params) end)
    |> to_string()
  end

  @doc """
  Fetches or refreshes a client-credentials token and persists it by scope.

  ## Options

  - `:token_name` - Custom token name (defaults to "krogex_client_{scope}")
  """
  @spec client_credentials(Krogex.t(), String.t(), keyword()) ::
          {:ok, Krogex.t()} | {:error, term()}
  def client_credentials(%Krogex{} = client, scope, opts \\ []) do
    token_name = Keyword.get(opts, :token_name, client_token_name(scope))

    case Krogex.load_token(client, token_name) do
      {:ok, loaded_client} ->
        if Krogex.TokenStore.expired?(loaded_client.token_info) do
          Client.fetch_token(
            client,
            %{"grant_type" => "client_credentials", "scope" => scope},
            token_name
          )
        else
          {:ok, loaded_client}
        end

      _ ->
        Client.fetch_token(
          client,
          %{"grant_type" => "client_credentials", "scope" => scope},
          token_name
        )
    end
  end

  @doc """
  Exchanges an authorization code for a shopper token and persists it.

  ## Options

  - `:token_name` - Custom token name (defaults to "kroger_user")
  - `:code_verifier` - PKCE code verifier if using PKCE flow
  """
  @spec exchange_code(Krogex.t(), String.t(), keyword()) :: {:ok, Krogex.t()} | {:error, term()}
  def exchange_code(%Krogex{} = client, code, opts \\ []) do
    if is_nil(client.redirect_uri) do
      raise ArgumentError, "redirect_uri is required for authorization code flow"
    end

    token_name = Keyword.get(opts, :token_name, @default_user_token)

    params =
      %{
        "grant_type" => "authorization_code",
        "code" => code,
        "redirect_uri" => client.redirect_uri
      }
      |> maybe_put("code_verifier", opts[:code_verifier])

    Client.fetch_token(client, params, token_name)
  end

  @doc """
  Loads a previously stored shopper token.
  """
  @spec load_user(Krogex.t(), String.t()) :: {:ok, Krogex.t()} | {:error, term()}
  def load_user(%Krogex{} = client, token_name \\ @default_user_token) do
    Krogex.load_token(client, token_name)
  end

  @doc """
  Explicitly refreshes a user token using its refresh_token.

  ## Options

  - `:token_name` - The token name to refresh (default: "kroger_user")
  """
  @spec refresh_user_token(Krogex.t(), keyword()) :: {:ok, Krogex.t()} | {:error, term()}
  def refresh_user_token(%Krogex{} = client, opts \\ []) do
    token_name = Keyword.get(opts, :token_name, @default_user_token)

    with {:ok, loaded_client} <- Krogex.load_token(client, token_name),
         refresh_token when is_binary(refresh_token) <-
           loaded_client.token_info["refresh_token"] do
      Client.fetch_token(
        loaded_client,
        %{"grant_type" => "refresh_token", "refresh_token" => refresh_token},
        token_name
      )
    else
      nil -> {:error, :no_refresh_token}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks if the user token is expired or will expire soon.

  ## Options

  - `:token_name` - The token name to check (default: "kroger_user")
  - `:skew_seconds` - Seconds before actual expiry to consider expired (default: 30)
  """
  @spec user_token_expired?(Krogex.t(), keyword()) :: boolean()
  def user_token_expired?(%Krogex{} = client, opts \\ []) do
    token_name = Keyword.get(opts, :token_name, @default_user_token)
    skew = Keyword.get(opts, :skew_seconds, 30)

    case Krogex.load_token(client, token_name) do
      {:ok, loaded_client} ->
        Krogex.TokenStore.expired?(loaded_client.token_info, skew)

      {:error, _} ->
        true
    end
  end

  @doc """
  Deletes a persisted token.
  """
  @spec revoke_local_token(Krogex.t(), String.t()) :: :ok | {:error, term()}
  def revoke_local_token(%Krogex{} = client, token_name \\ @default_user_token) do
    Krogex.TokenStore.delete_token(token_name, dir: client.token_store_dir)
  end

  defp client_token_name(scope) do
    "krogex_client_" <> String.replace(scope, ":", "_")
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
