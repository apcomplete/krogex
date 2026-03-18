defmodule KrogexTest do
  use ExUnit.Case

  describe "new/1" do
    test "creates a client with required options" do
      client = Krogex.new(client_id: "test_id", client_secret: "test_secret")

      assert client.client_id == "test_id"
      assert client.client_secret == "test_secret"
      assert client.base_url == "https://api.kroger.com"
    end

    test "accepts optional redirect_uri" do
      client =
        Krogex.new(
          client_id: "test_id",
          client_secret: "test_secret",
          redirect_uri: "http://localhost/callback"
        )

      assert client.redirect_uri == "http://localhost/callback"
    end

    test "raises on missing required options" do
      assert_raise KeyError, fn ->
        Krogex.new(client_id: "test_id")
      end
    end
  end

  describe "put_token/3" do
    test "adds token info to client" do
      client = Krogex.new(client_id: "test_id", client_secret: "test_secret")
      token_info = %{"access_token" => "abc123", "expires_in" => 1800}

      client = Krogex.put_token(client, token_info)

      assert client.token_info["access_token"] == "abc123"
      assert client.token_info["expires_at"]
    end
  end
end
