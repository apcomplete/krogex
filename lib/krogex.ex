defmodule Krogex do
  @moduledoc """
  Elixir client for Kroger's public API.

  Supports OAuth client credentials for public catalog data and
  authorization code tokens for shopper-specific endpoints like cart management.

  ## Installation

  Add `krogex` to your dependencies:

      def deps do
        [
          {:krogex, "~> 0.1.0"}
        ]
      end

  ## Configuration

  Add to your `config/config.exs` or `config/runtime.exs`:

      config :krogex,
        client_id: System.get_env("KROGER_CLIENT_ID"),
        client_secret: System.get_env("KROGER_CLIENT_SECRET"),
        redirect_uri: System.get_env("KROGER_REDIRECT_URI")

  Then use `from_config/0`:

      client = Krogex.from_config()

  ## Basic Usage

      # Create a client
      client = Krogex.new(
        client_id: "your_client_id",
        client_secret: "your_client_secret"
      )

      # Get client credentials token for public API access
      {:ok, client} = Krogex.Authorization.client_credentials(client, "product.compact")

      # Search products
      {:ok, results} = Krogex.Products.search(client, term: "milk", limit: 10)

      # Find nearby stores
      {:ok, stores} = Krogex.Locations.search(client, zip_code: "45202", limit: 5)

  ## User Authentication (for cart access)

      # Generate authorization URL
      auth_url = Krogex.Authorization.authorization_url(
        client,
        "cart.basic:write profile.compact"
      )

      # After user authorizes, exchange the code
      {:ok, shopper_client} = Krogex.Authorization.exchange_code(client, auth_code)

      # Add items to cart
      :ok = Krogex.Cart.add_items(shopper_client, [
        %{upc: "0001111087523", quantity: 1, modality: "PICKUP"}
      ])

  ## Token Persistence

  Tokens can be automatically persisted by providing a `token_name`:

      {:ok, client} = Krogex.Authorization.client_credentials(
        client,
        "product.compact",
        token_name: "my_app_public"
      )

      # Later, load the saved token
      {:ok, client} = Krogex.load_token(client, "my_app_public")

  By default, tokens are stored as files on disk using `Krogex.TokenStore.File`.
  You can provide a custom token store by implementing the `Krogex.TokenStore`
  behaviour:

      config :krogex,
        token_store: MyApp.KrogerTokenStore

  Or disable persistence entirely by setting `token_store: nil`.
  """

  alias __MODULE__.TokenStore

  @type token_info :: map()
  @type token_store :: module() | nil

  @type t :: %__MODULE__{
          client_id: String.t(),
          client_secret: String.t(),
          redirect_uri: String.t() | nil,
          base_url: String.t(),
          token_name: String.t() | nil,
          token_info: token_info() | nil,
          token_store: token_store(),
          token_store_opts: keyword(),
          req_options: keyword()
        }

  defstruct [
    :client_id,
    :client_secret,
    :redirect_uri,
    token_name: nil,
    token_info: nil,
    token_store: TokenStore.File,
    token_store_opts: [],
    base_url: "https://api.kroger.com",
    req_options: []
  ]

  @doc """
  Builds a Krogex client from application config.

  Reads from `Application.get_env(:krogex, ...)`.

  ## Config keys

  - `:client_id` (required)
  - `:client_secret` (required)
  - `:redirect_uri` (optional, required for user auth flows)
  - `:base_url` (optional, defaults to "https://api.kroger.com")
  - `:token_store` (optional, module implementing `Krogex.TokenStore`, defaults to `Krogex.TokenStore.File`)
  - `:token_store_opts` (optional, options passed to token store, e.g. `[dir: "/path"]`)
  - `:req_options` (optional, extra options passed to Req)

  ## Examples

      # In config/runtime.exs:
      config :krogex,
        client_id: System.get_env("KROGER_CLIENT_ID"),
        client_secret: System.get_env("KROGER_CLIENT_SECRET"),
        redirect_uri: System.get_env("KROGER_REDIRECT_URI")

      # In your code:
      client = Krogex.from_config()
  """
  @spec from_config() :: t()
  def from_config do
    config = [
      client_id: Application.get_env(:krogex, :client_id),
      client_secret: Application.get_env(:krogex, :client_secret),
      redirect_uri: Application.get_env(:krogex, :redirect_uri),
      base_url: Application.get_env(:krogex, :base_url),
      token_store: Application.get_env(:krogex, :token_store, TokenStore.File),
      token_store_opts: Application.get_env(:krogex, :token_store_opts, []),
      req_options: Application.get_env(:krogex, :req_options, [])
    ]

    new(config)
  end

  @doc """
  Builds a Krogex client with explicit options.

  ## Options

  - `:client_id` (required) - Kroger API client ID
  - `:client_secret` (required) - Kroger API client secret
  - `:redirect_uri` (optional) - OAuth redirect URI for user auth flows
  - `:base_url` (optional) - API base URL, defaults to "https://api.kroger.com"
  - `:token_name` (optional) - Name for token persistence
  - `:token_info` (optional) - Pre-loaded token info map
  - `:token_store` (optional) - Module implementing `Krogex.TokenStore` behaviour
  - `:token_store_opts` (optional) - Options passed to token store callbacks
  - `:req_options` (optional) - Extra options passed to Req HTTP client
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      client_id: Keyword.fetch!(opts, :client_id),
      client_secret: Keyword.fetch!(opts, :client_secret),
      redirect_uri: Keyword.get(opts, :redirect_uri),
      base_url: Keyword.get(opts, :base_url) || "https://api.kroger.com",
      token_name: Keyword.get(opts, :token_name),
      token_info: Keyword.get(opts, :token_info),
      token_store: Keyword.get(opts, :token_store, TokenStore.File),
      token_store_opts: Keyword.get(opts, :token_store_opts, []),
      req_options: Keyword.get(opts, :req_options, [])
    }
  end

  @doc """
  Returns a client with the given token payload.
  """
  @spec put_token(t(), token_info(), String.t() | nil) :: t()
  def put_token(%__MODULE__{} = client, token_info, token_name \\ nil) when is_map(token_info) do
    %{
      client
      | token_info: TokenStore.normalize_token(token_info),
        token_name: token_name || client.token_name
    }
  end

  @doc """
  Loads a persisted token into the client.

  Uses the configured `token_store` module to load the token.
  """
  @spec load_token(t(), String.t()) :: {:ok, t()} | {:error, :token_not_found | term()}
  def load_token(%__MODULE__{} = client, token_name) do
    case client.token_store.load(token_name, client.token_store_opts) do
      {:ok, token_info} ->
        {:ok, put_token(%{client | token_name: token_name}, token_info, token_name)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
