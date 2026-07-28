if Code.ensure_loaded?(Plug) do
  defmodule ExBoxPacker.PackerPreview do
    @moduledoc """
    A `forward`-able Plug that renders a 3D preview of packings captured via
    `ExBoxPacker.Preview`. Mount it (typically under a dev-only scope):

        scope "/dev" do
          pipe_through [:browser]
          forward "/box-packer", ExBoxPacker.PackerPreview
        end

    Requires the optional `:plug` dependency and a running `ExBoxPacker.Preview.Collector`.
    """
    use Plug.Router

    alias ExBoxPacker.Preview.Collector

    @static_dir Application.app_dir(:ex_box_packer, "priv/static/preview")

    plug(:match)
    plug(:dispatch)

    get "/" do
      conn
      |> put_resp_content_type("text/html")
      |> send_file(200, Path.join(@static_dir, "index.html"))
    end

    get "/api/packings" do
      send_json(conn, 200, Collector.list())
    end

    get "/api/packings/:id" do
      case Integer.parse(id) do
        {int, ""} ->
          case Collector.get(int) do
            nil -> send_json(conn, 404, %{"error" => "not found"})
            payload -> send_json(conn, 200, payload)
          end

        _ ->
          send_json(conn, 404, %{"error" => "not found"})
      end
    end

    get "/api/stream" do
      conn =
        conn
        |> put_resp_header("content-type", "text/event-stream")
        |> put_resp_header("cache-control", "no-cache")
        |> send_chunked(200)

      Collector.subscribe()
      stream_loop(conn)
    end

    get "/assets/:file" do
      path = Path.join(@static_dir, Path.basename(file))

      if File.exists?(path) do
        conn |> put_resp_content_type(content_type(file)) |> send_file(200, path)
      else
        send_resp(conn, 404, "not found")
      end
    end

    get "/assets/vendor/:file" do
      path = Path.join([@static_dir, "vendor", Path.basename(file)])

      if File.exists?(path) do
        conn |> put_resp_content_type(content_type(file)) |> send_file(200, path)
      else
        send_resp(conn, 404, "not found")
      end
    end

    match _ do
      send_resp(conn, 404, "not found")
    end

    defp send_json(conn, status, data) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(status, :json.encode(data))
    end

    defp stream_loop(conn) do
      receive do
        {:preview_packing, entry} ->
          case chunk(conn, "data: " <> IO.iodata_to_binary(:json.encode(entry)) <> "\n\n") do
            {:ok, conn} -> stream_loop(conn)
            {:error, _} -> conn
          end
      after
        30_000 ->
          case chunk(conn, ": keepalive\n\n") do
            {:ok, conn} -> stream_loop(conn)
            {:error, _} -> conn
          end
      end
    end

    defp content_type(file) do
      cond do
        String.ends_with?(file, ".js") -> "text/javascript"
        String.ends_with?(file, ".css") -> "text/css"
        String.ends_with?(file, ".html") -> "text/html"
        true -> "application/octet-stream"
      end
    end
  end
end
