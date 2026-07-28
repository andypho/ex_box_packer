defmodule ExBoxPacker.Engine.Cache do
  @moduledoc false
  # Per-pack, per-process memoization for pure geometric computations (mirrors BoxPacker's
  # static caches). Lives in the process dictionary under one namespaced key, created only at
  # the OUTERMOST pack and torn down after — so it is concurrency-safe (each request runs in
  # its own BEAM process), cannot clash with other libraries, and is bounded to a single pack.
  @key {__MODULE__, :pack_cache}

  @spec with_cache((-> result)) :: result when result: var
  def with_cache(fun) do
    if Process.get(@key) == nil do
      Process.put(@key, %{})

      try do
        fun.()
      after
        Process.delete(@key)
      end
    else
      fun.()
    end
  end

  @spec get_or_compute(term(), (-> value)) :: value when value: var
  def get_or_compute(key, fun) do
    case Process.get(@key) do
      nil ->
        fun.()

      cache ->
        case cache do
          %{^key => cached} ->
            cached

          _ ->
            value = fun.()
            # re-read: nested computes may have added entries while `fun` ran
            Process.put(@key, Map.put(Process.get(@key), key, value))
            value
        end
    end
  end
end
