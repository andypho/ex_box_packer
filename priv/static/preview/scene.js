// The 3D viewer widget: owns the Three.js canvas, its control bar (play/step/scrub/speed/
// box-select/stats/zoom), the orbit+zoom camera, and the placement-order reveal animation.
// Uses the global `THREE` provided by the vendored three.min.js (a classic script).
//
// Coordinate mapping — Three.js: X=width, Y=depth(up), Z=length. Packing: x=width, y=length, z=depth(up).

const el = (id) => document.getElementById(id);

// Stable colour per item description.
const palette = {};
const colorFor = (desc) =>
  (palette[desc] =
    palette[desc] ||
    new THREE.Color().setHSL((Object.keys(palette).length * 0.13) % 1, 0.55, 0.55));

export function createViewer() {
  const container = el("scene");

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0xf7f7fa);
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setSize(container.clientWidth, container.clientHeight);
  container.appendChild(renderer.domElement);
  const camera = new THREE.PerspectiveCamera(
    55,
    container.clientWidth / container.clientHeight,
    1,
    100000,
  );
  scene.add(new THREE.AmbientLight(0xffffff, 0.7));
  const dir = new THREE.DirectionalLight(0xffffff, 0.6);
  dir.position.set(1, 2, 1.5);
  scene.add(dir);

  // --- orbit/zoom camera (static by default; drag to rotate, wheel/buttons to zoom) ---
  const target = new THREE.Vector3();
  const MIN_PHI = 0.05,
    MAX_PHI = Math.PI - 0.05;
  let theta = Math.PI / 4,
    phi = Math.PI / 3.2,
    radius = 100,
    minRadius = 1,
    maxRadius = 1e6;

  function updateCamera() {
    const s = radius * Math.sin(phi);
    camera.position.set(
      target.x + s * Math.sin(theta),
      target.y + radius * Math.cos(phi),
      target.z + s * Math.cos(theta),
    );
    camera.lookAt(target);
  }

  function zoom(factor) {
    radius = Math.min(maxRadius, Math.max(minRadius, radius * factor));
    updateCamera();
  }

  function frameCamera(iw, il, id) {
    const diag = Math.hypot(iw, il, id);
    target.set(iw / 2, id / 2, il / 2);
    radius = diag * 1.4;
    minRadius = diag * 0.35;
    maxRadius = diag * 5;
    theta = Math.PI / 4;
    phi = Math.PI / 3.2;
    updateCamera();
  }

  // --- scene contents + reveal state ---
  let group = new THREE.Group();
  scene.add(group);
  let meshes = []; // item cuboids in placement order
  let shown = 0,
    playing = false;

  function clear() {
    scene.remove(group);
    group = new THREE.Group();
    scene.add(group);
    meshes = [];
    shown = 0;
  }

  function addBox(iw, il, id) {
    const geo = new THREE.BoxGeometry(iw, id, il);
    const edges = new THREE.LineSegments(
      new THREE.EdgesGeometry(geo),
      new THREE.LineBasicMaterial({ color: 0x333333 }),
    );
    edges.position.set(iw / 2, id / 2, il / 2);
    group.add(edges);
    frameCamera(iw, il, id);
  }

  function addItem([desc, x, y, z, w, l, d]) {
    const mat = new THREE.MeshLambertMaterial({
      color: colorFor(desc),
      transparent: true,
      opacity: 0.9,
    });
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, d, l), mat);
    mesh.position.set(x + w / 2, z + d / 2, y + l / 2);
    mesh.visible = false;
    group.add(mesh);
    meshes.push(mesh);
  }

  function reveal(n) {
    shown = Math.max(0, Math.min(n, meshes.length));
    meshes.forEach((m, i) => (m.visible = i < shown));
    el("scrub").value = shown;
  }

  function loadBox(payload, idx) {
    clear();
    const [ref, iw, il, id, placed] = payload.boxes[idx];
    const items = payload.items;
    addBox(iw, il, id);
    placed.forEach(([itemIdx, x, y, z, w, l, d]) => addItem([items[itemIdx][0], x, y, z, w, l, d]));
    el("scrub").max = meshes.length;
    reveal(meshes.length); // start fully packed; user can scrub back
    el("stats").textContent = `${ref}: ${placed.length} items`;
  }

  // --- control bar wiring ---
  el("play").onclick = () => {
    playing = !playing;
    el("play").textContent = playing ? "Pause" : "Play";
    if (playing && shown >= meshes.length) reveal(0);
  };
  el("step").onclick = () => reveal(shown + 1);
  el("scrub").oninput = (e) => reveal(+e.target.value);

  // drag to rotate, wheel or +/- buttons to zoom
  const canvas = renderer.domElement;
  canvas.style.cursor = "grab";
  let dragging = false,
    lastX = 0,
    lastY = 0;
  canvas.addEventListener("pointerdown", (e) => {
    dragging = true;
    lastX = e.clientX;
    lastY = e.clientY;
    canvas.setPointerCapture(e.pointerId);
    canvas.style.cursor = "grabbing";
  });
  canvas.addEventListener("pointermove", (e) => {
    if (!dragging) return;
    theta -= (e.clientX - lastX) * 0.01;
    phi = Math.min(MAX_PHI, Math.max(MIN_PHI, phi - (e.clientY - lastY) * 0.01));
    lastX = e.clientX;
    lastY = e.clientY;
    updateCamera();
  });
  canvas.addEventListener("pointerup", (e) => {
    dragging = false;
    canvas.style.cursor = "grab";
    if (canvas.hasPointerCapture(e.pointerId)) canvas.releasePointerCapture(e.pointerId);
  });
  canvas.addEventListener("pointercancel", () => {
    dragging = false;
    canvas.style.cursor = "grab";
  });
  canvas.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      zoom(e.deltaY > 0 ? 1.1 : 0.9);
    },
    { passive: false },
  );
  el("zoom-in").onclick = () => zoom(0.85);
  el("zoom-out").onclick = () => zoom(1.15);

  window.addEventListener("resize", () => {
    renderer.setSize(container.clientWidth, container.clientHeight);
    camera.aspect = container.clientWidth / container.clientHeight;
    camera.updateProjectionMatrix();
  });

  // --- render loop (advances the reveal while playing) ---
  let acc = 0;
  function tick() {
    requestAnimationFrame(tick);
    if (playing) {
      acc += 1;
      if (acc >= 21 - +el("speed").value) {
        acc = 0;
        reveal(shown + 1);
        if (shown >= meshes.length) {
          playing = false;
          el("play").textContent = "Play";
        }
      }
    }
    renderer.render(scene, camera);
  }
  requestAnimationFrame(tick);

  // Show a packing payload: populate the box selector and render the first box.
  function showPayload(payload) {
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

  return { showPayload };
}
