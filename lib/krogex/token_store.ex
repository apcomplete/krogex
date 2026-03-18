defmodule Krogex.TokenStore do
  @moduledoc """
  Behaviour for token persistence.

  Krogex uses this behaviour to save, load, and delete OAuth tokens.
  The default implementation (`Krogex.TokenStore.File`) stores tokens
  as JSON files on disk.

  ## Custom Token Stores

  To use a custom storage backend (e.g., database, Redis, ETS), implement
  this behaviour and configure it:

      config :krogex,
        token_store: MyApp.KrogerTokenStore

  Or pass it when creating a client:

      client = Krogex.new(
        client_id: "...",
        client_secret: "...",
        token_store: MyApp.KrogerTokenStore
      )

  ## Example Implementation

      defmodule MyApp.KrogerTokenStore do
        @behaviour Krogex.TokenStore

        @impl true
        def save(token_name, token_info, _opts) do
          # Save to your backend
          MyApp.Repo.insert_or_update_token(token_name, token_info)
          :ok
        end

        @impl true
        def load(token_name, _opts) do
          case MyApp.Repo.get_token(token_name) do
            nil -> {:error, :token_not_found}
            token_info -> {:ok, token_info}
          end
        end

        @impl true
        def delete(token_name, _opts) do
          MyApp.Repo.delete_token(token_name)
          :ok
        end
      end

  ## Token Info Structure

  Token info is a map with string keys:

  - `"access_token"` - The OAuth access token
  - `"refresh_token"` - The refresh token (optional)
  - `"expires_in"` - Seconds until expiry (from API response)
  - `"expires_at"` - Unix timestamp when token expires (computed)
  - `"issued_at"` - Unix timestamp when token was issued (computed)
  """

  @type token_name :: String.t()
  @type token_info :: %{String.t() => term()}
  @type opts :: keyword()

  @doc """
  Saves a token with the given name.

  The `opts` may include implementation-specific options.
  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @callback save(token_name(), token_info(), opts()) :: :ok | {:error, term()}

  @doc """
  Loads a token by name.

  Returns `{:ok, token_info}` if found, or `{:error, :token_not_found}`
  if the token doesn't exist.
  """
  @callback load(token_name(), opts()) ::
              {:ok, token_info()} | {:error, :token_not_found | term()}

  @doc """
  Deletes a token by name.

  Returns `:ok` even if the token didn't exist.
  """
  @callback delete(token_name(), opts()) :: :ok | {:error, term()}

  @doc """
  Normalizes a token map, adding `issued_at` and `expires_at` if needed.

  This is a utility function that token store implementations can use,
  but it's not part of the behaviour callbacks.
  """
  @spec normalize(token_info()) :: token_info()
  def normalize(token_info) when is_map(token_info) do
    issued_at =
      Map.get(token_info, "issued_at") ||
        Map.get(token_info, :issued_at) ||
        System.system_time(:second)

    expires_in = Map.get(token_info, "expires_in") || Map.get(token_info, :expires_in)

    token_info
    |> stringify_keys()
    |> Map.put_new("issued_at", issued_at)
    |> maybe_put_expires_at(expires_in, issued_at)
  end

  @doc """
  Checks if a token is expired.

  Returns `true` if the token has expired or will expire within
  `skew_seconds` (default 30 seconds).
  """
  @spec expired?(token_info(), non_neg_integer()) :: boolean()
  def expired?(token_info, skew_seconds \\ 30) when is_map(token_info) do
    now = System.system_time(:second)

    case token_info["expires_at"] do
      expires_at when is_integer(expires_at) -> expires_at <= now + skew_seconds
      _ -> false
    end
  end

  # Keep old function name as alias for backwards compatibility
  @doc false
  def normalize_token(token_info), do: normalize(token_info)

  defp maybe_put_expires_at(token_info, expires_in, issued_at) when is_integer(expires_in) do
    Map.put_new(token_info, "expires_at", issued_at + expires_in)
  end

  defp maybe_put_expires_at(token_info, expires_in, issued_at) when is_binary(expires_in) do
    case Integer.parse(expires_in) do
      {value, ""} -> Map.put_new(token_info, "expires_at", issued_at + value)
      _ -> token_info
    end
  end

  defp maybe_put_expires_at(token_info, _expires_in, _issued_at), do: token_info

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
