import numpy as np, sys
rng = np.random.default_rng(20261110)
xs = []
for i in range(16):                                  # uniform noise images
    xs.append(rng.integers(0, 256, (150, 150, 3)).astype(np.float32))
yy, xx = np.mgrid[0:150, 0:150].astype(np.float32)
for i in range(8):                                    # smooth structured images
    r = 127 + 120*np.sin(xx/(9+i) + i); g = 127 + 120*np.cos(yy/(11+i)); b = (xx+yy)*255/298
    blob = 90*np.exp(-(((xx-75)/(30+i))**2 + ((yy-70)/(38+i))**2))
    xs.append(np.clip(np.stack([r+blob, g+blob*0.8, b+blob*0.6], -1), 0, 255).round().astype(np.float32))
X = np.stack(xs)
X.tofile(sys.argv[1]); print(X.shape)
