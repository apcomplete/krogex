defmodule Krogex.Params do
  @moduledoc """
  Parameter normalization for Kroger API requests.
  """

  @doc """
  Normalizes filter parameters for Kroger API requests.

  Converts keyword lists or maps to the `filter.*` format expected by Kroger,
  filtering out nil and empty string values.

  ## Examples

      iex> Krogex.Params.normalize_filters(term: "milk", location_id: "123")
      %{"filter.term" => "milk", "filter.locationId" => "123"}

      iex> Krogex.Params.normalize_filters(%{"filter.term" => "milk"})
      %{"filter.term" => "milk"}
  """
  @spec normalize_filters(keyword() | map()) :: map()
  def normalize_filters(params) do
    params
    |> Enum.into(%{})
    |> Enum.reduce(%{}, fn
      {_key, value}, acc when value in [nil, ""] -> acc
      {key, value}, acc -> Map.put(acc, filter_key(key), value)
    end)
  end

  @doc """
  Converts a parameter key to Kroger's `filter.*` format.

  Handles both atom and string keys, and converts snake_case to camelCase.
  Some keys require special suffixes (e.g., `zip_code` -> `zipCode.near`).
  """
  @spec filter_key(atom() | String.t()) :: String.t()
  def filter_key(key) do
    key_str = to_string(key)

    # Return as-is if already has filter. prefix
    if String.starts_with?(key_str, "filter.") do
      key_str
    else
      "filter." <> normalize_key(key_str)
    end
  end

  # Keys that need .near suffix for location-based searches
  defp normalize_key("zip_code"), do: "zipCode.near"
  defp normalize_key("lat_long"), do: "latLong.near"
  defp normalize_key("lat"), do: "lat.near"
  defp normalize_key("lon"), do: "lon.near"
  defp normalize_key(key), do: snake_to_camel(key)

  defp snake_to_camel(string) do
    string
    |> String.split("_")
    |> case do
      [first | rest] -> first <> Enum.map_join(rest, "", &String.capitalize/1)
      [] -> ""
    end
  end
end
