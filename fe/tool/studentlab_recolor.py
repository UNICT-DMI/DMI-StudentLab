import numpy as np
from PIL import Image

# Tema -> (tinta di destinazione in gradi, scala saturazione, scala luminosità)
THEMES = {
    'ardesia':   (172, 0.85, 1.00),
    'terra':     (18,  0.55, 0.95),
    'bosco':     (118, 0.65, 0.95),
    'pietra':    (38,  0.30, 0.95),
    'fico':      (318, 0.80, 1.00),
    'torbiera':  (80,  0.55, 0.92),
    'kiwi':      (95,  0.75, 1.00),
    'pesca':     (22,  0.62, 1.00),
    'antartide': (205, 0.85, 1.05),
    'cocco':     (28,  0.60, 0.85),
    'laguna':    (180, 0.85, 1.00),
    'focus':     (215, 0.35, 1.00),
    'argilla':   (15,  0.62, 0.98),
}
SRC_CENTER = 250.0   # blu/viola dei vestiti e del logo

def rgb_to_hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(-1); mn = a.min(-1); d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rm = m & (mx == r); gm = m & (mx == g) & ~rm; bm = m & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = ((b - r)[gm] / d[gm]) + 2
    h[bm] = ((r - g)[bm] / d[bm]) + 4
    h = h * 60.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h, s, mx

def hsv_to_rgb(h, s, v):
    h = (h % 360) / 60.0
    i = np.floor(h).astype(int) % 6
    f = h - np.floor(h)
    p = v * (1 - s); q = v * (1 - s * f); t = v * (1 - s * (1 - f))
    out = np.zeros(h.shape + (3,))
    for k, (rr, gg, bb) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        sel = i == k
        out[..., 0][sel] = rr[sel]; out[..., 1][sel] = gg[sel]; out[..., 2][sel] = bb[sel]
    return out

def recolor(img, theme, spread=0.40):
    target, sat_k, val_k = THEMES[theme]
    im = img.convert('RGBA')
    a = np.asarray(im).astype(np.float64) / 255.0
    rgb, alpha = a[..., :3], a[..., 3:]
    h, s, v = rgb_to_hsv(rgb)
    # Solo blu, viola, ciano e magenta abbastanza saturi: pelo grigio, bianco,
    # lingua e orecchie rosa restano come sono.
    band = (h >= 175) & (h <= 325)
    weight = np.clip((s - 0.18) / 0.20, 0, 1) * band
    nh = target + (h - SRC_CENTER) * spread
    ns = np.clip(s * sat_k, 0, 1)
    nv = np.clip(v * val_k, 0, 1)
    new = hsv_to_rgb(nh, ns, nv)
    w = weight[..., None]
    out = rgb * (1 - w) + new * w
    res = np.concatenate([out, alpha], -1)
    return Image.fromarray((res * 255).round().astype(np.uint8), 'RGBA')
