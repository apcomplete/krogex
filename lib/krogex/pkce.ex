defmodule Krogex.PKCE do
  @moduledoc """
  PKCE (Proof Key for Code Exchange) helpers for OAuth authorization code flows.

  Use this for enhanced security in public clients (mobile apps, SPAs).

  ## Example

      pkce = Krogex.PKCE.generate()

      auth_url = Krogex.Authorization.authorization_url(
        client,
        "cart.basic:write",
        code_challenge: pkce.code_challenge,
        code_challenge_method: pkce.code_challenge_method
      )

      # After user authorizes...
      {:ok, client} = Krogex.Authorization.exchange_code(
        client,
        auth_code,
        code_verifier: pkce.code_verifier
      )
  """

  @doc """
  Generates a PKCE code verifier and challenge.

  ## Options

  - `length` - Length of the code verifier (default: 64, min: 32)
  - `method` - Challenge method, "S256" or "plain" (default: "S256")

  ## Returns

  A map with:
  - `:code_verifier` - The random string to send when exchanging the code
  - `:code_challenge` - The hashed challenge to include in the auth URL
  - `:code_challenge_method` - The method used ("S256" or "plain")
  """
  @spec generate(non_neg_integer(), String.t()) :: %{
          code_verifier: String.t(),
          code_challenge: String.t(),
          code_challenge_method: String.t()
        }
  def generate(length \\ 64, method \\ "S256") do
    code_verifier = generate_code_verifier(length)

    %{
      code_verifier: code_verifier,
      code_challenge: generate_code_challenge(code_verifier, method),
      code_challenge_method: method
    }
  end

  @doc """
  Generates a random code verifier string.
  """
  @spec generate_code_verifier(non_neg_integer()) :: String.t()
  def generate_code_verifier(length \\ 64) do
    bytes = max(length, 32)

    bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, length)
  end

  @doc """
  Generates a code challenge from a code verifier.
  """
  @spec generate_code_challenge(String.t(), String.t()) :: String.t()
  def generate_code_challenge(code_verifier, "plain"), do: code_verifier

  def generate_code_challenge(code_verifier, "S256") do
    :crypto.hash(:sha256, code_verifier)
    |> Base.url_encode64(padding: false)
  end

  def generate_code_challenge(_code_verifier, method) do
    raise ArgumentError, "unsupported PKCE method: #{inspect(method)}"
  end
end
