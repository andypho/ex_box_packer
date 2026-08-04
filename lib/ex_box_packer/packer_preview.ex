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

    alias ExBoxPacker.Packer
    alias ExBoxPacker.Preview.{Collector, Payload, Spec}

    @static_dir Application.app_dir(:ex_box_packer, "priv/static/preview")

    plug(:match)
    plug(:dispatch)

    get "/" do
      # Inject the mount path (from script_name) so asset/API URLs are absolute and work
      # regardless of a trailing slash on the mount point (e.g. forwarded at "/dev/box-packer").
      base = "/" <> Enum.join(conn.script_name, "/")
      base = if base == "/", do: "", else: base

      html =
        @static_dir
        |> Path.join("index.html")
        |> File.read!()
        |> String.replace("{{BASE}}", base)
        |> String.replace("{{CSRF}}", Plug.CSRFProtection.get_csrf_token())

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, html)
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

    post "/api/pack" do
      # No opts are passed to Packer.pack/2, so it returns {:error, exception} rather than
      # raising (a `:timeout` opt is the only thing that makes it raise TimeoutError). Keep it
      # that way, or the `else` below — which handles returned errors, not raised ones — will
      # let the exception escape as a 500.
      with {:ok, params} <- read_spec(conn),
           {:ok, {boxes, items}} <- Spec.decode(params),
           {:ok, result} <- Packer.pack(boxes, items) do
        id =
          Collector.capture_sync(Payload.build(result), Payload.summary(result),
            label: params["label"]
          )

        send_json(conn, 200, %{ok: true, id: id})
      else
        {:error, %{__exception__: true} = e} ->
          send_json(conn, 422, %{ok: false, error: Exception.message(e)})

        {:error, message} when is_binary(message) ->
          send_json(conn, 422, %{ok: false, error: message})
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

    # The host endpoint may already have parsed a JSON body (Phoenix's Plug.Parsers),
    # in which case it is in conn.body_params. Otherwise read and decode the raw body.
    defp read_spec(conn) do
      case conn.body_params do
        %Plug.Conn.Unfetched{} -> read_raw(conn)
        params when is_map(params) and map_size(params) > 0 -> {:ok, params}
        _ -> read_raw(conn)
      end
    end

    defp read_raw(conn) do
      case read_body(conn) do
        {:ok, body, _conn} when byte_size(body) > 0 ->
          try do
            {:ok, :json.decode(body)}
          rescue
            _ -> {:error, "invalid JSON body"}
          end

        _ ->
          {:error, "invalid JSON body"}
      end
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
