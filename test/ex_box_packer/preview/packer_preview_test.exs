defmodule ExBoxPacker.PackerPreviewTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  alias ExBoxPacker.Preview.Collector

  @opts ExBoxPacker.PackerPreview.init([])

  setup do
    Application.put_env(:ex_box_packer, ExBoxPacker.Preview, enabled: true)
    start_supervised!(Collector)
    on_exit(fn -> Application.put_env(:ex_box_packer, ExBoxPacker.Preview, enabled: false) end)
    :ok
  end

  defp post_pack(spec) do
    body = IO.iodata_to_binary(:json.encode(spec))

    conn(:post, "/api/pack", body)
    |> put_req_header("content-type", "application/json")
    |> ExBoxPacker.PackerPreview.call(@opts)
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

  test "GET /assets/viewer.js returns 200 with text/javascript" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/assets/viewer.js"), @opts)
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
      "boxes" => [%{"reference" => "B", "width" => 100, "length" => 100, "depth" => 100, "max_weight" => 22_000}],
      "items" => [%{"description" => "w", "width" => 40, "length" => 40, "depth" => 40, "weight" => 100, "quantity" => 2, "rotation" => "best_fit"}]
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
      "items" => [%{"description" => "w", "width" => 10, "length" => 10, "depth" => 10, "weight" => 1}]
    }

    conn = post_pack(spec)
    assert conn.status == 422
    assert %{"ok" => false, "error" => msg} = :json.decode(conn.resp_body)
    assert msg =~ "longest side 1200 mm > 1050 mm"
  end

  test "POST /api/pack with an item too large for any box returns 422" do
    spec = %{
      "boxes" => [%{"reference" => "B", "width" => 10, "length" => 10, "depth" => 10}],
      "items" => [%{"description" => "big", "width" => 100, "length" => 100, "depth" => 100, "weight" => 1}]
    }

    conn = post_pack(spec)
    assert conn.status == 422
    assert %{"ok" => false} = :json.decode(conn.resp_body)
  end

  test "GET / injects a csrf-token meta tag (no template placeholders left)" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/"), @opts)
    assert conn.resp_body =~ ~s(name="csrf-token")
    refute conn.resp_body =~ "{{CSRF}}"
    refute conn.resp_body =~ "{{BASE}}"
  end

  test "GET / includes the sandbox builder form" do
    conn = ExBoxPacker.PackerPreview.call(conn(:get, "/"), @opts)
    assert conn.resp_body =~ ~s(id="builder")
    assert conn.resp_body =~ "Load example"
  end
end
