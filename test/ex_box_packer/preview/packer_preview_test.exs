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
end
