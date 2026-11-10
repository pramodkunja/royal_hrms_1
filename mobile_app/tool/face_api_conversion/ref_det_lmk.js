const fs = require('fs'), path = require('path');
const ROOT = process.argv[2];
const tf = require(path.join(ROOT, 'node_modules/@tensorflow/tfjs-core'));
const faceapi = require(path.join(ROOT, 'node_modules/face-api.js'));
const modelDir = process.argv[3], work = process.argv[4];
function weightMap(prefix) {
  const m = JSON.parse(fs.readFileSync(path.join(modelDir, prefix + '-weights_manifest.json')));
  const specs = [], bufs = [];
  for (const g of m) { specs.push(...g.weights); for (const p of g.paths) bufs.push(fs.readFileSync(path.join(modelDir, p))); }
  const all = Buffer.concat(bufs);
  return tf.io.decodeWeights(all.buffer.slice(all.byteOffset, all.byteOffset + all.length), specs);
}
function load(file, n, s) { const r = fs.readFileSync(path.join(work, file)); const d = new Float32Array(r.buffer, r.byteOffset, r.length / 4);
  return Array.from({ length: n }, (_, i) => tf.tensor3d(d.subarray(i * s * s * 3, (i + 1) * s * s * 3), [s, s, 3])); }
(async () => {
  await tf.setBackend('cpu');
  const det = faceapi.nets.tinyFaceDetector; det.loadFromWeightMap(weightMap('tiny_face_detector_model'));
  const lmk = faceapi.nets.faceLandmark68Net; lmk.loadFromWeightMap(weightMap('face_landmark_68_model'));
  const detOut = [], lmkOut = [];
  for (const t of load('in_224.f32', 12, 224)) {
    const ni = await faceapi.toNetInput(t);
    const o = det.forwardInput(ni, 224);              // raw [1,7,7,25]
    detOut.push(Array.from(await o.data())); o.dispose();
  }
  for (const t of load('in_112.f32', 12, 112)) {
    const ni = await faceapi.toNetInput(t); ni.toBatchTensor(112, true);  // sets inputSize like forwardInput does
    const o = lmk.runNet(ni);                          // raw fc output [1,136] (before postProcess)
    lmkOut.push(Array.from(await o.data())); o.dispose();
  }
  fs.writeFileSync(path.join(work, 'ref_det_lmk.json'), JSON.stringify({ det: detOut, lmk: lmkOut }));
  console.log('ok det', detOut.length, detOut[0].length, 'lmk', lmkOut.length, lmkOut[0].length);
})().catch(e => { console.error(e); process.exit(1); });
