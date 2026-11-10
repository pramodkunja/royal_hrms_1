"""face-api.js 0.22.2 TinyFaceDetector (tinyYolov2 runMobilenet, withSeparableConvs,
isFirstLayerConv2d) and FaceLandmark68Net (FaceFeatureExtractor + fc), op-for-op.
Inputs are raw RGB 0..255 squares (after imageToSquare); outputs are the raw network
outputs — box decoding / NMS / landmark post-processing happen in the app."""
import numpy as np
import tensorflow as tf

DET_MEAN = np.array([117.001, 114.697, 97.404], np.float32)
LMK_MEAN = np.array([122.782, 117.001, 104.298], np.float32)

def leaky(x):  # tinyYolov2/leaky.js: relu(x - 0.1x) + 0.1x
    m = x * np.float32(0.10000000149011612)
    return tf.nn.relu(x - m) + m

def build_detector(W, size=224):
    c = lambda n: tf.constant(W[n])
    def sep(x, p):  # tinyYolov2/depthwiseSeparableConv.js
        x = tf.pad(x, [[0, 0], [1, 1], [1, 1], [0, 0]])
        x = tf.nn.separable_conv2d(x, c(p + '/depthwise_filter'), c(p + '/pointwise_filter'), [1, 1, 1, 1], 'VALID')
        return leaky(x + c(p + '/bias'))
    @tf.function(input_signature=[tf.TensorSpec([1, size, size, 3], tf.float32)])
    def forward(x):
        x = (x - DET_MEAN) / 256.0
        out = leaky(tf.nn.conv2d(x, c('conv0/filters'), 1, 'VALID') + c('conv0/bias'))
        out = tf.nn.max_pool2d(out, 2, 2, 'SAME')
        for i in range(1, 5):
            out = sep(out, 'conv%d' % i)
            out = tf.nn.max_pool2d(out, 2, 2, 'SAME')
        out = sep(out, 'conv5')
        out = tf.nn.max_pool2d(out, 2, 1, 'SAME')
        return tf.nn.conv2d(out, c('conv8/filters'), 1, 'VALID') + c('conv8/bias')
    return forward

def build_landmarks(W):
    c = lambda n: tf.constant(W[n])
    def dsc(x, p, s):  # common/depthwiseSeparableConv.js: separableConv2d 'same' + bias (no activation)
        return tf.nn.separable_conv2d(x, c(p + '/depthwise_filter'), c(p + '/pointwise_filter'), [1, s, s, 1], 'SAME') + c(p + '/bias')
    def dense4(x, p, first=False):
        if first:
            out1 = tf.nn.relu(tf.nn.conv2d(x, c(p + '/conv0/filters'), 2, 'SAME') + c(p + '/conv0/bias'))
        else:
            out1 = tf.nn.relu(dsc(x, p + '/conv0', 2))
        out2 = dsc(out1, p + '/conv1', 1)
        in3 = tf.nn.relu(out1 + out2)
        out3 = dsc(in3, p + '/conv2', 1)
        in4 = tf.nn.relu(out1 + (out2 + out3))
        out4 = dsc(in4, p + '/conv3', 1)
        return tf.nn.relu(out1 + (out2 + (out3 + out4)))
    @tf.function(input_signature=[tf.TensorSpec([1, 112, 112, 3], tf.float32)])
    def forward(x):
        x = (x - LMK_MEAN) / 255.0
        out = dense4(x, 'dense0', True)
        out = dense4(out, 'dense1')
        out = dense4(out, 'dense2')
        out = dense4(out, 'dense3')
        out = tf.nn.avg_pool2d(out, 7, 2, 'VALID')
        out = tf.reshape(out, [1, -1])
        return tf.matmul(out, c('fc/weights')) + c('fc/bias')
    return forward
