defmodule Krogex.Identity do
  @moduledoc """
  Shopper identity operations for Kroger.
  """

  alias Krogex
  alias Krogex.Client

  @doc """
  Fetches the authenticated shopper profile.

  Returns user profile data including name and loyalty card info.
  """
  @spec profile(Krogex.t()) :: {:ok, map()} | {:error, term()}
  def profile(%Krogex{} = client) do
    Client.request(client, :get, "/v1/identity/profile")
  end
end
