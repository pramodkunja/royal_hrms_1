"""face-api.js 0.22.2 FaceRecognitionNet, op-for-op (faceRecognitionNet/*.js), as a
tf.function taking [1,150,150,3] float32 RGB in 0..255 (the toBatchTensor(150,true)
output) and returning the [1,128] descriptor."""
import numpy as np
import tensorflow as tf

MEAN_RGB = np.array([122.782, 117.001, 104.298], np.float32)

def build(W):
    c = lambda name: tf.constant(W[name])
    def conv_layer(x, p, strides, relu, padding='SAME'):
        out = tf.nn.conv2d(x, c(p + '/conv/filters'), strides=strides, padding=padding)
        out = out + c(p + '/conv/bias')
        out = out * c(p + '/scale/weights') + c(p + '/scale/biases')
        return tf.nn.relu(out) if relu else out
    conv = lambda x, p: conv_layer(x, p, 1, True)
    conv_no_relu = lambda x, p: conv_layer(x, p, 1, False)
    conv_down = lambda x, p: conv_layer(x, p, 2, True, 'VALID')
    def residual(x, p):
        out = conv(x, p + '/conv1')
        out = conv_no_relu(out, p + '/conv2')
        return tf.nn.relu(out + x)
    def residual_down(x, p):
        out = conv_down(x, p + '/conv1')
        out = conv_no_relu(out, p + '/conv2')
        pooled = tf.nn.avg_pool2d(x, 2, 2, 'VALID')
        if pooled.shape[1] != out.shape[1] or pooled.shape[2] != out.shape[2]:
            out = tf.pad(out, [[0, 0], [0, 1], [0, 0], [0, 0]])  # concat zeros on axis 1
            out = tf.pad(out, [[0, 0], [0, 0], [0, 1], [0, 0]])  # then on axis 2
        if pooled.shape[3] != out.shape[3]:
            pooled = tf.concat([pooled, tf.zeros_like(pooled)], 3)
        return tf.nn.relu(pooled + out)

    @tf.function(input_signature=[tf.TensorSpec([1, 150, 150, 3], tf.float32)])
    def forward(x):
        x = (x - MEAN_RGB) / 256.0
        out = conv_down(x, 'conv32_down')
        out = tf.nn.max_pool2d(out, 3, 2, 'VALID')
        for p in ['conv32_1', 'conv32_2', 'conv32_3']: out = residual(out, p)
        out = residual_down(out, 'conv64_down')
        for p in ['conv64_1', 'conv64_2', 'conv64_3']: out = residual(out, p)
        out = residual_down(out, 'conv128_down')
        for p in ['conv128_1', 'conv128_2']: out = residual(out, p)
        out = residual_down(out, 'conv256_down')
        for p in ['conv256_1', 'conv256_2']: out = residual(out, p)
        out = residual_down(out, 'conv256_down_out')
        avg = tf.reduce_mean(out, axis=[1, 2])
        return tf.matmul(avg, c('fc'))
    return forward
