import sys, numpy as np, tensorflow as tf
sys.path.insert(0, sys.argv[3])
import weights, recognition
W = weights.load(sys.argv[1], 'face_recognition_model')
print('weights:', len(W), 'params:', sum(v.size for v in W.values()))
fwd = recognition.build(W)
conv = tf.lite.TFLiteConverter.from_concrete_functions([fwd.get_concrete_function()], fwd)
model = conv.convert()
open(sys.argv[2], 'wb').write(model)
print('tflite bytes:', len(model))
