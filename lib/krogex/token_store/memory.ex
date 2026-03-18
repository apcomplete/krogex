defmodule Krogex.TokenStore.Memory do
  @moduledoc """
  In-memory token store using ETS.

  This is used internally for client credentials tokens which are short-lived
  and don't need to be persisted. It can also be used for testing or simple
  applications that don't need persistence.

  ## Usage

  The store is started automatically when first used. Tokens are stored in
  a named ETS table (`:krogex_token_store`).

  ```elixir
  client = Krogex.new(
    client_id: "my_client",
    client_secret: "my_secret",
    token_store: Krogex.TokenStore.Memory
  )
  ```
  """

  @behaviour Krogex.TokenStore

  @table :krogex_memory_token_store

  @doc false
  def ensure_table_exists do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])

      _ref ->
        :ok
    end
  end

  @impl true
  def save(token_name, token_info, _opts) do
    ensure_table_exists()
    :ets.insert(@table, {token_name, token_info})
    :ok
  end

  @impl true
  def load(token_name, _opts) do
    ensure_table_exists()

    case :ets.lookup(@table, token_name) do
      [{^token_name, token_info}] -> {:ok, token_info}
      [] -> {:error, :token_not_found}
    end
  end

  @impl true
  def delete(token_name, _opts) do
    ensure_table_exists()
    :ets.delete(@table, token_name)
    :ok
  end
end
