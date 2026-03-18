defmodule Krogex.Products do
  @moduledoc """
  Product catalog operations for Kroger.
  """

  alias Krogex
  alias Krogex.Client
  alias Krogex.Params

  @doc """
  Searches products with Kroger's `filter.*` params.

  ## Supported filters

  - `:term` - Search term to filter products
  - `:location_id` - Location ID for pricing/availability
  - `:product_id` - Comma-separated product IDs
  - `:brand` - Pipe-separated brand names
  - `:fulfillment` - Comma-separated fulfillment types
  - `:start` - Number of products to skip
  - `:limit` - Number of products to return

  ## Examples

      {:ok, results} = Krogex.Products.search(client, term: "milk", location_id: "01234567", limit: 10)
  """
  @spec search(Krogex.t(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def search(%Krogex{} = client, params \\ %{}) do
    Client.request(client, :get, "/v1/products", params: Params.normalize_filters(params))
  end

  @doc """
  Fetches a single product by ID.

  Optionally accepts `:location_id` for pricing and availability data.
  """
  @spec get(Krogex.t(), String.t(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def get(%Krogex{} = client, product_id, params \\ %{}) do
    Client.request(client, :get, "/v1/products/#{product_id}",
      params: Params.normalize_filters(params)
    )
  end
end
