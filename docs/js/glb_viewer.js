export async function loadGLBViewer(containerId, glbPath, { mode = "textured" } = {}) {
  const THREE = await import('https://unpkg.com/three@0.165.0/build/three.module.js');
  const { OrbitControls } = await import('https://unpkg.com/three@0.165.0/examples/jsm/controls/OrbitControls.js?module');
  const { GLTFLoader } = await import('https://unpkg.com/three@0.165.0/examples/jsm/loaders/GLTFLoader.js?module');

  const container = document.getElementById(containerId);
  if (!container) {
    console.error(`Container with ID '${containerId}' not found.`);
    return;
  }

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0xf0f0f0);

  const camera = new THREE.PerspectiveCamera(75, container.clientWidth / container.clientHeight, 0.1, 1000);
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setSize(container.clientWidth, container.clientHeight);
  container.appendChild(renderer.domElement);

  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.05;

  scene.add(new THREE.AmbientLight(0x999999));
  const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
  directionalLight.position.set(5, 10, 5);
  scene.add(directionalLight);

  const loader = new GLTFLoader();

  loader.load(glbPath, (gltf) => {
    const model = gltf.scene;

    model.traverse((child) => {
      if (child.isMesh) {
        if (mode === "wireframe") {
          child.material = new THREE.MeshBasicMaterial({
            color: 0x000000,
            wireframe: true
          });
        } else if (mode === "shaded") {
          child.material = new THREE.MeshStandardMaterial({
            color: 0x999999,
            metalness: 0.3,
            roughness: 0.7
          });
        }
        // else: default textured appearance
      }
    });

    scene.add(model);

    // Center model
    const box = new THREE.Box3().setFromObject(model);
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const radius = size.length() * 0.5;

    model.position.sub(center); // center the object

    camera.position.set(radius * 1.5, radius * 1.5, radius * 1.5);
    controls.target.set(0, 0, 0);
    controls.update();
  }, undefined, (err) => {
    console.error(`Failed to load GLB file: ${err.message}`);
  });

  function animate() {
    requestAnimationFrame(animate);
    controls.update();
    renderer.render(scene, camera);
  }

  animate();

  window.addEventListener("resize", () => {
    camera.aspect = container.clientWidth / container.clientHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(container.clientWidth, container.clientHeight);
  });
}
