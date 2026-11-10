import sys, tensorflow as tf
sys.path.insert(0, sys.argv[2])
import weights, detector_landmarks as dl
md, outdir = sys.argv[1], sys.argv[3]
for name, prefix, build in [('tiny_face_detector', 'tiny_face_detector_model', dl.build_detector),
                            ('face_landmark_68', 'face_landmark_68_model', dl.build_landmarks)]:
    W = weights.load(md, prefix)
    fwd = build(W)
    m = tf.lite.TFLiteConverter.from_concrete_functions([fwd.get_concrete_function()], fwd).convert()
    open('%s/%s.tflite' % (outdir, name), 'wb').write(m)
    print(name, 'params', sum(v.size for v in W.values()), 'tflite bytes', len(m))
