# face-api.js → TFLite (mobile face descriptors compatible with web)

The mobile app computes face descriptors with the **same three networks the web
app uses** (`face-api.js` **0.22.2**, weights in
`web_frontend_backend/frontend/public/models`, pinned to face-api.js commit
`a86f011d72124e5fb93e59d5c4ab98f699dd5c9c`), converted op-for-op to TFLite.
The backend is unchanged: it still receives a 128-value `face_embedding` in the
`face-api.js-faceRecognitionNet-v1` space.

| Asset (`assets/face_api/`) | Source model | Params | Input → output |
|---|---|---|---|
| `tiny_face_detector.tflite` | `tiny_face_detector_model` | 193,321 | 224×224×3 RGB 0..255 → 7×7×25 |
| `face_landmark_68.tflite` | `face_landmark_68_model` | 356,840 | 112×112×3 → 136 |
| `face_recognition.tflite` | `face_recognition_model` | 5,614,592 | 150×150×3 → 128 |

Each model subtracts face-api.js's mean RGB and divides (256, or 255 for
landmarks) inside the graph, so the app feeds raw RGB squares. Weights are the
web files' uint8 values dequantized exactly as tfjs does (`q × scale + min`);
float32 throughout (a float16 variant halves the recognition model to 11.3 MB
but moves descriptors up to ~1e-3 — not used).

## Reproduce

```sh
python3 -m venv tfenv && tfenv/bin/pip install "tensorflow==2.15.1" "numpy<2"
npm i face-api.js@0.22.2                      # pulls @tensorflow/tfjs-core 1.7.0
MODELS=<web>/frontend/public/models
tfenv/bin/python convert_recognition.py "$MODELS" face_recognition.tflite .
tfenv/bin/python convert_det_lmk.py   "$MODELS" . .
# Equivalence vs the real face-api.js (CPU backend), identical inputs:
tfenv/bin/python make_inputs.py inputs_150.f32
node ref_recognition.js <dir with node_modules> "$MODELS" inputs_150.f32 24 ref_out.json
tfenv/bin/python compare_recognition.py inputs_150.f32 ref_out.json face_recognition.tflite
node ref_det_lmk.js <dir with node_modules> "$MODELS" .   # after writing in_224.f32 / in_112.f32
tfenv/bin/python compare_det_lmk.py
# Pure-Dart pre/post-processing fixtures from the real web/face-api code:
node --no-warnings make_fixtures.mjs <dir with node_modules> <web>/frontend out.json
```

## Measured equivalence (2026-11-10, TFLite vs face-api.js 0.22.2 / tfjs-core 1.7.0 CPU)

| Network | Values compared | Max abs diff | Mean abs diff |
|---|---|---|---|
| Recognition (24 inputs × 128) | 3,072 | 4.7e-6 | 9.8e-7 |
| Tiny Face Detector (12 × 7×7×25) | 14,700 | 5.3e-5 (raw values up to ±40) | 7.2e-6 |
| Landmarks (12 × 136) | 1,632 | 1.0e-6 | 2.5e-7 |

Largest descriptor distance for the same input: **1.5e-5** (backend match bar
`FACE_MATCH_MAX_DISTANCE` = 0.6).

The Dart pre/post-processing (CLAHE, detector decoding + NMS, landmark mapping,
dlib alignment, quality gate, multi-frame averaging) is checked against the real
web/face-api code by `test/features/facial_recognition/face_api_port_test.dart`.
