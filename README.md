# Krogex

Elixir client for [Kroger's public API](https://developer.kroger.com/).

Search products, find store locations, and manage shopping carts with OAuth authentication.

## Installation

Add `krogex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:krogex, "~> 0.1.0"}
  ]
end
```

## Configuration

Get your API credentials from [Kroger Developer Portal](https://developer.kroger.com/).

```elixir
# config/runtime.exs
config :krogex,
  client_id: System.get_env("KROGER_CLIENT_ID"),
  client_secret: System.get_env("KROGER_CLIENT_SECRET"),
  redirect_uri: System.get_env("KROGER_REDIRECT_URI")  # Only needed for user auth
```

## Quick Start

### Search Products (Public API)

```elixir
# Create client from config
client = Krogex.from_config()

# Get a client credentials token for public API access
{:ok, client} = Krogex.Authorization.client_credentials(client, "product.compact")

# Search for products
{:ok, %{"data" => products}} = Krogex.Products.search(client,
  term: "organic milk",
  location_id: "01234567",
  limit: 10
)

# Find nearby stores
{:ok, %{"data" => stores}} = Krogex.Locations.search(client,
  zip_code: "45202",
  radius_in_miles: 10,
  limit: 5
)
```

### User Authentication (Cart Access)

```elixir
# Generate authorization URL
auth_url = Krogex.Authorization.authorization_url(
  client,
  "cart.basic:write profile.compact"
)

# Redirect user to auth_url...
# After they authorize, exchange the code:
{:ok, client} = Krogex.Authorization.exchange_code(client, auth_code)

# Add items to cart
:ok = Krogex.Cart.add_items(client, [
  %{upc: "0001111087523", quantity: 1, modality: "PICKUP"},
  %{upc: "0001111087524", quantity: 2, modality: "PICKUP"}
])

# Get user profile
{:ok, profile} = Krogex.Identity.profile(client)
```

### PKCE Flow (Recommended for Mobile/SPA)

```elixir
# Generate PKCE codes
pkce = Krogex.PKCE.generate()

# Include challenge in auth URL
auth_url = Krogex.Authorization.authorization_url(
  client,
  "cart.basic:write",
  code_challenge: pkce.code_challenge,
  code_challenge_method: pkce.code_challenge_method
)

# Include verifier when exchanging code
{:ok, client} = Krogex.Authorization.exchange_code(
  client,
  auth_code,
  code_verifier: pkce.code_verifier
)
```

## Token Persistence

Tokens are automatically persisted to disk (`~/.local/share/krogex/` by default).

```elixir
# Tokens are saved automatically with a name
{:ok, client} = Krogex.Authorization.client_credentials(
  client,
  "product.compact",
  token_name: "my_app_public"
)

# Later, load the saved token
{:ok, client} = Krogex.load_token(client, "my_app_public")

# Check if user token is expired
if Krogex.Authorization.user_token_expired?(client) do
  {:ok, client} = Krogex.Authorization.refresh_user_token(client)
end
```

## API Modules

- `Krogex.Products` - Search and get product details
- `Krogex.Locations` - Find stores, chains, and departments
- `Krogex.Cart` - Add items to shopping cart
- `Krogex.Identity` - Get user profile
- `Krogex.Authorization` - OAuth flows and token management
- `Krogex.PKCE` - PKCE code generation

## License

MIT License
