defmodule ExBoxPacker.Preview.Collector do
  @moduledoc """
  In-memory store of recent packings for the `ExBoxPacker.PackerPreview` dev tool. Holds a
  bounded ring buffer and notifies subscribed Server-Sent-Events connections of new packings.
  Add it to your supervision tree (typically dev-only) to enable the preview.
  """
  use GenServer

  @default_max 50

  # --- client ---

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Store a packing (payload map + summary). Async; safe to call often."
  def capture(payload, summary, opts \\ []),
    do: GenServer.cast(__MODULE__, {:capture, payload, summary, opts[:label]})

  @doc "Recent packings, newest first — summaries only (`%{id, inserted_at, label, summary}`)."
  def list, do: GenServer.call(__MODULE__, :list)

  @doc "Full payload map for one packing id, or nil."
  def get(id), do: GenServer.call(__MODULE__, {:get, id})

  @doc "Subscribe the calling process to `{:preview_packing, entry}` messages for new packings."
  def subscribe, do: GenServer.call(__MODULE__, {:subscribe, self()})

  # --- server ---

  @impl true
  def init(opts) do
    max = opts[:max_packings] || Application.get_env(:ex_box_packer, __MODULE__, [])[:max_packings] || @default_max
    {:ok, %{packings: [], max: max, subscribers: MapSet.new()}}
  end

  @impl true
  def handle_cast({:capture, payload, summary, label}, state) do
    entry = %{id: System.unique_integer([:positive, :monotonic]), inserted_at: System.system_time(:millisecond),
              label: label, summary: summary}
    stored = Map.put(entry, :payload, payload)
    packings = [stored | state.packings] |> Enum.take(state.max)
    for pid <- state.subscribers, do: send(pid, {:preview_packing, Map.delete(entry, :payload)})
    {:noreply, %{state | packings: packings}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Enum.map(state.packings, &Map.take(&1, [:id, :inserted_at, :label, :summary])), state}
  end

  def handle_call({:get, id}, _from, state) do
    {:reply, state.packings |> Enum.find(&(&1.id == id)) |> then(&(&1 && &1.payload)), state}
  end

  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: MapSet.put(state.subscribers, pid)}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end
end
