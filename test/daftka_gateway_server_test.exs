defmodule DaftkaGatewayServerTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn

  alias Daftka.Gateway.Server
  alias Daftka.Metadata.Store
  alias Daftka.PartitionReplica.Supervisor, as: PartSup
  alias Daftka.Partitions.Supervisor, as: Partitions
  alias Daftka.Types

  @opts Server.init([])

  setup do
    Store.clear()

    {:ok, topic} = Types.new_topic("api")
    :ok = Store.create_topic(topic, 1)

    {:ok, pid} = Partitions.start_partition_supervisor({"api", 0})

    on_exit(fn ->
      if Process.alive?(pid), do: DynamicSupervisor.terminate_child(Partitions, pid)
    end)

    server = PartSup.server_name("api", 0)
    {:ok, part} = Types.new_partition(0)
    :ok = Store.set_partition_owner(topic, part, GenServer.whereis(server))

    {:ok, %{topic: topic, part: part}}
  end

  test "healthz" do
    conn = conn(:get, "/healthz") |> Server.call(@opts)
    assert conn.status == 200
    assert conn.resp_body == "ok"
  end

  test "produce then fetch and next_offset", %{topic: topic} do
    # produce
    body = %{key: "k1", value: "v1", headers: %{"a" => "1"}} |> Jason.encode!()

    conn =
      conn(:post, "/topics/#{Types.topic_value(topic)}/partitions/0/produce", body)
      |> put_req_header("content-type", "application/json")
      |> Server.call(@opts)

    assert conn.status == 200
    %{"offset" => 0} = Jason.decode!(conn.resp_body)

    # next_offset
    conn =
      conn(:get, "/topics/#{Types.topic_value(topic)}/partitions/0/next_offset")
      |> Server.call(@opts)

    assert conn.status == 200
    %{"next_offset" => 1} = Jason.decode!(conn.resp_body)

    # fetch
    conn =
      conn(
        :get,
        "/topics/#{Types.topic_value(topic)}/partitions/0/fetch?from_offset=0&max_count=10"
      )
      |> Server.call(@opts)

    assert conn.status == 200
    %{"messages" => [m]} = Jason.decode!(conn.resp_body)
    assert m["key"] == "k1"
    assert m["value"] == "v1"
    assert m["headers"] == %{"a" => "1"}
    assert m["offset"] == 0
  end

  test "create topic and list topics" do
    # create topic
    body = %{name: "t1", partitions: 2} |> Jason.encode!()

    conn =
      conn(:post, "/topics", body)
      |> put_req_header("content-type", "application/json")
      |> Server.call(@opts)

    assert conn.status == 201

    # list topics
    conn = conn(:get, "/topics") |> Server.call(@opts)
    assert conn.status == 200
    %{"topics" => topics} = Jason.decode!(conn.resp_body)
    assert Enum.any?(topics, &(&1["name"] == "t1" and &1["partitions"] == 2))
  end
end
