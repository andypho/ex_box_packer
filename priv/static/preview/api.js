// Server calls to the ExBoxPacker.PackerPreview endpoints. `base` is the mount path
// (e.g. "/dev/box-packer"), derived from the current URL so the tool works wherever it's forwarded.
const base = location.pathname.replace(/\/$/, "");

export async function listPackings() {
  return (await fetch(`${base}/api/packings`)).json();
}

export async function getPacking(id) {
  return (await fetch(`${base}/api/packings/${id}`)).json();
}

// Packs a sandbox spec. Returns {ok, id, error, status}; throws only on network/JSON errors.
export async function pack(spec) {
  const res = await fetch(`${base}/api/pack`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(spec),
  });
  const data = await res.json();
  return { ok: res.ok && !!data.ok, id: data.id, error: data.error, status: res.status };
}

// Subscribes to the Server-Sent-Events stream; calls `onEvent` on each new packing.
export function subscribe(onEvent) {
  const es = new EventSource(`${base}/api/stream`);
  es.onmessage = onEvent;
  return es;
}
