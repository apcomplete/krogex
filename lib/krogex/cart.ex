defmodule Krogex.Cart do
  @moduledoc """
  Cart operations for Kroger ClickList.
  """

  alias Krogex
  alias Krogex.Client

  @doc """
  Adds items to the authenticated shopper cart.

  ## Item format

  Each item should be a map with:
  - `:upc` - Product UPC code
  - `:quantity` - Number to add
  - `:modality` - Fulfillment type ("PICKUP" or "DELIVERY")

  ## Examples

      :ok = Krogex.Cart.add_items(client, [
        %{upc: "0001111087523", quantity: 1, modality: "PICKUP"}
      ])
  """
  @spec add_items(Krogex.t(), [map()]) :: :ok | {:error, term()}
  def add_items(%Krogex{} = client, items) when is_list(items) do
    payload = %{"items" => Enum.map(items, &normalize_item/1)}

    case Client.request(client, :put, "/v1/cart/add", json: payload) do
      :ok -> :ok
      {:ok, _body} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_item(item) do
    item
    |> Enum.into(%{})
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
  end
end
