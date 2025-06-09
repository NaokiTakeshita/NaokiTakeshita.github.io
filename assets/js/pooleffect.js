/*
Most of the stuff in here is just bootstrapping. Essentially it's just
setting ThreeJS up so that it renders a flat surface upon which to draw 
the shader. The only thing to see here really is the uniforms sent to 
the shader. Apart from that all of the magic happens in the HTML view
under the fragment shader.
*/
// 🔧 これを .then の外側・上部に書く
let loader = new THREE.TextureLoader();

const isMobile = window.innerWidth < 768;

const imageSet = isMobile
  ? [
      "./assets/img/hero/myimg_sp1.webp",
      "./assets/img/hero/myimg_sp2.webp",
      "./assets/img/hero/myimg_sp3.webp",
    ]
  : [
      "./assets/img/hero/myimg5.webp",
      "./assets/img/hero/myimg7.webp",
      "./assets/img/hero/myimg8.webp",
    ];

async function loadShader(path) {
  const response = await fetch(path);
  if (!response.ok) {
    throw new Error(`Failed to load shader: ${path}`);
  }
  return await response.text();
}
Promise.all([
  loadShader("./assets/shaders/vertex.glsl"),
  loadShader("./assets/shaders/fragment.glsl"),
]).then(([vertexShaderCode, fragmentShaderCode]) => {
  loader.load("./assets/img/noise.webp", (tex) => {
    texture = tex;
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    texture.minFilter = THREE.LinearFilter;

    loader.load("./assets/img/noise.webp", function environment_load(tex) {
      environment = tex;
      //   environment.wrapS = THREE.RepeatWrapping;
      //   environment.wrapT = THREE.RepeatWrapping;
      environment.wrapS = THREE.MirroredRepeatWrapping;
      environment.wrapT = THREE.MirroredRepeatWrapping;
      environment.minFilter = THREE.NearestMipMapNearestFilter;

      //   loader.load("./tiling-mosaic.jpg", function image_load(tex) {
      loader.load(imageSet[0], function image_load(tex) {
        pooltex = tex;
        // pooltex.wrapS = THREE.RepeatWrapping;
        // pooltex.wrapT = THREE.RepeatWrapping;
        pooltex.wrapS = THREE.MirroredRepeatWrapping;
        pooltex.wrapT = THREE.MirroredRepeatWrapping;
        // pooltex.wrapS = THREE.ClampToEdgeWrapping;
        // pooltex.wrapT = THREE.ClampToEdgeWrapping;

        pooltex.minFilter = THREE.LinearFilter;
        pooltex.generateMipmaps = false;

        loader.load(imageSet[1], function image_load(tex) {
          pooltex2 = tex;
          // pooltex.wrapS = THREE.RepeatWrapping;
          // pooltex.wrapT = THREE.RepeatWrapping;
          pooltex2.wrapS = THREE.MirroredRepeatWrapping;
          pooltex2.wrapT = THREE.MirroredRepeatWrapping;
          // pooltex.wrapS = THREE.ClampToEdgeWrapping;
          // pooltex.wrapT = THREE.ClampToEdgeWrapping;

          pooltex2.minFilter = THREE.LinearFilter;
          pooltex2.generateMipmaps = false;

          loader.load(imageSet[2], function image_load(tex) {
            pooltex3 = tex;
            // pooltex.wrapS = THREE.RepeatWrapping;
            // pooltex.wrapT = THREE.RepeatWrapping;
            pooltex3.wrapS = THREE.MirroredRepeatWrapping;
            pooltex3.wrapT = THREE.MirroredRepeatWrapping;
            // pooltex.wrapS = THREE.ClampToEdgeWrapping;
            // pooltex.wrapT = THREE.ClampToEdgeWrapping;

            pooltex3.minFilter = THREE.LinearFilter;
            pooltex3.generateMipmaps = false;

            // 👇 シェーダーを渡して初期化
            console.log("texture set");
            startAnimation();
            init(vertexShaderCode, fragmentShaderCode);
            animate();
          });
        });
      });
    });
  });
});

let container;
let camera, scene, renderer;
let uniforms;

let divisor = 1 / 8;
let textureFraction = 1 / 1;

let newmouse = {
  x: 0,
  y: 0,
};

function init(vertexShaderCode, fragmentShaderCode) {
  container = document.getElementById("container");

  camera = new THREE.Camera();
  camera.position.z = 1;

  scene = new THREE.Scene();

  const geometry = new THREE.PlaneBufferGeometry(2, 2);

  rtTexture = new THREE.WebGLRenderTarget(
    Math.floor(window.innerWidth * textureFraction),
    Math.floor(window.innerHeight * textureFraction),
    { type: THREE.FloatType, minFilter: THREE.NearestMipMapNearestFilter }
  );
  rtTexture2 = new THREE.WebGLRenderTarget(
    Math.floor(window.innerWidth * textureFraction),
    Math.floor(window.innerHeight * textureFraction),
    { type: THREE.FloatType, minFilter: THREE.NearestMipMapNearestFilter }
  );

  uniforms = {
    u_time: { type: "f", value: 1.0 },
    u_resolution: { type: "v2", value: new THREE.Vector2() },
    u_noise: { type: "t", value: texture },
    u_buffer: { type: "t", value: rtTexture.texture },
    u_texture: { type: "t", value: pooltex },
    u_texture2: { type: "t", value: pooltex2 },
    u_texture3: { type: "t", value: pooltex3 },
    u_environment: { type: "t", value: environment },
    u_mouse: { type: "v3", value: new THREE.Vector3() },
    u_frame: { type: "i", value: -1 },
    u_renderpass: { type: "b", value: false },
    u_texture_width: { type: "f", value: pooltex.image.width },
    u_texture_height: { type: "f", value: pooltex.image.height },
    u_stage: { type: "f", value: 0.0 },
    u_wave_timing: { type: "f", value: 0.0 },
  };
  console.log(uniforms);

  const material = new THREE.ShaderMaterial({
    uniforms: uniforms,
    vertexShader: vertexShaderCode,
    fragmentShader: fragmentShaderCode,
  });
  material.extensions.derivatives = true;

  const mesh = new THREE.Mesh(geometry, material);
  scene.add(mesh);

  renderer = new THREE.WebGLRenderer({ alpha: true });
  container.appendChild(renderer.domElement);

  onWindowResize();
  window.addEventListener("resize", onWindowResize, false);

  document.addEventListener("pointermove", (e) => {
    let ratio = window.innerHeight / window.innerWidth;
    if (window.innerHeight > window.innerWidth) {
      newmouse.x = (e.pageX - window.innerWidth / 2) / window.innerWidth;
      newmouse.y =
        ((e.pageY - window.innerHeight / 2) / window.innerHeight) * -1 * ratio;
    } else {
      newmouse.x =
        (e.pageX - window.innerWidth / 2) / window.innerWidth / ratio;
      newmouse.y =
        ((e.pageY - window.innerHeight / 2) / window.innerHeight) * -1;
    }

    e.preventDefault();
  });
  document.addEventListener("pointerdown", () => {
    uniforms.u_mouse.value.z = 1;
  });
  document.addEventListener("pointerup", () => {
    uniforms.u_mouse.value.z = 0;
  });
}

// function init() {
//   container = document.getElementById("container");

//   camera = new THREE.Camera();
//   camera.position.z = 1;

//   scene = new THREE.Scene();

//   var geometry = new THREE.PlaneBufferGeometry(2, 2);

//   rtTexture = new THREE.WebGLRenderTarget(
//     Math.floor(window.innerWidth * textureFraction),
//     Math.floor(window.innerHeight * textureFraction),
//     { type: THREE.FloatType, minFilter: THREE.NearestMipMapNearestFilter }
//   );
//   rtTexture2 = new THREE.WebGLRenderTarget(
//     Math.floor(window.innerWidth * textureFraction),
//     Math.floor(window.innerHeight * textureFraction),
//     { type: THREE.FloatType, minFilter: THREE.NearestMipMapNearestFilter }
//   );

//   uniforms = {
//     u_time: { type: "f", value: 1.0 },
//     u_resolution: { type: "v2", value: new THREE.Vector2() },
//     u_noise: { type: "t", value: texture },
//     u_buffer: { type: "t", value: rtTexture.texture },
//     u_texture: { type: "t", value: pooltex },
//     u_environment: { type: "t", value: environment },
//     u_mouse: { type: "v3", value: new THREE.Vector3() },
//     u_frame: { type: "i", value: -1 },
//     u_renderpass: { type: "b", value: false },
//   };

//   var material = new THREE.ShaderMaterial({
//     uniforms: uniforms,
//     vertexShader: document.getElementById("vertexShader").textContent,
//     fragmentShader: document.getElementById("fragmentShader").textContent,
//   });
//   material.extensions.derivatives = true;

//   var mesh = new THREE.Mesh(geometry, material);
//   scene.add(mesh);

//   renderer = new THREE.WebGLRenderer();
//   // renderer.setPixelRatio( window.devicePixelRatio );

//   container.appendChild(renderer.domElement);

//   onWindowResize();
//   window.addEventListener("resize", onWindowResize, false);

//   document.addEventListener("pointermove", (e) => {
//     let ratio = window.innerHeight / window.innerWidth;
//     if (window.innerHeight > window.innerWidth) {
//       newmouse.x = (e.pageX - window.innerWidth / 2) / window.innerWidth;
//       newmouse.y =
//         ((e.pageY - window.innerHeight / 2) / window.innerHeight) * -1 * ratio;
//     } else {
//       newmouse.x =
//         (e.pageX - window.innerWidth / 2) / window.innerWidth / ratio;
//       newmouse.y =
//         ((e.pageY - window.innerHeight / 2) / window.innerHeight) * -1;
//     }

//     e.preventDefault();
//   });
//   document.addEventListener("pointerdown", () => {
//     uniforms.u_mouse.value.z = 1;
//   });
//   document.addEventListener("pointerup", () => {
//     uniforms.u_mouse.value.z = 0;
//   });
// }

function onWindowResize(event) {
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(window.devicePixelRatio);
  uniforms.u_resolution.value.x = renderer.domElement.width;
  uniforms.u_resolution.value.y = renderer.domElement.height;

  // console.log(
  //   `window ${uniforms.u_resolution.value.x},${uniforms.u_resolution.value.y}`
  // );

  rtTexture = new THREE.WebGLRenderTarget(
    window.innerWidth * textureFraction,
    window.innerHeight * textureFraction
  );
  rtTexture2 = new THREE.WebGLRenderTarget(
    window.innerWidth * textureFraction,
    window.innerHeight * textureFraction
  );

  uniforms.u_frame.value = -1;

  // 🔽 テクスチャ画像を再ロード（768px未満と以上で切替）
  const isMobile = window.innerWidth < 768;
  const imageSet = isMobile
    ? [
        "./assets/img/hero/myimg_sp1.webp",
        "./assets/img/hero/myimg_sp2.webp",
        "./assets/img/hero/myimg_sp3.webp",
      ]
    : [
        "./assets/img/hero/myimg5.webp",
        "./assets/img/hero/myimg7.webp",
        "./assets/img/hero/myimg8.webp",
      ];

  console.log("reload texture");
  const loader = new THREE.TextureLoader();
  loader.load(imageSet[0], (tex1) => {
    pooltex = tex1;
    pooltex.wrapS = THREE.MirroredRepeatWrapping;
    pooltex.wrapT = THREE.MirroredRepeatWrapping;
    pooltex.minFilter = THREE.LinearFilter;
    pooltex.generateMipmaps = false;
    uniforms.u_texture.value = pooltex;

    loader.load(imageSet[1], (tex2) => {
      pooltex2 = tex2;
      pooltex2.wrapS = THREE.MirroredRepeatWrapping;
      pooltex2.wrapT = THREE.MirroredRepeatWrapping;
      pooltex2.minFilter = THREE.LinearFilter;
      pooltex2.generateMipmaps = false;
      uniforms.u_texture2.value = pooltex2;

      loader.load(imageSet[2], (tex3) => {
        pooltex3 = tex3;
        pooltex3.wrapS = THREE.MirroredRepeatWrapping;
        pooltex3.wrapT = THREE.MirroredRepeatWrapping;
        pooltex3.minFilter = THREE.LinearFilter;
        pooltex3.generateMipmaps = false;
        uniforms.u_texture3.value = pooltex3;

        // このタイミングで image.width/height が取得可能
        uniforms.u_texture.value = pooltex;
        uniforms.u_texture_width.value = pooltex.image.width;
        uniforms.u_texture_height.value = pooltex.image.height;

        // 更新が完了
      });
    });
  });
}

function animate(delta) {
  requestAnimationFrame(animate);
  render(delta);
}

let then = 0;
function renderTexture(delta) {
  // let ov = uniforms.u_buff.value;

  let odims = uniforms.u_resolution.value.clone();
  uniforms.u_resolution.value.x = window.innerWidth * textureFraction;
  uniforms.u_resolution.value.y = window.innerHeight * textureFraction;

  uniforms.u_buffer.value = rtTexture2.texture;

  uniforms.u_renderpass.value = true;

  //   rtTexture = rtTexture2;
  //   rtTexture2 = buffer;

  window.rtTexture = rtTexture;
  renderer.setRenderTarget(rtTexture);
  renderer.render(scene, camera, rtTexture, true);

  let buffer = rtTexture;
  rtTexture = rtTexture2;
  rtTexture2 = buffer;

  // uniforms.u_buff.value = ov;

  uniforms.u_buffer.value = rtTexture.texture;
  uniforms.u_resolution.value = odims;
  uniforms.u_renderpass.value = false;
}
let beta = Math.random() * -1000;
beta = 0;
console.log(beta);

function render(delta) {
  uniforms.u_frame.value++;

  uniforms.u_mouse.value.x += (newmouse.x - uniforms.u_mouse.value.x) * divisor;
  uniforms.u_mouse.value.y += (newmouse.y - uniforms.u_mouse.value.y) * divisor;

  uniforms.u_time.value = beta + delta * 0.0005;
  renderer.render(scene, camera);
  //   console.log(`time ${uniforms.u_time.value}`);
  renderTexture();
}
