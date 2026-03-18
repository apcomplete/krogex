defmodule Krogex.TokenStore do
  @moduledoc """
  Token persistence for OAuth tokens.

  Tokens are stored as JSON files in a configurable directory.
  By default, uses `~/.local/share/krogex/` on Unix systems.
  """

  @default_app_dir "krogex"

  @doc """
  Loads a token from disk.
  """
  @spec load_token(String.t(), keyword()) :: {:ok, map()} | {:error, :token_not_found | term()}
  def load_token(token_name, opts \\ []) do
    path = token_path(token_name, opts)

    case File.read(path) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, token} -> {:ok, normalize_token(token)}
          {:error, reason} -> {:error, reason}
        end

      {:error, :enoent} ->
        {:error, :token_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Saves a token to disk.
  """
  @spec save_token(String.t(), map(), keyword()) :: :ok | {:error, term()}
  def save_token(token_name, token_info, opts \\ []) do
    path = token_path(token_name, opts)
    dir = Path.dirname(path)
    token_info = normalize_token(token_info)

    with :ok <- File.mkdir_p(dir),
         {:ok, json} <- Jason.encode(token_info),
         :ok <- File.write(path, json),
         :ok <- chmod_if_supported(path) do
      :ok
    end
  end

  @doc """
  Deletes a token from disk.
  """
  @spec delete_token(String.t(), keyword()) :: :ok | {:error, term()}
  def delete_token(token_name, opts \\ []) do
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

  @doc """
  Normalizes a token map, adding `issued_at` and `expires_at` if needed.
  """
  @spec normalize_token(map()) :: map()
  def normalize_token(token_info) when is_map(token_info) do
    issued_at =
      Map.get(token_info, "issued_at") || Map.get(token_info, :issued_at) ||
        System.system_time(:second)

    expires_in = Map.get(token_info, "expires_in") || Map.get(token_info, :expires_in)

    token_info
    |> stringify_keys()
    |> Map.put_new("issued_at", issued_at)
    |> maybe_put_expires_at(expires_in, issued_at)
  end

  @doc """
  Checks if a token is expired.
  """
  @spec expired?(map(), non_neg_integer()) :: boolean()
  def expired?(token_info, skew_seconds \\ 30) when is_map(token_info) do
    now = System.system_time(:second)

    case token_info["expires_at"] do
      expires_at when is_integer(expires_at) -> expires_at <= now + skew_seconds
      _ -> false
    end
  end

  defp maybe_put_expires_at(token_info, expires_in, issued_at) when is_integer(expires_in) do
    Map.put_new(token_info, "expires_at", issued_at + expires_in)
  end

  defp maybe_put_expires_at(token_info, expires_in, issued_at) when is_binary(expires_in) do
    case Integer.parse(expires_in) do
      {value, ""} -> Map.put_new(token_info, "expires_at", issued_at + value)
      _ -> token_info
    end
  end

  defp maybe_put_expires_at(token_info, _expires_in, _issued_at), do: token_info

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
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
