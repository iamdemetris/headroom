#!/usr/bin/env python3
"""Generate the Headroom app icon.

Big Sur style: full-bleed 1024x1024 art (macOS applies the rounded squircle
mask itself, so the art must NOT bake its own corners). A dark dashboard tile
with a soft teal glow and a clean open-bottom gauge dial at a sane scale:

  - dark vertical ink gradient background
  - green -> amber -> red gauge ring (open at the bottom)
  - thin white ticks, white "headroom" start dot
  - green needle pointing at 12 o'clock with an ink/white hub

Run from this directory:
    python3 make_icon.py
"""
import glob
import math
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))

# Palette (matches the app theme)
INK_TOP = (0.058, 0.088, 0.134, 1.0)
INK_BOT = (0.026, 0.042, 0.072, 1.0)
GLOW_COLOR = (0.09, 0.23, 0.17, 1.0)
GREEN = (0.16, 0.78, 0.42, 1.0)
AMBER = (0.97, 0.65, 0.10, 1.0)
RED = (0.95, 0.30, 0.31, 1.0)
TICK = (0.90, 0.95, 1.0, 1.0)
WHITE = (1.0, 1.0, 1.0, 1.0)
NEEDLE = (0.19, 0.80, 0.46, 1.0)
HUB_INK = (0.03, 0.05, 0.08, 1.0)

A0 = 135.0     # dial start (lower-left)
SPAN = 270.0   # dial sweep through the top to the lower-right


def mix(a, b, t):
    t = min(1.0, max(0.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def c255(col):
    return tuple(int(round(min(1.0, max(0.0, v)) * 255)) for v in col)


def pt(center, r, deg):
    rad = math.radians(deg)
    return (center[0] + r * math.cos(rad), center[1] + r * math.sin(rad))


def build_ring_layer(size, c, R, T):
    """Green->amber->red gauge ring with rounded end-caps, own transparent layer."""
    from PIL import Image, ImageDraw
    w = h = size
    layer = Image.new("RGBA", (w, h))
    ld = ImageDraw.Draw(layer, "RGBA")
    bbox = [c - R, c - R, c + R, c + R]
    n = 72
    hot = 0.12  # last 12% of the dial is the red hot slot
    for i in range(n):
        f0, f1 = i / n, (i + 1) / n
        ang0 = A0 + SPAN * f0
        ang1 = A0 + SPAN * f1 + 0.25  # slight overlap hides seams
        if f1 >= 1.0 - hot:
            col = mix(AMBER, RED, (f1 - (1.0 - hot)) / hot)
        else:
            col = mix(GREEN, AMBER, f1 / (1.0 - hot))
        ld.arc(bbox, start=ang0, end=ang1, fill=c255(col), width=int(T))

    cap_r = T / 2
    mid = R - T / 2
    p0 = pt((c, c), mid, A0)
    p1 = pt((c, c), mid, A0 + SPAN)
    ld.ellipse([p0[0] - cap_r, p0[1] - cap_r, p0[0] + cap_r, p0[1] + cap_r], fill=c255(GREEN))
    ld.ellipse([p1[0] - cap_r, p1[1] - cap_r, p1[0] + cap_r, p1[1] + cap_r], fill=c255(RED))
    return layer


def render(size):
    from PIL import Image, ImageDraw, ImageFilter
    s = size / 1024.0
    w = h = size
    c = size / 2.0
    R = 330 * s   # gauge outer radius: ~64% of the tile -> proper icon margins
    T = 62 * s    # ring thickness
    # 1. background: vertical ink gradient
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img, "RGBA")
    for y in range(h):
        col = c255(mix(INK_TOP, INK_BOT, y / (h - 1)))
        d.line([(0, y), (w, y)], fill=col)

    # 2. soft teal glow behind the gauge
    glow = Image.new("RGBA", (w, h))
    gd = ImageDraw.Draw(glow, "RGBA")
    gr = R * 1.3
    gd.ellipse([c - gr, c - gr * 0.7, c + gr, c + gr * 1.05], fill=c255(GLOW_COLOR))
    glow = glow.filter(ImageFilter.GaussianBlur(90 * s))
    img = Image.alpha_composite(img, glow)

    # 3. faint upper sheen
    sheen = Image.new("RGBA", (w, h))
    sd = ImageDraw.Draw(sheen, "RGBA")
    sr = R * 1.5
    sd.ellipse([c - sr * 1.1, c - sr * 1.4, c + sr * 0.7, c - sr * 0.1], fill=(255, 255, 255, 24))
    img = Image.alpha_composite(img, sheen.filter(ImageFilter.GaussianBlur(80 * s)))

    # 3b. Bake a rounded-corner mask (macOS here does NOT always apply the
    # squircle mask itself, so we clip the art AND add an inset rounded border
    # that matches the masked radius). This is what makes the icon look like
    # every other Mac app icon instead of a hard square.
    corner = 0.2237  # macOS 14+ squircle-like corner radius (normalized)
    radius = corner * size
    mask = Image.new("L", (w, h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)

    # An antique-white inset border track just inside the rounded clip,
    # with a matching rounded-rect radius so the border follows the corners.
    border_inset = size * 0.030
    border_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(border_layer, "RGBA")
    bdraw_r = max(0.0, radius - border_inset * 0.6)
    bd.rounded_rectangle(
        [border_inset, border_inset, w - border_inset, h - border_inset],
        radius=bdraw_r, outline=(255, 255, 255, 70), width=max(1, int(3.5 * s)))
    bd.rounded_rectangle(
        [border_inset + 5 * s, border_inset + 5 * s, w - border_inset - 5 * s, h - border_inset - 5 * s],
        radius=bdraw_r + 2 * s, outline=(255, 255, 255, 22), width=1)
    img = Image.alpha_composite(img, border_layer)

    # apply rounded mask with light anti-aliasing
    mask_blur = mask.filter(ImageFilter.GaussianBlur(1.0))
    alpha = img.split()[3]
    img = img.convert("RGBA")
    img.putalpha(Image.composite(mask_blur, alpha, mask_blur))

    # 4. gauge ring: soft under-glow + crisp ring
    arc = build_ring_layer(size, c, R, T)
    ring_glow = arc.filter(ImageFilter.GaussianBlur(9 * s))
    r, g, b, a = ring_glow.split()
    ring_glow = Image.merge("RGBA", (r, g, b, a.point(lambda v: int(v * 0.55))))
    img = Image.alpha_composite(img, ring_glow)
    img = Image.alpha_composite(img, arc)
    d = ImageDraw.Draw(img, "RGBA")

    # 5. ticks just inside the ring
    n_ticks = 13
    for i in range(n_ticks):
        ang = A0 + SPAN * i / (n_ticks - 1)
        p_in = pt((c, c), 0.58 * R, ang)
        p_out = pt((c, c), 0.74 * R, ang)
        d.line([p_in, p_out], fill=c255(TICK), width=max(1, int(6 * s)))

    # 6. white "headroom" start dot on the ring's start cap
    mid = R - T / 2
    p = pt((c, c), mid, A0)
    dr = 14 * s
    d.ellipse([p[0] - dr, p[1] - dr, p[0] + dr, p[1] + dr], fill=c255(WHITE))

    # 7. needle straight up at 12 o'clock
    ang = 270.0
    tip = pt((c, c), 0.60 * R, ang)
    tail = 0.13 * R
    left = pt((c, c), tail, ang + 90)
    right = pt((c, c), tail, ang - 90)
    d.polygon([left, tip, right], fill=c255(NEEDLE))

    # 8. hub
    hr = 30 * s
    d.ellipse([c - hr, c - hr, c + hr, c + hr],
              fill=c255(HUB_INK), outline=c255(WHITE), width=max(1, int(5 * s)))
    d.ellipse([c - hr * 0.5, c - hr * 0.5, c + hr * 0.5, c + hr * 0.5], fill=c255(NEEDLE))

    return img


def main():
    try:
        from PIL import Image  # noqa: F401
    except Exception as e:
        sys.exit("Pillow not installed; run: python3 -m pip install pillow --user  (%s)" % e)

    out = os.path.join(ROOT, "png")
    os.makedirs(out, exist_ok=True)
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    masters = {}
    for sz in sizes:
        img = render(sz)
        p = os.path.join(out, "app_%d.png" % sz)
        img.save(p)
        masters[sz] = p

    iconset = os.path.join(ROOT, "Headroom.iconset")
    os.makedirs(iconset, exist_ok=True)
    for f in glob.glob(os.path.join(iconset, "*")):
        os.remove(f)

    mapping = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, src in mapping.items():
        subprocess.run(["cp", masters[src], os.path.join(iconset, name)], check=True)

    icns = os.path.join(ROOT, "..", "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", icns], check=True)
    print("wrote", os.path.realpath(icns))

    png = os.path.join(ROOT, "..", "AppIcon.png")
    subprocess.run(["cp", masters[1024], png], check=True)
    print("wrote", os.path.realpath(png))


if __name__ == "__main__":
    main()
