// Entry point: wires the packings list ↔ the 3D viewer ↔ the sandbox builder, and refreshes
// the list on Server-Sent-Events. Loaded as a module after the vendored three.min.js.
import { listPackings, getPacking, subscribe } from "./api.js";
import { createViewer } from "./scene.js";
import { initBuilder } from "./builder.js";

const el = (id) => document.getElementById(id);
const viewer = createViewer();

async function selectPacking(id, li) {
  document.querySelectorAll("#packings li").forEach((n) => n.classList.remove("active"));
  if (li) li.classList.add("active");
  viewer.showPayload(await getPacking(id));
}

async function loadList() {
  const items = await listPackings();
  const ul = el("packings");
  ul.innerHTML = "";
  items.forEach((p) => {
    const li = document.createElement("li");
    li.textContent = `${p.label || "packing"} — ${p.summary.boxes}b/${p.summary.items}i/${p.summary.utilisation}%`;
    li.onclick = () => selectPacking(p.id, li);
    ul.appendChild(li);
  });
}

initBuilder({
  onPacked: async (id) => {
    await loadList();
    await selectPacking(id, document.querySelector("#packings li"));
  },
});

loadList();
subscribe(() => loadList());
