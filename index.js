// Constants
const CANVAS_HEIGHT = 768;
const CANVAS_WIDTH = 768;
// const RENDER_SCALE = 2;
const RENDER_WIDTH = 1024;
const RENDER_HEIGHT = 1024;
const FRAME_RATE = 24;
const FRAME_DURATION = 1000 / FRAME_RATE;

// WebGL variables
let gl;
let texture;
let wasm;

let mouseX = 0;
let mouseY = 0;

// Shader sources
const vertexShaderSource = `
  attribute vec4 a_position;
  attribute vec2 a_texCoord;
  varying vec2 v_texCoord;
  void main() {
    gl_Position = a_position;
    v_texCoord = a_texCoord;
  }
`;

const fragmentShaderSource = `
  precision mediump float;
  varying vec2 v_texCoord;
  uniform sampler2D u_texture;
  void main() {
    gl_FragColor = texture2D(u_texture, v_texCoord);
  }
`;

// Helper functions
function createCanvas(parentDivId, canvasWidth, canvasHeight) {
  const parentDiv = document.getElementById(parentDivId);
  const canvas = document.createElement('canvas');
  canvas.width = canvasWidth;
  canvas.height = canvasHeight;
  parentDiv.appendChild(canvas);
  return canvas;
}

function createShader(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.error(gl.getShaderInfoLog(shader));
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

function createProgram(gl, vertexShader, fragmentShader) {
  const program = gl.createProgram();
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error(gl.getProgramInfoLog(program));
    gl.deleteProgram(program);
    return null;
  }
  return program;
}

async function loadZigWasmModule() {
  const response = await fetch('/zig-out/bin/zigl.wasm');
  const bytes = await response.arrayBuffer();
  const { instance } = await WebAssembly.instantiate(bytes, {
    env: {
      js_console_log: (ptr, len) => {
        const buf = new Uint8Array(wasm.exports.memory.buffer, ptr, len);
        const message = new TextDecoder().decode(buf);
        console.log('ZIG: ', message);
      }
    }
  });
  return instance;
}

// Main application logic
function initWebGL() {
  const canvas = createCanvas('root', CANVAS_WIDTH, CANVAS_HEIGHT);
  gl = canvas.getContext('webgl');
  if (!gl) {
    console.error('WebGL not supported');
    return false;
  }
  texture = gl.createTexture();

  canvas.addEventListener('mousemove', (event) => {
    const rect = canvas.getBoundingClientRect();
    mouseX = 2 * ((event.clientX - rect.left) / CANVAS_WIDTH - 0.5);
    mouseY = -2 * (1 - (event.clientY - rect.top) / CANVAS_HEIGHT - 0.5); // Invert Y-axis
  });

  return true;
}

function setupShaders() {
  const vertexShader = createShader(gl, gl.VERTEX_SHADER, vertexShaderSource);
  const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, fragmentShaderSource);
  return createProgram(gl, vertexShader, fragmentShader);
}

function setupBuffers() {
  const positionBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
  const positions = new Float32Array([
    -1, -1, 1, -1, -1, 1,
    -1, 1, 1, -1, 1, 1,
  ]);
  gl.bufferData(gl.ARRAY_BUFFER, positions, gl.STATIC_DRAW);

  const texCoordBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, texCoordBuffer);
  const texCoords = new Float32Array([
    0, 0, 1, 0, 0, 1,
    0, 1, 1, 0, 1, 1,
  ]);
  gl.bufferData(gl.ARRAY_BUFFER, texCoords, gl.STATIC_DRAW);

  return { positionBuffer, texCoordBuffer };
}

function setupTexture() {
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, RENDER_WIDTH, RENDER_HEIGHT, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
}

function setupAttributes(program, buffers) {
  const positionLocation = gl.getAttribLocation(program, 'a_position');
  gl.enableVertexAttribArray(positionLocation);
  gl.bindBuffer(gl.ARRAY_BUFFER, buffers.positionBuffer);
  gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

  const texCoordLocation = gl.getAttribLocation(program, 'a_texCoord');
  gl.enableVertexAttribArray(texCoordLocation);
  gl.bindBuffer(gl.ARRAY_BUFFER, buffers.texCoordBuffer);
  gl.vertexAttribPointer(texCoordLocation, 2, gl.FLOAT, false, 0, 0);

  const textureLocation = gl.getUniformLocation(program, 'u_texture');
  gl.uniform1i(textureLocation, 0);
}

let lastFrameTime = 0;

function animate(currentTime) {
  requestAnimationFrame(animate);

  // Calculate time since last frame
  const deltaTime = currentTime - lastFrameTime;

  // If not enough time has passed, skip this frame
  if (deltaTime < FRAME_DURATION) {
    return;
  }

  // Update lastFrameTime for the next frame
  lastFrameTime = currentTime - (deltaTime % FRAME_DURATION);

  try {
    const data = wasm.exports.go(mouseX, mouseY);
    const pixels = new Uint8Array(
      wasm.exports.memory.buffer,
      data, 
      RENDER_WIDTH * RENDER_HEIGHT * 4
    );

    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, RENDER_WIDTH, RENDER_HEIGHT, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  } catch (e) {
    console.warn(e);
  }
}

function addMouseListeners() {
  window.addEventListener()  
}

function main() {
  if (!initWebGL()) return;

  const program = setupShaders();
  const buffers = setupBuffers();
  setupTexture();
  setupAttributes(program, buffers);

  gl.useProgram(program);
  wasm.exports.init(RENDER_WIDTH, RENDER_HEIGHT);

  // Initialize lastFrameTime before starting the animation
  lastFrameTime = performance.now();
  requestAnimationFrame(animate);
}

// Initialize the application
loadZigWasmModule().then((wasmModule) => {
  wasm = wasmModule;
  main();
});
