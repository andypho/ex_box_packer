// ex_box_packer packing viewer — Three.js 0.160.0 (vendored)
(function () {
  const base = location.pathname.replace(/\/$/, "");
  const el = (id) => document.getElementById(id);

  // --- sandbox builder config ---
  const PRESETS = {
    "AusPost Small": { width: 220, length: 160, depth: 70 },
    "AusPost Medium": { width: 310, length: 225, depth: 102 },
    "AusPost Large": { width: 400, length: 275, depth: 175 },
    "AusPost X-Large": { width: 500, length: 440, depth: 350 },
  };
  const MAX_WEIGHT_G = 22000, MAX_LEN_MM = 1050, MAX_VOL_MM3 = 250000000;

  const palette = {};
  const colorFor = (desc) =>
    (palette[desc] = palette[desc] || new THREE.Color().setHSL((Object.keys(palette).length * 0.13) % 1, 0.55, 0.55));

  // --- scene ---
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0xf7f7fa);
  const container = el("scene");
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setSize(container.clientWidth, container.clientHeight);
  container.appendChild(renderer.domElement);
  const camera = new THREE.PerspectiveCamera(55, container.clientWidth / container.clientHeight, 1, 100000);
  scene.add(new THREE.AmbientLight(0xffffff, 0.7));
  const dir = new THREE.DirectionalLight(0xffffff, 0.6);
  dir.position.set(1, 2, 1.5);
  scene.add(dir);

  let group = new THREE.Group();
  scene.add(group);
  let meshes = [];   // item cuboids in placement order
  let shown = 0, playing = false, currentBoxes = [], boxIndex = 0;

  function clear() {
    scene.remove(group);
    group = new THREE.Group();
    scene.add(group);
    meshes = [];
    shown = 0;
  }

  function frameCamera(iw, il, id) {
    const c = new THREE.Vector3(iw / 2, id / 2, il / 2);
    camera.position.set(iw * 1.8, id * 1.8, il * 1.8);
    camera.lookAt(c);
  }

  // Three.js: X=width, Y=depth(up), Z=length. Packing coords: x=width, y=length, z=depth(up).
  function addBox(iw, il, id) {
    const geo = new THREE.BoxGeometry(iw, id, il);
    const edges = new THREE.LineSegments(new THREE.EdgesGeometry(geo), new THREE.LineBasicMaterial({ color: 0x333333 }));
    edges.position.set(iw / 2, id / 2, il / 2);
    group.add(edges);
    frameCamera(iw, il, id);
  }

  function addItem([desc, x, y, z, w, l, d]) {
    const mat = new THREE.MeshLambertMaterial({ color: colorFor(desc), transparent: true, opacity: 0.9 });
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, d, l), mat);
    mesh.position.set(x + w / 2, z + d / 2, y + l / 2);
    mesh.visible = false;
    mesh.userData = { desc, x, y, z, w, l, d };
    group.add(mesh);
    meshes.push(mesh);
  }

  function loadBox(payload, idx) {
    clear();
    boxIndex = idx;
    const [ref, iw, il, id, placed] = payload.boxes[idx];
    const items = payload.items;
    addBox(iw, il, id);
    placed.forEach(([itemIdx, x, y, z, w, l, d]) => addItem([items[itemIdx][0], x, y, z, w, l, d]));
    el("scrub").max = meshes.length;
    reveal(meshes.length);        // start fully packed; user can scrub back
    el("stats").textContent = `${ref}: ${placed.length} items`;
  }

  function reveal(n) {
    shown = Math.max(0, Math.min(n, meshes.length));
    meshes.forEach((m, i) => (m.visible = i < shown));
    el("scrub").value = shown;
  }

  // --- data ---
  async function loadList() {
    const res = await fetch(`${base}/api/packings`);
    const items = await res.json();
    const ul = el("packings");
    ul.innerHTML = "";
    items.forEach((p) => {
      const li = document.createElement("li");
      li.textContent = `${p.label || "packing"} — ${p.summary.boxes}b/${p.summary.items}i/${p.summary.utilisation}%`;
      li.onclick = () => selectPacking(p.id, li);
      ul.appendChild(li);
    });
  }

  let payload = null;
  async function selectPacking(id, li) {
    document.querySelectorAll("#packings li").forEach((n) => n.classList.remove("active"));
    if (li) li.classList.add("active");
    payload = await (await fetch(`${base}/api/packings/${id}`)).json();
    const sel = el("box-select");
    sel.innerHTML = "";
    payload.boxes.forEach(([ref], i) => {
      const o = document.createElement("option");
      o.value = i;
      o.textContent = ref;
      sel.appendChild(o);
    });
    sel.onchange = () => loadBox(payload, +sel.value);
    loadBox(payload, 0);
  }

  // --- controls ---
  el("play").onclick = () => { playing = !playing; el("play").textContent = playing ? "Pause" : "Play"; if (playing && shown >= meshes.length) reveal(0); };
  el("step").onclick = () => reveal(shown + 1);
  el("scrub").oninput = (e) => reveal(+e.target.value);

  let acc = 0;
  function tick(t) {
    requestAnimationFrame(tick);
    group.rotation.y += 0.0015;
    if (playing) {
      acc += 1;
      if (acc >= (21 - +el("speed").value)) { acc = 0; reveal(shown + 1); if (shown >= meshes.length) { playing = false; el("play").textContent = "Play"; } }
    }
    renderer.render(scene, camera);
  }
  requestAnimationFrame(tick);

  window.addEventListener("resize", () => {
    renderer.setSize(container.clientWidth, container.clientHeight);
    camera.aspect = container.clientWidth / container.clientHeight;
    camera.updateProjectionMatrix();
  });

  // --- sandbox builder ---
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
    w.placeholder = "W"; l.placeholder = "L"; d.placeholder = "D"; mw.placeholder = "max wt (g)";
    preset.onchange = () => {
      const p = PRESETS[preset.value];
      if (p) { w.value = p.width; l.value = p.length; d.value = p.depth; mw.value = MAX_WEIGHT_G; if (!ref.value) ref.value = preset.value; }
    };
    [preset, ref, w, l, d, mw, rmButton(row)].forEach((n) => row.appendChild(n));
    el("boxes").appendChild(row);
    if (data.preset) preset.value = data.preset;
  }

  function itemRow(data = {}) {
    const row = document.createElement("div");
    row.className = "row item-row";
    const desc = mkInput("text", "description", data.description || ""); desc.placeholder = "description";
    const w = mkInput("number", "width", data.width || ""); w.placeholder = "W";
    const l = mkInput("number", "length", data.length || ""); l.placeholder = "L";
    const d = mkInput("number", "depth", data.depth || ""); d.placeholder = "D";
    const wt = mkInput("number", "weight", data.weight || ""); wt.placeholder = "wt (g)";
    const qty = mkInput("number", "quantity", data.quantity || 1); qty.placeholder = "qty";
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

  function validate(spec) {
    if (!spec.boxes.length) return "Add at least one box.";
    if (!spec.items.length) return "Add at least one item.";
    for (const b of spec.boxes) {
      const name = b.reference || "?";
      for (const k of ["width", "length", "depth"]) if (!(b[k] > 0)) return `Box "${name}": ${k} must be a positive number.`;
      const longest = Math.max(b.width, b.length, b.depth);
      if (longest > MAX_LEN_MM) return `Box "${name}" exceeds Australia Post limit: longest side ${longest} mm > ${MAX_LEN_MM} mm.`;
      const vol = b.width * b.length * b.depth;
      if (vol > MAX_VOL_MM3) return `Box "${name}" exceeds Australia Post limit: volume ${vol} mm³ > ${MAX_VOL_MM3} mm³.`;
      const mw = b.max_weight || MAX_WEIGHT_G;
      if (mw > MAX_WEIGHT_G) return `Box "${name}" exceeds Australia Post limit: max weight ${mw} g > ${MAX_WEIGHT_G} g.`;
    }
    for (const it of spec.items) {
      const name = it.description || "?";
      for (const k of ["width", "length", "depth", "weight"]) if (!(it[k] > 0)) return `Item "${name}": ${k} must be a positive number.`;
    }
    return null;
  }

  function showErr(msg) {
    const e = el("builder-error");
    e.textContent = "⚠ " + msg;
    e.hidden = false;
  }

  async function pack(ev) {
    ev.preventDefault();
    const spec = collectSpec();
    const clientErr = validate(spec);
    if (clientErr) return showErr(clientErr);
    el("builder-error").hidden = true;
    try {
      const res = await fetch(`${base}/api/pack`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(spec),
      });
      const data = await res.json();
      if (!res.ok || !data.ok) return showErr(data.error || `pack failed (${res.status})`);
      await loadList();
      await selectPacking(data.id, document.querySelector("#packings li"));
    } catch (e) {
      showErr(String(e));
    }
  }

  function loadExample() {
    el("boxes").innerHTML = "";
    el("items").innerHTML = "";
    boxRow({ preset: "AusPost Medium", reference: "AusPost Medium", ...PRESETS["AusPost Medium"], max_weight: MAX_WEIGHT_G });
    [
      { description: "book", width: 210, length: 140, depth: 20, weight: 300, quantity: 6, rotation: "best_fit" },
      { description: "mug", width: 100, length: 80, depth: 100, weight: 400, quantity: 4, rotation: "best_fit" },
      { description: "cable", width: 60, length: 40, depth: 30, weight: 80, quantity: 8, rotation: "best_fit" },
    ].forEach(itemRow);
  }

  el("new-toggle").onclick = () => {
    const f = el("builder");
    f.hidden = !f.hidden;
    if (!f.hidden && !el("boxes").children.length) { boxRow(); itemRow(); }
  };
  el("add-box").onclick = () => boxRow();
  el("add-item").onclick = () => itemRow();
  el("load-example").onclick = loadExample;
  el("builder").addEventListener("submit", pack);

  // --- live updates ---
  loadList();
  const es = new EventSource(`${base}/api/stream`);
  es.onmessage = () => loadList();
})();
