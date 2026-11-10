// Expected outputs from the REAL web code (frontend/lib/faceApi/*.ts, imported unchanged)
// and the REAL face-api.js 0.22.2 (its own decode/NMS, landmark post-processing, dlib
// alignment, box clipping). Network outputs are stubbed with deterministic random values;
// the networks themselves are validated separately (TFLite vs face-api.js).
import { createRequire } from 'module';
import fs from 'fs';
const [ROOT, WEB, OUT] = process.argv.slice(2);
const require = createRequire(import.meta.url);
const tf = require(ROOT + '/node_modules/@tensorflow/tfjs-core');
const faceapi = require(ROOT + '/node_modules/face-api.js');
const { applyClahe } = await import(WEB + '/lib/faceApi/clahe.ts');
const qg = await import(WEB + '/lib/faceApi/qualityGate.ts');
const fc = await import(WEB + '/lib/faceApi/frameCapture.ts');
await tf.setBackend('cpu');

let seed = 20261110;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const fx = { clahe: [], detect: [], landmarks: [], quality: [], combine: [] };

// 1. CLAHE
for (const [w, h, kind] of [[97, 61, 'noise'], [40, 33, 'gradient'], [64, 64, 'dark'], [33, 70, 'bright'], [1, 1, 'noise']]) {
  const data = new Uint8ClampedArray(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const p = (y * w + x) * 4;
    const v = kind === 'noise' ? rnd() * 255 : kind === 'gradient' ? (x * 255) / w : kind === 'dark' ? 10 + rnd() * 40 : 180 + rnd() * 75;
    data[p] = v; data[p + 1] = (v * 0.8 + rnd() * 30); data[p + 2] = (v * 0.6 + rnd() * 50); data[p + 3] = 255;
  }
  const input = Array.from(data);
  applyClahe({ data, width: w, height: h });
  fx.clahe.push({ width: w, height: h, input, output: Array.from(data) });
}

// 2. Detector decode + NMS through face-api's own locateFaces (network output stubbed)
const det = faceapi.nets.tinyFaceDetector;
det._params = {};                                    // never used: forwardInput is stubbed
for (const [w, h] of [[800, 600], [640, 480], [480, 640], [720, 720], [799, 533], [800, 450]]) {
  for (let k = 0; k < 3; k++) {
    const raw = Array.from({ length: 7 * 7 * 25 }, (_, i) => (i % 5 === 4 ? (rnd() * 8 - 7) : (rnd() * 4 - 2)));
    // plant a few confident, overlapping boxes so NMS has work to do
    for (let n = 0; n < 4; n++) { const cell = Math.floor(rnd() * 49), a = Math.floor(rnd() * 5); raw[cell * 25 + a * 5 + 4] = 1 + rnd() * 4; }
    det.forwardInput = (netInput, inputSize) => { netInput.toBatchTensor(inputSize, false); return tf.tensor4d(raw, [1, 7, 7, 25]); };
    const img = tf.zeros([h, w, 3]);
    const found = await det.locateFaces(img, new faceapi.TinyFaceDetectorOptions({ inputSize: 224, scoreThreshold: 0.5 }));
    img.dispose();
    fx.detect.push({ width: w, height: h, raw, faces: found.map(d => ({ score: d.score, box: [d.box.x, d.box.y, d.box.width, d.box.height],
      cropBox: (b => [b.x, b.y, b.width, b.height])(d.forSize(w, h).box.floor().clipAtImageBorders(w, h)) })) });
  }
}

// 3. Landmark post-processing → shifted 68 points → dlib box → clipped descriptor crop
const lmk = faceapi.nets.faceLandmark68Net;
for (let k = 0; k < 24; k++) {
  const frameW = 640 + Math.floor(rnd() * 160), frameH = 360 + Math.floor(rnd() * 240);
  const cropW = 40 + Math.floor(rnd() * 260), cropH = 40 + Math.floor(rnd() * 260);
  const shift = [rnd() * frameW * 0.8 - 20, rnd() * frameH * 0.8 - 20];   // unfloored detection origin (may be < 0)
  const raw = Array.from({ length: 136 }, () => rnd() * 1.1 - 0.05);
  const rel = await lmk.postProcess(tf.tensor2d(raw, [1, 136]), 112, [{ width: cropW, height: cropH }]).data();
  const pts = Array.from({ length: 68 }, (_, i) => new faceapi.Point(rel[2 * i], rel[2 * i + 1]));
  const marks = new faceapi.FaceLandmarks68(pts, { width: cropW, height: cropH }).shiftBy(shift[0], shift[1]);
  const rect = marks.align(null, { useDlibAlignment: true });
  const clipped = rect.clipAtImageBorders(frameW, frameH);
  fx.landmarks.push({ raw, cropW, cropH, shift, frameW, frameH,
    positions: marks.positions.map(p => [p.x, p.y]), dlib: [rect.x, rect.y, rect.width, rect.height],
    clipped: [clipped.x, clipped.y, clipped.width, clipped.height],
    frontality: qg.computeFrontality(marks.getLeftEye(), marks.getRightEye(), marks.getNose()[3]) });
}

// 4. Quality gate + eye occlusion (web qualityGate.ts / frameCapture.ts)
for (let k = 0; k < 30; k++) {
  const m = { detectionScore: rnd() * 0.4 + 0.6, faceWidthRatio: rnd() * 0.9, frontality: rnd(), meanLuminance: rnd() * 255 };
  fx.quality.push({ metrics: m, codes: qg.assessFrameQuality(m).codes });
}
for (const [w, h, dark] of [[60, 40, true], [60, 40, false]]) {
  const data = new Uint8ClampedArray(w * h * 4);
  for (let i = 0; i < data.length; i += 4) { const v = dark ? 20 + rnd() * 5 : rnd() * 255; data[i] = data[i + 1] = data[i + 2] = v; data[i + 3] = 255; }
  const le = [[5, 5], [15, 4], [20, 9], [6, 12]], re = [[35, 6], [50, 5], [52, 12], [36, 13]];
  const P = a => a.map(([x, y]) => ({ x, y }));
  fx.quality.push({ eyeImage: { width: w, height: h, data: Array.from(data) }, leftEye: le, rightEye: re,
    occluded: fc.assessEyeOcclusion({ data, width: w, height: h }, P(le), P(re)).suspected,
    meanLum: fc.meanLuminanceOfBox({ data, width: w, height: h }, { x: 3.4, y: 2.2, width: 30.5, height: 20.9 }) });
}

// 5. Combine frames
for (let k = 0; k < 6; k++) {
  const n = 2 + (k % 3), base = Array.from({ length: 128 }, () => rnd() * 0.2 - 0.1);
  const ds = Array.from({ length: n }, () => base.map(v => v + (rnd() - 0.5) * (k < 3 ? 0.02 : 0.08)));
  const c = qg.assessCaptureConsistency(ds, 0.35);
  fx.combine.push({ descriptors: ds, average: qg.averageDescriptors(ds), passed: c.passed, mean: c.meanPairwiseDistance, max: c.maxPairwiseDistance });
}
fs.writeFileSync(OUT, JSON.stringify(fx));
console.log('fixtures: clahe', fx.clahe.length, 'detect', fx.detect.length, 'faces', fx.detect.reduce((a, d) => a + d.faces.length, 0),
  'landmarks', fx.landmarks.length, 'quality', fx.quality.length, 'combine', fx.combine.length, 'passed-consistency', fx.combine.filter(c => c.passed).length);
