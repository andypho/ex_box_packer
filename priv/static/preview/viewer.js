// ex_box_packer packing viewer — Three.js 0.160.0 (vendored)
(function () {
  const base = location.pathname.replace(/\/$/, "");
  const el = (id) => document.getElementById(id);
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

  // --- live updates ---
  loadList();
  const es = new EventSource(`${base}/api/stream`);
  es.onmessage = () => loadList();
})();
