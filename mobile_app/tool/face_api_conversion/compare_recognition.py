import json, sys, numpy as np, tensorflow as tf
X = np.fromfile(sys.argv[1], dtype=np.float32).reshape(-1, 150, 150, 3)
ref = np.array(json.load(open(sys.argv[2]))['descriptors'], np.float32)
it = tf.lite.Interpreter(model_path=sys.argv[3]); it.allocate_tensors()
inp, out = it.get_input_details()[0], it.get_output_details()[0]
print('tflite input', inp['shape'], inp['dtype'].__name__, '-> output', out['shape'])
got = []
for x in X:
    it.set_tensor(inp['index'], x[None]); it.invoke(); got.append(it.get_tensor(out['index'])[0].copy())
got = np.array(got)
d = np.abs(got - ref)
dist = np.linalg.norm(got - ref, axis=1)
norms = np.linalg.norm(ref, axis=1)
print('values compared: %d x %d' % got.shape)
print('max abs diff  : %.3e' % d.max())
print('mean abs diff : %.3e' % d.mean())
print('max euclidean distance between the two descriptors of the same input: %.3e' % dist.max())
print('descriptor norms (ref): min %.3f max %.3f' % (norms.min(), norms.max()))
# context: distances between DIFFERENT inputs, same model
pair = [np.linalg.norm(ref[i]-ref[j]) for i in range(len(ref)) for j in range(i+1, len(ref))]
print('min distance between different inputs: %.3f (backend match bar 0.6)' % min(pair))
