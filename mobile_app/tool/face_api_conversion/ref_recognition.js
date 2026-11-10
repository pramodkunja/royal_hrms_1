// Reference: the real face-api.js 0.22.2 FaceRecognitionNet (pinned tfjs-core 1.7.0, CPU backend),
// loaded from the web app's own weight files.
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2];                       // dir holding node_modules/face-api.js
const tf = require(path.join(ROOT, 'node_modules/@tensorflow/tfjs-core'));
const faceapi = require(path.join(ROOT, 'node_modules/face-api.js'));
const [modelDir, inputFile, n, outFile] = process.argv.slice(3);
(async () => {
  await tf.setBackend('cpu');
  const manifest = JSON.parse(fs.readFileSync(path.join(modelDir, 'face_recognition_model-weights_manifest.json')));
  const specs = [], bufs = [];
  for (const g of manifest) { specs.push(...g.weights); for (const p of g.paths) bufs.push(fs.readFileSync(path.join(modelDir, p))); }
  const all = Buffer.concat(bufs);
  const weightMap = tf.io.decodeWeights(all.buffer.slice(all.byteOffset, all.byteOffset + all.length), specs);
  const net = faceapi.nets.faceRecognitionNet;
  net.loadFromWeightMap(weightMap);
  const raw = fs.readFileSync(inputFile);
  const data = new Float32Array(raw.buffer, raw.byteOffset, raw.length / 4);
  const out = [];
  for (let i = 0; i < Number(n); i++) {
    const t = tf.tensor3d(data.subarray(i * 150 * 150 * 3, (i + 1) * 150 * 150 * 3), [150, 150, 3]);
    const d = await net.computeFaceDescriptor(t);      // the public API web calls
    out.push(Array.from(d));
    t.dispose();
  }
  fs.writeFileSync(outFile, JSON.stringify({ tfjs: tf.version_core, backend: tf.getBackend(), descriptors: out }));
  console.log('ok', out.length, 'x', out[0].length, 'tfjs', tf.version_core, tf.getBackend());
})().catch(e => { console.error(e); process.exit(1); });
