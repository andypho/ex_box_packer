defmodule ExBoxPacker.Test.TestPubsub do
  @moduledoc false
  # Minimal Absinthe.Subscription.Pubsub implementation, enough for
  # `Absinthe.Subscription.publish/3` to run end-to-end in tests. Mutations are
  # forwarded to whichever process registered itself via `set_owner/1`, so a test
  # can assert on what ExBoxPacker.Broadcast actually handed to Absinthe.
  @behaviour Absinthe.Subscription.Pubsub

  @owner __MODULE__.Owner

  @doc "Route published mutations to `pid`."
  def set_owner(pid) do
    if is_nil(Process.whereis(@owner)) do
      Process.register(pid, @owner)
    else
      Process.unregister(@owner)
      Process.register(pid, @owner)
    end
  end

  @impl true
  def node_name, do: Atom.to_string(node())

  @impl true
  def subscribe(_topic), do: :ok

  @impl true
  def publish_mutation(proxy_topic, mutation_result, subscribed_fields) do
    send(@owner, {:absinthe_mutation, proxy_topic, mutation_result, subscribed_fields})
    :ok
  end

  @impl true
  def publish_subscription(topic, data) do
    send(@owner, {:absinthe_subscription, topic, data})
    :ok
  end
end
