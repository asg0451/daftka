defmodule DaftkaE2EHTTPTest do
  use ExUnit.Case, async: false

  alias Daftka.MetadataAPI.Server, as: MetadataAPI

  @gateway_port Application.compile_env(:daftka, :gateway_port, 4001)

  setup_all do
    :inets.start()
    :ok
  end

  setup do
    topic_name = "e2e_" <> Integer.to_string(System.unique_integer([:positive]))
    :ok = MetadataAPI.create_topic(topic_name, 1)
    assert :ok = MetadataAPI.wait_for_online(topic_name, 0, 2_000)

    {:ok, %{topic_name: topic_name}}
  end

  defp http_json(method, path, body \\ nil) do
    url =
      ~c"http://localhost:" ++ to_charlist(Integer.to_string(@gateway_port)) ++ to_charlist(path)

    headers = [{~c"content-type", ~c"application/json"}]

    case method do
      :get ->
        :httpc.request(:get, {url, []}, [], [])

      :post ->
        payload = if body, do: Jason.encode!(body), else: ""
        :httpc.request(:post, {url, headers, ~c"application/json", to_charlist(payload)}, [], [])
    end
  end

  test "end-to-end produce, next_offset, fetch", %{topic_name: topic_name} do
    # health check first
    assert {:ok, {{_, 200, _}, _h, ~c"ok"}} = http_json(:get, "/healthz")

    # produce
    {:ok, {{_, 200, _}, _headers, body}} =
      http_json(:post, "/topics/#{topic_name}/partitions/0/produce", %{
        key: "k1",
        value: "v1",
        headers: %{}
      })

    %{"offset" => 0} = Jason.decode!(List.to_string(body))

    # next offset
    {:ok, {{_, 200, _}, _headers2, body2}} =
      http_json(:get, "/topics/#{topic_name}/partitions/0/next_offset")

    %{"next_offset" => 1} = Jason.decode!(List.to_string(body2))

    # fetch
    {:ok, {{_, 200, _}, _headers3, body3}} =
      http_json(:get, "/topics/#{topic_name}/partitions/0/fetch?from_offset=0&max_count=10")

    %{"messages" => [m]} = Jason.decode!(List.to_string(body3))
    assert m["key"] == "k1"
    assert m["value"] == "v1"
    assert m["offset"] == 0
  end
end
