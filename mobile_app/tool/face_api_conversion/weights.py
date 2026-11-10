"""Loads face-api.js weight manifests exactly as tfjs-core 1.7 io.decodeWeights does:
uint8-quantized entries are dequantized as q * scale + min; float32 entries are read
little-endian. Returns an ordered dict name -> np.float32 array."""
import json, os
from collections import OrderedDict
import numpy as np

def load(model_dir, prefix):
    man = json.load(open(os.path.join(model_dir, prefix + '-weights_manifest.json')))
    out = OrderedDict()
    for group in man:
        buf = b''.join(open(os.path.join(model_dir, p), 'rb').read() for p in group['paths'])
        off = 0
        for w in group['weights']:
            n = int(np.prod(w['shape'])) if w['shape'] else 1
            q = w.get('quantization')
            if q:
                assert q['dtype'] == 'uint8', q
                raw = np.frombuffer(buf, dtype=np.uint8, count=n, offset=off)
                off += n
                vals = raw.astype(np.float32) * np.float32(q['scale']) + np.float32(q['min'])
            else:
                assert w['dtype'] == 'float32', w
                vals = np.frombuffer(buf, dtype='<f4', count=n, offset=off).astype(np.float32)
                off += 4 * n
            out[w['name']] = vals.reshape(w['shape']).astype(np.float32)
        assert off == len(buf), (off, len(buf))
    return out
