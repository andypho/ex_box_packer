defmodule ExBoxPacker.PackerPreviewTest.JSONDecoder do
  @moduledoc false
  # Minimal :json_decoder for Plug.Parsers, so these tests can simulate a host
  # application (e.g. Phoenix) that has already parsed the JSON body.
  def decode!(binary), do: :json.decode(binary)
end

defmodule ExBoxPacker.PackerPreviewTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  alias ExBoxPacker.PackerPreviewTest.JSONDecoder
  alias ExBoxPacker.Preview.Collector

  @opts ExBoxPacker.PackerPreview.init([])

  @parser_opts Plug.Parsers.init(
                 parsers: [:json],
                 pass: ["application/json"],
                 json_decoder: JSONDecoder
               )

  setup do
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: true])
    start_supervised!(Collector)
    on_exit(fn -> Application.delete_env(:ex_box_packer, ExBoxPacker) end)
    :ok
  end

  defp post_pack(spec) do
    body = IO.iodata_to_binary(:json.encode(spec))

    conn(:post, "/api/pack", body)
    |> put_req_header("content-type", "application/json")
    |> ExBoxPacker.PackerPreview.call(@opts)
  end

  # POST a raw body that a host's Plug.Parsers has already consumed and decoded,
  # leaving the result in conn.body_params.
  defp post_pack_preparsed(body) do
    conn(:post, "/api/pack", body)
    |> put_req_header("content-type", "application/json")
    |> Plug.Parsers.call(@parser_opts)
    |> ExBoxPacker.PackerPreview.call(@opts)
  end

  defp valid_spec do
    %{
      "boxes" => [%{"reference" => "B", "width" => 100, "length" => 100, "depth" => 100}],
      "items" => [
        %{"description" => "w", "width" => 40, "length" => 40, "depth" => 40, "weight" => 100}
      ]
    }
  end

  defp wait_until(fun, remaining \\ 200) do
    cond do
      fun.() -> :ok
      remaining <= 0 -> flunk("condition did not become true within 200ms")
      true -> Process.sleep(5) && wait_until(fun, remaining - 5)
    end
  end

  test "GET / serves the HTML shell" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/"), @opts)
    assert conn.status == 200
    assert conn.resp_body =~ "preview"
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/html"
  end

  test "GET /api/packings returns JSON list (newest first)" do
    Collector.capture(%{"items" => [], "boxes" => []}, %{boxes: 0, items: 0, utilisation: 0.0},
      label: "one"
    )

    Process.sleep(20)
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/api/packings"), @opts)
    assert conn.status == 200
    assert [%{"label" => "one"}] = :json.decode(conn.resp_body)
  end

  test "GET /api/packings/:id returns the payload; unknown id -> 404" do
    Collector.capture(
      %{"items" => [["c", 1, 1, 1]], "boxes" => []},
      %{boxes: 0, items: 1, utilisation: 0.0},
      label: "p"
    )

    Process.sleep(20)

    [%{"id" => id}] =
      ExBoxPacker.PackerPreview.call(conn(:get, "/api/packings"), @opts).resp_body
      |> :json.decode()

    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/api/packings/#{id}"), @opts)
    assert conn.status == 200
    assert %{"items" => [["c", 1, 1, 1]]} = :json.decode(conn.resp_body)
    assert ExBoxPacker.PackerPreview.call(conn(:get, "/api/packings/999999"), @opts).status == 404
  end

  test "GET /api/packings/:id with non-integer id returns 404" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/api/packings/not-an-int"), @opts)
    assert conn.status == 404
  end

  test "GET /assets/app.css returns 200 with text/css" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/assets/app.css"), @opts)
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/css"
  end

  test "GET /assets/app.js returns 200 with text/javascript" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/assets/app.js"), @opts)
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/javascript"
  end

  test "GET /assets/nope.js returns 404" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/assets/nope.js"), @opts)
    assert conn.status == 404
  end

  test "unknown route returns 404" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/unknown"), @opts)
    assert conn.status == 404
  end

  test "POST /api/pack packs a valid spec, stores it, and returns {ok, id}" do
    spec = %{
      "label" => "sandbox",
      "boxes" => [
        %{
          "reference" => "B",
          "width" => 100,
          "length" => 100,
          "depth" => 100,
          "max_weight" => 22_000
        }
      ],
      "items" => [
        %{
          "description" => "w",
          "width" => 40,
          "length" => 40,
          "depth" => 40,
          "weight" => 100,
          "quantity" => 2,
          "rotation" => "best_fit"
        }
      ]
    }

    conn = post_pack(spec)
    assert conn.status == 200
    assert %{"ok" => true, "id" => id} = :json.decode(conn.resp_body)
    assert is_integer(id)
    assert %{"boxes" => [_ | _]} = Collector.get(id)
  end

  test "POST /api/pack with an invalid spec returns 422 with a message" do
    conn = post_pack(%{"boxes" => [], "items" => []})
    assert conn.status == 422
    assert %{"ok" => false, "error" => msg} = :json.decode(conn.resp_body)
    assert msg =~ "at least one box"
  end

  test "POST /api/pack with a box over the AusPost limit returns 422" do
    spec = %{
      "boxes" => [%{"reference" => "Long", "width" => 1200, "length" => 100, "depth" => 100}],
      "items" => [
        %{"description" => "w", "width" => 10, "length" => 10, "depth" => 10, "weight" => 1}
      ]
    }

    conn = post_pack(spec)
    assert conn.status == 422
    assert %{"ok" => false, "error" => msg} = :json.decode(conn.resp_body)
    assert msg =~ "longest side 1200 mm > 1050 mm"
  end

  test "POST /api/pack with an item too large for any box returns 422" do
    spec = %{
      "boxes" => [%{"reference" => "B", "width" => 10, "length" => 10, "depth" => 10}],
      "items" => [
        %{"description" => "big", "width" => 100, "length" => 100, "depth" => 100, "weight" => 1}
      ]
    }

    conn = post_pack(spec)
    assert conn.status == 422
    assert %{"ok" => false} = :json.decode(conn.resp_body)
  end

  test "GET / leaves no template placeholders in the served HTML" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/"), @opts)
    refute conn.resp_body =~ "{{BASE}}"
    refute conn.resp_body =~ ~r/\{\{[A-Z]+\}\}/
  end

  test "GET / includes the sandbox builder form" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/"), @opts)
    assert conn.resp_body =~ ~s(id="builder")
    assert conn.resp_body =~ "Load example"
  end

  # A host that mounts this Plug behind `protect_from_forgery` (e.g. Phoenix's `:browser`
  # pipeline) installs Plug.CSRFProtection, whose before_send raises
  # InvalidCrossOriginRequestError for any GET served as `text/javascript`. Serving our static
  # JS must opt out of that guard, or the whole viewer fails to load.
  test "serving JS assets is not blocked by a host's Plug.CSRFProtection cross-origin guard" do
    conn =
      conn(:get, "/assets/app.js")
      |> init_test_session(%{})
      |> Plug.CSRFProtection.call(Plug.CSRFProtection.init([]))
      |> ExBoxPacker.PackerPreview.call(@opts)

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
  end

  describe "GET /assets/vendor/:file" do
    test "serves a bundled vendor asset with the right content type" do
      conn = ExBoxPacker.PackerPreview.call(conn(:get, "/assets/vendor/three.min.js"), @opts)
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/javascript"
      assert byte_size(conn.resp_body) > 0
    end

    test "returns 404 for an unknown vendor asset" do
      conn = ExBoxPacker.PackerPreview.call(conn(:get, "/assets/vendor/nope.js"), @opts)
      assert conn.status == 404
      assert conn.resp_body == "not found"
    end

    test "cannot escape the vendor directory via a traversal path" do
      conn = ExBoxPacker.PackerPreview.call(conn(:get, "/assets/vendor/..%2fapp.js"), @opts)
      assert conn.status == 404
    end
  end

  test "GET /assets/index.html is served as text/html" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/assets/index.html"), @opts)
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/html"
  end

  describe "POST /api/pack body handling" do
    test "uses body_params when a host's parser already decoded the JSON body" do
      conn = post_pack_preparsed(IO.iodata_to_binary(:json.encode(valid_spec())))
      assert conn.status == 200
      assert %{"ok" => true, "id" => id} = :json.decode(conn.resp_body)
      assert %{"boxes" => [_ | _]} = Collector.get(id)
    end

    test "returns 422 when a host's parser decoded an empty body to an empty map" do
      conn = post_pack_preparsed("")
      assert conn.status == 422
      assert %{"ok" => false, "error" => "invalid JSON body"} = :json.decode(conn.resp_body)
    end

    test "returns 422 for a malformed raw JSON body" do
      conn =
        conn(:post, "/api/pack", "{not valid json")
        |> put_req_header("content-type", "application/json")
        |> ExBoxPacker.PackerPreview.call(@opts)

      assert conn.status == 422
      assert %{"ok" => false, "error" => "invalid JSON body"} = :json.decode(conn.resp_body)
    end

    test "returns 422 for an empty raw body" do
      conn =
        conn(:post, "/api/pack", "")
        |> put_req_header("content-type", "application/json")
        |> ExBoxPacker.PackerPreview.call(@opts)

      assert conn.status == 422
      assert %{"ok" => false, "error" => "invalid JSON body"} = :json.decode(conn.resp_body)
    end

    test "returns 422 when the decoded body is a JSON value that is not an object" do
      conn =
        conn(:post, "/api/pack", "[1,2,3]")
        |> put_req_header("content-type", "application/json")
        |> ExBoxPacker.PackerPreview.call(@opts)

      assert conn.status == 422
      assert %{"ok" => false, "error" => msg} = :json.decode(conn.resp_body)
      assert msg =~ "expected a JSON object"
    end
  end

  describe "GET /api/stream" do
    test "opens a chunked SSE response, subscribes, and streams new packings" do
      parent = self()
      # `owner` is this process, so the adapter notifies us when the response is sent.
      stream_conn = conn(:get, "/api/stream")

      streamer =
        spawn(fn ->
          send(parent, :calling)
          ExBoxPacker.PackerPreview.call(stream_conn, @opts)
        end)

      assert_receive :calling

      # send_chunked/2 ran: a chunked response is open.
      assert_receive {:plug_conn, :sent}

      # The streaming process subscribed itself to the collector.
      wait_until(fn ->
        MapSet.member?(:sys.get_state(Collector).subscribers, streamer)
      end)

      # capture_sync returns only after the collector has sent to subscribers, so the
      # event is guaranteed to be in (or already consumed from) the streamer's mailbox.
      Collector.capture_sync(%{"boxes" => []}, %{boxes: 0, items: 0, utilisation: 0.0},
        label: "streamed"
      )

      # An empty mailbox therefore proves stream_loop received the event, chunked it,
      # and recursed — had chunk/2 failed or raised, the process would have exited.
      wait_until(fn -> Process.info(streamer, :messages) == {:messages, []} end)
      assert Process.alive?(streamer)

      Process.exit(streamer, :kill)
    end

    test "a disconnected stream is dropped from the collector's subscribers" do
      parent = self()
      stream_conn = conn(:get, "/api/stream")

      streamer =
        spawn(fn ->
          send(parent, :calling)
          ExBoxPacker.PackerPreview.call(stream_conn, @opts)
        end)

      assert_receive :calling
      assert_receive {:plug_conn, :sent}
      wait_until(fn -> MapSet.member?(:sys.get_state(Collector).subscribers, streamer) end)

      Process.exit(streamer, :kill)

      wait_until(fn ->
        not MapSet.member?(:sys.get_state(Collector).subscribers, streamer)
      end)
    end
  end
end
