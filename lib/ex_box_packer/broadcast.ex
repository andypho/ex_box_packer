defmodule ExBoxPacker.Broadcast do
  @moduledoc """
  Config-driven event publisher for a live packing feed. No callbacks: when
  `ExBoxPacker.Config.broadcast/0` is set (and `absinthe` is loaded), each event is
  published via `Absinthe.Subscription.publish(endpoint, event, [{field, topic}])`.

  A `nil` topic or absent config makes every function a cheap no-op, so packing
  outside a broadcasting context is unaffected. A `:publisher` 2-arity fn in the
  broadcast config overrides the Absinthe path (used in tests).
  """

  alias ExBoxPacker.Broadcast.Event
  alias ExBoxPacker.Config
  alias ExBoxPacker.Result.{PackedBox, PackedBoxList}

  @spec started(String.t() | nil) :: :ok
  def started(topic), do: publish(topic, %Event{type: :started})

  @spec box_packed(String.t() | nil, PackedBox.t()) :: :ok
  def box_packed(topic, box), do: publish(topic, %Event{type: :box_packed, box: box})

  @spec done(String.t() | nil, map()) :: :ok
  def done(topic, summary), do: publish(topic, %Event{type: :done, summary: summary})

  @doc "Aggregate summary for the `:done` event."
  @spec summary(PackedBoxList.t(), [ExBoxPacker.Item.t()]) :: map()
  def summary(%PackedBoxList{} = packed, leftover) do
    count = PackedBoxList.count(packed)

    %{
      box_count: count,
      # Delegate to the library's canonical aggregate (round_half_up) so the
      # broadcast summary can't drift from PackedBoxList.volume_utilisation/1.
      # Guard the empty case (that function divides by zero on no boxes).
      volume_utilisation: if(count > 0, do: PackedBoxList.volume_utilisation(packed), else: 0.0),
      unpacked: leftover
    }
  end

  defp publish(nil, _event), do: :ok

  defp publish(topic, event) do
    case Config.broadcast() do
      cfg when is_list(cfg) -> do_publish(cfg, topic, event)
      _ -> :ok
    end
  end

  # A `:publisher` fn in config is a test seam (receives `(topic, event)`); the
  # default path publishes through Absinthe. `apply/3` keeps the optional dep out
  # of the compile-time reference graph.
  defp do_publish(cfg, topic, event) do
    case cfg[:publisher] do
      fun when is_function(fun, 2) ->
        fun.(topic, event)
        :ok

      _ ->
        with endpoint when not is_nil(endpoint) <- cfg[:endpoint],
             field when not is_nil(field) <- cfg[:field],
             true <- Code.ensure_loaded?(Absinthe.Subscription) do
          # Fire-and-forget: a live packing feed tolerates a dropped event, so we
          # intentionally ignore Absinthe's publish result and always return :ok.
          #
          # `apply/3` (not a direct call) is deliberate: it keeps the optional
          # `absinthe` dependency out of this module's compile-time reference graph,
          # so the library compiles cleanly for apps that don't pull absinthe in.
          # credo:disable-for-next-line Credo.Check.Refactor.Apply
          apply(Absinthe.Subscription, :publish, [endpoint, event, [{field, topic}]])
          :ok
        else
          _ -> :ok
        end
    end
  end
end
