// The sandbox form widget: box/item rows, AusPost presets, client-side validation, and the
// "Pack" action. Calls the pack API and notifies the caller of the new packing id via onPacked.
import { pack } from "./api.js";

const el = (id) => document.getElementById(id);

const PRESETS = {
  "AusPost Small": { width: 220, length: 160, depth: 70 },
  "AusPost Medium": { width: 310, length: 225, depth: 102 },
  "AusPost Large": { width: 400, length: 275, depth: 175 },
  "AusPost X-Large": { width: 500, length: 440, depth: 350 },
};
// Australia Post "Within Australia" parcel limits (mm / mm³ / grams) — mirror the server checks.
const MAX_WEIGHT_G = 22000,
  MAX_LEN_MM = 1050,
  MAX_VOL_MM3 = 250000000;

function mkInput(type, name, value) {
  const i = document.createElement("input");
  i.type = type;
  i.dataset.name = name;
  if (value !== "" && value != null) i.value = value;
  if (type === "number") i.min = "1";
  return i;
}

function rmButton(row) {
  const b = document.createElement("button");
  b.type = "button";
  b.textContent = "✕";
  b.className = "rm";
  b.onclick = () => row.remove();
  return b;
}

function boxRow(data = {}) {
  const row = document.createElement("div");
  row.className = "row box-row";
  const preset = document.createElement("select");
  preset.className = "preset";
  ["Custom", ...Object.keys(PRESETS)].forEach((name) => {
    const o = document.createElement("option");
    o.value = name;
    o.textContent = name;
    preset.appendChild(o);
  });
  const ref = mkInput("text", "reference", data.reference || "");
  ref.placeholder = "reference";
  const w = mkInput("number", "width", data.width || "");
  const l = mkInput("number", "length", data.length || "");
  const d = mkInput("number", "depth", data.depth || "");
  const mw = mkInput("number", "max_weight", data.max_weight || MAX_WEIGHT_G);
  w.placeholder = "W";
  l.placeholder = "L";
  d.placeholder = "D";
  mw.placeholder = "max wt (g)";
  preset.onchange = () => {
    const p = PRESETS[preset.value];
    if (p) {
      w.value = p.width;
      l.value = p.length;
      d.value = p.depth;
      mw.value = MAX_WEIGHT_G;
      if (!ref.value) ref.value = preset.value;
    }
  };
  [preset, ref, w, l, d, mw, rmButton(row)].forEach((n) => row.appendChild(n));
  el("boxes").appendChild(row);
  if (data.preset) preset.value = data.preset;
}

function itemRow(data = {}) {
  const row = document.createElement("div");
  row.className = "row item-row";
  const desc = mkInput("text", "description", data.description || "");
  desc.placeholder = "description";
  const w = mkInput("number", "width", data.width || "");
  w.placeholder = "W";
  const l = mkInput("number", "length", data.length || "");
  l.placeholder = "L";
  const d = mkInput("number", "depth", data.depth || "");
  d.placeholder = "D";
  const wt = mkInput("number", "weight", data.weight || "");
  wt.placeholder = "wt (g)";
  const qty = mkInput("number", "quantity", data.quantity || 1);
  qty.placeholder = "qty";
  const rot = document.createElement("select");
  rot.dataset.name = "rotation";
  ["best_fit", "keep_flat", "never"].forEach((r) => {
    const o = document.createElement("option");
    o.value = r;
    o.textContent = r;
    rot.appendChild(o);
  });
  if (data.rotation) rot.value = data.rotation;
  [desc, w, l, d, wt, qty, rot, rmButton(row)].forEach((n) => row.appendChild(n));
  el("items").appendChild(row);
}

function readRow(row) {
  const o = {};
  row.querySelectorAll("input,select").forEach((n) => {
    if (!n.dataset.name) return;
    const v = n.value.trim();
    o[n.dataset.name] = n.type === "number" ? (v === "" ? null : Number(v)) : v;
  });
  return o;
}

function collectSpec() {
  return {
    label: "sandbox",
    boxes: [...document.querySelectorAll("#boxes .box-row")].map(readRow),
    items: [...document.querySelectorAll("#items .item-row")].map(readRow),
  };
}

// Mirrors the server's validation so the user gets instant feedback (server stays authoritative).
function validate(spec) {
  if (!spec.boxes.length) return "Add at least one box.";
  if (!spec.items.length) return "Add at least one item.";
  for (const b of spec.boxes) {
    const name = b.reference || "?";
    for (const k of ["width", "length", "depth"])
      if (!(b[k] > 0)) return `Box "${name}": ${k} must be a positive number.`;
    const longest = Math.max(b.width, b.length, b.depth);
    if (longest > MAX_LEN_MM)
      return `Box "${name}" exceeds Australia Post limit: longest side ${longest} mm > ${MAX_LEN_MM} mm.`;
    const vol = b.width * b.length * b.depth;
    if (vol > MAX_VOL_MM3)
      return `Box "${name}" exceeds Australia Post limit: volume ${vol} mm³ > ${MAX_VOL_MM3} mm³.`;
    const mw = b.max_weight || MAX_WEIGHT_G;
    if (mw > MAX_WEIGHT_G)
      return `Box "${name}" exceeds Australia Post limit: max weight ${mw} g > ${MAX_WEIGHT_G} g.`;
  }
  for (const it of spec.items) {
    const name = it.description || "?";
    for (const k of ["width", "length", "depth", "weight"])
      if (!(it[k] > 0)) return `Item "${name}": ${k} must be a positive number.`;
  }
  return null;
}

function showErr(msg) {
  const e = el("builder-error");
  e.textContent = "⚠ " + msg;
  e.hidden = false;
}

function loadExample() {
  el("boxes").innerHTML = "";
  el("items").innerHTML = "";
  boxRow({
    preset: "AusPost Medium",
    reference: "AusPost Medium",
    ...PRESETS["AusPost Medium"],
    max_weight: MAX_WEIGHT_G,
  });
  [
    {
      description: "book",
      width: 210,
      length: 140,
      depth: 20,
      weight: 300,
      quantity: 6,
      rotation: "best_fit",
    },
    {
      description: "mug",
      width: 100,
      length: 80,
      depth: 100,
      weight: 400,
      quantity: 4,
      rotation: "best_fit",
    },
    {
      description: "cable",
      width: 60,
      length: 40,
      depth: 30,
      weight: 80,
      quantity: 8,
      rotation: "best_fit",
    },
  ].forEach(itemRow);
}

// Wire up the builder panel. `onPacked(id)` is called with the new packing id after a successful pack.
export function initBuilder({ onPacked }) {
  async function doPack(ev) {
    ev.preventDefault();
    const spec = collectSpec();
    const clientErr = validate(spec);
    if (clientErr) return showErr(clientErr);
    el("builder-error").hidden = true;
    try {
      const { ok, id, error, status } = await pack(spec);
      if (!ok) return showErr(error || `pack failed (${status})`);
      onPacked(id);
    } catch (e) {
      showErr(String(e));
    }
  }

  el("new-toggle").onclick = () => {
    const f = el("builder");
    f.hidden = !f.hidden;
    if (!f.hidden && !el("boxes").children.length) {
      boxRow();
      itemRow();
    }
  };
  el("add-box").onclick = () => boxRow();
  el("add-item").onclick = () => itemRow();
  el("load-example").onclick = loadExample;
  el("builder").addEventListener("submit", doPack);
}
