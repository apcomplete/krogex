defmodule Krogex.Locations do
  @moduledoc """
  Store location operations for Kroger.
  """

  alias Krogex
  alias Krogex.Client
  alias Krogex.Params

  @doc """
  Searches locations with Kroger's `filter.*` params.

  ## Supported filters

  - `:zip_code` - Zip code for location search (becomes zipCode.near)
  - `:lat_long` - Lat/long coordinates (becomes latLong.near)
  - `:lat` - Latitude (becomes lat.near)
  - `:lon` - Longitude (becomes lon.near)
  - `:radius_in_miles` - Search radius (1-100)
  - `:limit` - Number of results (1-200)
  - `:chain` - Chain name filter
  - `:department` - Department ID filter
  - `:location_id` - Comma-separated location IDs

  ## Examples

      {:ok, results} = Krogex.Locations.search(client, zip_code: "45202", radius_in_miles: 10, limit: 5)
  """
  @spec search(Krogex.t(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def search(%Krogex{} = client, params \\ %{}) do
    Client.request(client, :get, "/v1/locations", params: Params.normalize_filters(params))
  end

  @doc """
  Fetches a single location by ID.
  """
  @spec get(Krogex.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get(%Krogex{} = client, location_id) do
    Client.request(client, :get, "/v1/locations/#{location_id}")
  end

  @doc """
  Lists all available chains (Kroger, Ralphs, Fred Meyer, etc.).
  """
  @spec list_chains(Krogex.t()) :: {:ok, map()} | {:error, term()}
  def list_chains(%Krogex{} = client) do
    Client.request(client, :get, "/v1/chains")
  end

  @doc """
  Fetches details for a specific chain by name.
  """
  @spec get_chain(Krogex.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_chain(%Krogex{} = client, chain_name) do
    Client.request(client, :get, "/v1/chains/#{chain_name}")
  end

  @doc """
  Lists all available departments.
  """
  @spec list_departments(Krogex.t()) :: {:ok, map()} | {:error, term()}
  def list_departments(%Krogex{} = client) do
    Client.request(client, :get, "/v1/departments")
  end

  @doc """
  Fetches details for a specific department by ID.
  """
  @spec get_department(Krogex.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_department(%Krogex{} = client, department_id) do
    Client.request(client, :get, "/v1/departments/#{department_id}")
  end
end
