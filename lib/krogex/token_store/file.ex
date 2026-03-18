defmodule Krogex.TokenStore.File do
  @moduledoc """
  File-based token storage.

  Stores tokens as JSON files in a configurable directory.
  By default, uses `~/.local/share/krogex/` on Unix systems
  or `%APPDATA%/krogex/` on Windows.

  ## Configuration

      config :krogex,
        token_store: Krogex.TokenStore.File,
        token_store_dir: "/path/to/tokens"

  Or pass `:dir` in opts when calling save/load/delete.
  """

  @behaviour Krogex.TokenStore

  @default_app_dir "krogex"

  @impl true
  def save(token_name, token_info, opts \\ []) do
    path = token_path(token_name, opts)
    dir = Path.dirname(path)
    token_info = Krogex.TokenStore.normalize(token_info)

    with :ok <- File.mkdir_p(dir),
         {:ok, json} <- Jason.encode(token_info),
         :ok <- File.write(path, json),
         :ok <- chmod_if_supported(path) do
      :ok
    end
  end

  @impl true
  def load(token_name, opts \\ []) do
    path = token_path(token_name, opts)

    case File.read(path) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, token} -> {:ok, Krogex.TokenStore.normalize(token)}
          {:error, reason} -> {:error, reason}
        end

      {:error, :enoent} ->
        {:error, :token_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def delete(token_name, opts \\ []) do
    case File.rm(token_path(token_name, opts)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the file path for a token.
  """
  @spec token_path(String.t(), keyword()) :: String.t()
  def token_path(token_name, opts \\ []) do
    Path.join(token_dir(opts), safe_token_name(token_name) <> ".json")
  end

  @doc """
  Returns the token storage directory.
  """
  @spec token_dir(keyword()) :: String.t()
  def token_dir(opts \\ []) do
    case Keyword.get(opts, :dir) do
      nil -> default_token_dir()
      dir -> dir
    end
  end

  defp safe_token_name(token_name) do
    token_name
    |> String.replace(~r/[^a-zA-Z0-9_.-]+/, "_")
    |> String.trim("_")
  end

  defp default_token_dir do
    cond do
      match?({:win32, _}, :os.type()) ->
        Path.join(System.get_env("APPDATA") || System.user_home!(), @default_app_dir)

      xdg_home = System.get_env("XDG_DATA_HOME") ->
        Path.join(xdg_home, @default_app_dir)

      true ->
        Path.join([System.user_home!(), ".local", "share", @default_app_dir])
    end
  end

  defp chmod_if_supported(path) do
    case :os.type() do
      {:win32, _} -> :ok
      _ -> File.chmod(path, 0o600)
    end
  end
end
