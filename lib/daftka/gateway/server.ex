defmodule Daftka.Gateway.Server do
  @moduledoc """
  HTTP API Gateway router using Plug.

  Exposes JSON endpoints to produce, fetch, and inspect offsets.
  """

  use Plug.Router
  use Plug.ErrorHandler

  alias Daftka.Metadata.Store
  alias Daftka.Router
  alias Daftka.Types

  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json, :urlencoded],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:dispatch)

  get "/healthz" do
    send_resp(conn, 200, "ok")
  end

  # --- Metadata API ---
  # POST /topics {name, partitions?}
  post "/topics" do
    name = Map.get(conn.body_params, "name") || Map.get(conn.body_params, "topic")
    partitions = Map.get(conn.body_params, "partitions")

    with true <- is_binary(name) or {:error, :invalid_topic},
         {:ok, topic} <- Types.new_topic(name) do
      result =
        case partitions do
          int when is_integer(int) and int > 0 -> Store.create_topic(topic, int)
          nil -> Store.create_topic(topic)
          _ -> {:error, :invalid_partitions}
        end

      case result do
        :ok -> json(conn, 201, %{ok: true})
        {:error, :topic_exists} -> json(conn, 409, %{error: "topic_exists"})
        {:error, :invalid_partitions} -> json(conn, 400, %{error: "invalid_partitions"})
        {:error, :invalid_topic} -> json(conn, 400, %{error: "invalid_topic"})
      end
    else
      {:error, :invalid_topic} -> json(conn, 400, %{error: "invalid_topic"})
      _ -> json(conn, 400, %{error: "invalid_body"})
    end
  end

  # GET /topics -> [{name, partitions}]
  get "/topics" do
    topics =
      Store.list_topics()
      |> Enum.map(fn {t, meta} ->
        %{name: Types.topic_value(t), partitions: map_size(meta.partitions)}
      end)

    json(conn, 200, %{topics: topics})
  end

  # POST /topics/:topic/partitions/:partition/produce
  post "/topics/:topic/partitions/:partition/produce" do
    with {:ok, topic} <- Types.new_topic(topic),
         {part_int, ""} <- Integer.parse(partition),
         {:ok, part} <- Types.new_partition(part_int),
         %{"key" => key, "value" => value} <- conn.body_params,
         headers <- Map.get(conn.body_params, "headers", %{}),
         true <- is_binary(key) and is_binary(value) and is_map(headers) do
      case Router.produce(topic, part, key, value, headers) do
        {:ok, offset} ->
          json(conn, 200, %{offset: Types.offset_value(offset)})

        {:error, :not_found} ->
          json(conn, 404, %{error: "partition_owner_not_found"})

        {:error, reason} ->
          json(conn, 400, %{error: to_string(reason)})
      end
    else
      {:error, :invalid_topic} -> json(conn, 400, %{error: "invalid_topic"})
      {:error, :invalid_partition} -> json(conn, 400, %{error: "invalid_partition"})
      :error -> json(conn, 400, %{error: "invalid_partition"})
      _ -> json(conn, 400, %{error: "invalid_body"})
    end
  end

  # GET /topics/:topic/partitions/:partition/fetch?from_offset=N&max_count=M
  get "/topics/:topic/partitions/:partition/fetch" do
    with {:ok, topic} <- Types.new_topic(topic),
         {part_int, ""} <- Integer.parse(partition),
         {:ok, part} <- Types.new_partition(part_int),
         {from_int, ""} <- Integer.parse(Map.get(conn.params, "from_offset", "0")),
         {:ok, from_offset} <- Types.new_offset(from_int),
         {max_count, ""} <- Integer.parse(Map.get(conn.params, "max_count", "50")),
         true <- max_count > 0 do
      case Router.fetch_from(topic, part, from_offset, max_count) do
        {:ok, messages} ->
          encoded =
            Enum.map(messages, fn m ->
              %{
                offset: Types.offset_value(m.offset),
                key: m.key,
                value: m.value,
                headers: m.headers
              }
            end)

          json(conn, 200, %{messages: encoded})

        {:error, :not_found} ->
          json(conn, 404, %{error: "partition_owner_not_found"})

        {:error, reason} ->
          json(conn, 400, %{error: to_string(reason)})
      end
    else
      {:error, :invalid_topic} -> json(conn, 400, %{error: "invalid_topic"})
      {:error, :invalid_partition} -> json(conn, 400, %{error: "invalid_partition"})
      {:error, :invalid_offset} -> json(conn, 400, %{error: "invalid_offset"})
      _ -> json(conn, 400, %{error: "invalid_query"})
    end
  end

  # GET /topics/:topic/partitions/:partition/next_offset
  get "/topics/:topic/partitions/:partition/next_offset" do
    with {:ok, topic} <- Types.new_topic(topic),
         {part_int, ""} <- Integer.parse(partition),
         {:ok, part} <- Types.new_partition(part_int) do
      case Router.next_offset(topic, part) do
        {:ok, offset} -> json(conn, 200, %{next_offset: Types.offset_value(offset)})
        {:error, :not_found} -> json(conn, 404, %{error: "partition_owner_not_found"})
        {:error, reason} -> json(conn, 400, %{error: to_string(reason)})
      end
    else
      {:error, :invalid_topic} -> json(conn, 400, %{error: "invalid_topic"})
      {:error, :invalid_partition} -> json(conn, 400, %{error: "invalid_partition"})
      _ -> json(conn, 400, %{error: "invalid_path"})
    end
  end

  match _ do
    json(conn, 404, %{error: "not_found"})
  end

  defp json(conn, status, data) do
    body = Jason.encode!(data)

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, body)
  end

  @impl true
  def handle_errors(conn, %{reason: _reason}) do
    json(conn, 500, %{error: "internal"})
  end
end
