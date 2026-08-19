#!/usr/bin/env python3
"""Generate the Headroom app icon at multiple sizes, then assemble the .icns.

Painting a real square corner to corner on 1024x1024 and letting macOS's
built-in 14%-radius mask round it gives the cleanest big-sur-style icon.
Run from this directory:
    python3 make_icon.py
"""
import glob
import math
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))

# App palette
TILE = (0.043, 0.067, 0.102, 1.0)     # #0b111a deep ink
GLOW = (0.070, 0.160, 0.120, 1.0)     # teal-green floor
GREEN = (0.133, 0.773, 0.369, 1.0)    # #22c55e accent
AMBER = (0.961, 0.620, 0.043, 1.0)
RED = (0.941, 0.267, 0.294, 1.0)      # #f0444b hot
TRACK = (0.180, 0.220, 0.300, 1.0)    # gauge track on dark
TICK = (0.85, 0.92, 1.0, 1.0)
WHITE = (1.0, 1.0, 1.0, 1.0)

GRID_R = 374.0      # gauge outer radius in 1024 space
GRID_MARGIN = 56.0  # pixels outside the gauge circle
MIN_A = math.radians(132)
MAX_A = math.radians(48)


def mix(a, b, t):
    """Linear blend between tuples `a` and `b` by `t`."""
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def arc_pt(center, r, a):
    return (center[0] + r * math.cos(a), center[1] + r * math.sin(a))


def in_arc_region(x, y, center, min_r, max_r, lo, hi):
    """True if point is inside the annulus and the angular span [lo, hi]."""
    dx, dy = x - center[0], y - center[1]
    r = math.hypot(dx, dy)
    a = math.atan2(dy, dx) % (math.tau)
    lo %= math.tau
    hi %= math.tau
    if lo <= hi:
        in_span = lo <= a <= hi
    else:
        in_span = a >= lo or a <= hi
    return min_r <= r <= max_r and in_span


def tile_center(size):
    c = size / 2.0
    pad = GRID_MARGIN * size / 1024.0
    r = (size / 2.0 - pad) * (GRID_R / (GRID_R + GRID_MARGIN))
    return c, r


def render(size):
    import colorsys as _cs  # placeholder import kept small
    from PIL import Image, ImageDraw
    w = h = size
    c = w / 2.0
    pad = GRID_MARGIN * size / 1024.0
    r = (w / 2.0 - pad) * (GRID_R / (GRID_R + GRID_MARGIN))
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def c255(col):
        return tuple(int(round(v * 255)) for v in col)

    sq = max(0, int(w * 0.965))  # leave a whisper so AA has room
    tl = (w - sq) // 2
    # base tile
    d.rounded_rectangle([tl, tl, tl + sq - 1, tl + sq - 1], radius=int(w * 0.20),
                        fill=c255(TILE))
    # very subtle vertical sheen: darken lower half, lift upper half
    sheen = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    sd.rounded_rectangle([tl, tl, tl + sq - 1, tl + sq - 1], radius=int(w * 0.20),
                         fill=(255, 255, 255, 0))
    sd.ellipse([-w * 0.3, -w * 0.7, w * 1.3, w * 0.9], fill=(255, 255, 255, 26))
    img = Image.alpha_composite(img, sheen)
    d = ImageDraw.Draw(img)

    # gauge track (dark ring)
    d.ellipse([c - r, c - r, c + r, c + r], outline=c255(TRACK), width=max(2, int(w * 0.020)))
    # wide amber "warming" arc from -40deg to +40deg (bottom arc)
    big = r * 0.955
    d.arc([c - big, c - big, c + big, c + big], start=-42, end=42, fill=c255(AMBER), width=max(2, int(w * 0.030)))
    # red "hot" arc 42deg..90deg region as a right-side wedge
    big2 = r * 0.90
    d.arc([c - big2, c - big2, c + big2, c + big2], start=44, end=92, fill=c255(RED), width=max(2, int(w * 0.030)))

    # ticks around the dial
    n = 17
    tick_w = max(1, int(w * 0.010))
    for i in range(n):
        a = MIN_A + (MAX_A - MIN_A) * i / (n - 1)
        p1 = arc_pt((c, c), r * 0.80, a)
        p2 = arc_pt((c, c), r * 0.90, a)
        d.line([p1, p2], fill=c255(TICK), width=tick_w)

    # needle: pointer toward ~72deg (three-quarters up the dial), green
    needle_a = math.radians(72)
    tip = arc_pt((c, c), r * 0.93, needle_a)
    base = (c, c)
    half = max(1, int(w * 0.028))
    # two polygons to fake a tapered needle
    left = arc_pt((c, c), r * 0.16, needle_a + math.pi / 2)
    right = arc_pt((c, c), r * 0.16, needle_a - math.pi / 2)
    d.polygon([left, tip, right], fill=c255(GREEN))
    d.polygon([(c - half, c - half), (c + half, c - half), (c, c + half)], fill=c255(GREEN))
    # hub
    hub_r = r * 0.085
    d.ellipse([c - hub_r, c - hub_r, c + hub_r, c + hub_r], fill=c255(TILE),
              outline=c255(WHITE), width=max(1, int(w * 0.008)))

    # white glow dot at top-left of the gauge, hinting at "headroom" spare capacity
    glow_pt = arc_pt((c, c), r * 0.62, math.radians(-128))
    gr = r * 0.055
    d.ellipse([glow_pt[0] - gr, glow_pt[1] - gr, glow_pt[0] + gr, glow_pt[1] + gr], fill=c255(WHITE))

    # save
    return img


def main():
    try:
        from PIL import Image, ImageDraw
    except Exception as e:
        sys.exit("Pillow not installed; run: python3 -m pip install pillow --user  (%s)" % e)

    out = os.path.join(ROOT, "png")
    os.makedirs(out, exist_ok=True)
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    paths = []
    for s in sizes:
        img = render(s)
        p = os.path.join(out, "app_%d.png" % s)
        img.save(p)
        paths.append((s, p))
    print("rendered:", ", ".join("%dpx" % s for s, _ in paths))

    # iconset -> icns
    iconset = os.path.join(ROOT, "Headroom.iconset")
    os.makedirs(iconset, exist_ok=True)
    for f in glob.glob(os.path.join(iconset, "*")):
        os.remove(f)
    for s, p in paths:
        if s == 16:
            subprocess.run(["cp", p, os.path.join(iconset, "icon_16x16.png")], check=True)
            subprocess.run(["sips", "-z", "32", "32", p, "--out",
                            os.path.join(iconset, "icon_16x16@2x.png")], check=True, capture_output=True)
        elif s == 32:
            subprocess.run(["cp", p, os.path.join(iconset, "icon_32x32.png")], check=True)
        elif s == 64:
            subprocess.run(["cp", p, os.path.join(iconset, "icon_32x32@2x.png")], check=True)
        elif s == 128:
            subprocess.run(["cp", p, os.path.join(iconset, "icon_128x128.png")], check=True)
        elif s == 256:
            subprocess.run(["cp", p, os.path.join(iconset, "icon_128x128@2x.png")], check=True)
            subprocess.run(["cp", p, os.path.join(iconset, "icon_256x256.png")], check=True)
        elif s == 512:
            subprocess.run(["cp", p, os.path.join(iconset, "icon_256x256@2x.png")], check=True)
            subprocess.run(["cp", p, os.path.join(iconset, "icon_512x512.png")], check=True)
        elif s == 1024:
            subprocess.run(["cp", p, os.path.join(iconset, "icon_512x512@2x.png")], check=True)
    # clean up intermediate files for the iconset (except our source pngs)
    icns = os.path.join(ROOT, "..", "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", icns], check=True)
    print("wrote", os.path.realpath(icns))

    # Also emit a 1024 marketing png
    mkt = os.path.join(ROOT, "..", "AppIcon.png")
    subprocess.run(["cp", os.path.join(out, "app_1024.png"), mkt], check=True)
    print("wrote", os.path.realpath(mkt))


if __name__ == "__main__":
    main()
