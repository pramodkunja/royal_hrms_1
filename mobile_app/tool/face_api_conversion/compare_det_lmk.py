import json, numpy as np, tensorflow as tf
ref = json.load(open('ref_det_lmk.json'))
def run(model, X):
    it = tf.lite.Interpreter(model_path=model); it.allocate_tensors()
    i, o = it.get_input_details()[0], it.get_output_details()[0]
    res = []
    for x in X:
        it.set_tensor(i['index'], x[None]); it.invoke(); res.append(it.get_tensor(o['index']).reshape(-1).copy())
    return np.array(res), o['shape']
for name, f, s, key in [('tiny_face_detector', 'in_224.f32', 224, 'det'), ('face_landmark_68', 'in_112.f32', 112, 'lmk')]:
    X = np.fromfile(f, np.float32).reshape(-1, s, s, 3)
    got, shape = run(name + '.tflite', X)
    r = np.array(ref[key], np.float32)
    d = np.abs(got - r)
    print('%-20s out %s  values %d  max abs %.3e  mean abs %.3e  (ref |max| %.2f)' % (name, list(shape), d.size, d.max(), d.mean(), np.abs(r).max()))
