#!/usr/bin/env python3
"""Tigris's artwork, made the way the Kestrel's is.

The tiger is not drawn here. FLUX.2 klein drew it, on the RTX 4070 in Zeus,
from the prompt in art/README.md; what is drawn here is everything that
happens after, and that is where the look comes from. The render is crushed
to a 96-pixel grid with LANCZOS and snapped to the Kestrel's palette with no
dither, exactly as dyad's ops/artgen.py does it in retro(), because error
diffusion against a small palette scatters confetti across fur. Then it is
shown at an integer scale and nothing else: a 1.5x pixel is a blurred pixel.

The palette is the SCREEN theme of dyad's look.py, the 27 colours a Kestrel
picture is allowed to be made of, in the order they are declared there. The
lettering is the Kestrel's own typeface (art/kp.py), five by seven.

  python3 art/mkart.py        writes art/tiger.png, art/tiger-full.png,
                              art/banner.png (animated) and art/social.png

Needs Pillow. Nothing in Tigris itself runs this.
"""
from __future__ import annotations

import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kp  # noqa: E402

# The Kestrel's SCREEN palette (dyad, app/look.py), in declared order.
PALETTE = ("#060a0f #0f1822 #18242f #22313f #2a3c4c #3a5268 #5c7793 #070c12 "
           "#c6d6e2 #93aabb #64798c #f2f8fb #ffb02e #9c6410 #4fd67f #256b45 "
           "#3f8f60 #52c7e8 #1d6b84 #e8833a #8c4515 #4a90e2 #24528c #e2483d "
           "#7a1d16 #9a73e0 #a08f6a").split()


def rgb(h: str) -> tuple[int, int, int]:
    return int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)


# The names look.py gives them, for the drawing below
C = {k: rgb(v) for k, v in dict(
    void="#060a0f", hull="#0f1822", hull2="#18242f", hull3="#22313f",
    grid="#2a3c4c", edge="#3a5268", lip="#5c7793", shade="#070c12",
    ink="#c6d6e2", ink2="#93aabb", dim="#64798c", lit="#f2f8fb",
    amber="#ffb02e", amber2="#9c6410", green="#4fd67f", cyan="#52c7e8",
    orange="#e8833a", orange2="#8c4515", red="#e2483d").items()}

SCALE = 4          # device pixels per logical pixel, everywhere


# --------------------------------------------------------------------------
# the crush
# --------------------------------------------------------------------------

def palette_image() -> Image.Image:
    """The palette as Pillow wants it, the spare entries repeating the last
    real colour so the quantiser cannot reach a colour that is not in it."""
    p = Image.new("P", (1, 1))
    flat: list[int] = []
    for h in PALETTE:
        flat += list(rgb(h))
    flat += flat[-3:] * (256 - len(PALETTE))
    p.putpalette(flat)
    return p


def retro(img: Image.Image, wide: int) -> Image.Image:
    """dyad's retro(): to the grid with LANCZOS, to the palette undithered."""
    w, h = img.size
    small = img.convert("RGB").resize((wide, max(1, round(h * wide / w))),
                                      Image.LANCZOS)
    return small.quantize(palette=palette_image(),
                          dither=Image.Dither.NONE).convert("RGB")


# --------------------------------------------------------------------------
# drawing, in logical pixels
# --------------------------------------------------------------------------

def rect(im: Image.Image, x: int, y: int, w: int, h: int, col) -> None:
    im.paste(col, (x, y, x + w, y + h))


def stipple(im: Image.Image, x: int, y: int, w: int, h: int, a, b) -> None:
    """Two adjacent ramp steps in a one-pixel checker: a third colour that is
    not in the palette, which is the trick the Kestrel's panels are made of."""
    px = im.load()
    for j in range(y, y + h):
        for i in range(x, x + w):
            px[i, j] = a if (i + j) % 2 else b


def bevel(im: Image.Image, x: int, y: int, w: int, h: int) -> None:
    """Light from above and to the left: the lit edge and the shadow."""
    rect(im, x, y, w, 1, C["lip"])
    rect(im, x, y, 1, h, C["lip"])
    rect(im, x, y + h - 1, w, 1, C["shade"])
    rect(im, x + w - 1, y, 1, h, C["shade"])


def text(im: Image.Image, s: str, x: int, y: int, col, scale: int = 1) -> int:
    """Kestrel lettering at an integer scale; returns the x after it."""
    for ch in s:
        g = kp.G.get(ch, kp.G["?"])
        for r, row in enumerate(g):
            for c, on in enumerate(row):
                if on == "#":
                    rect(im, x + c * scale, y + r * scale, scale, scale, col)
        x += 6 * scale
    return x


def wordmark(im: Image.Image, s: str, x: int, y: int, scale: int) -> None:
    """A title the way a 1993 box put one on: a drop shadow, a keyline, and
    the letters banded amber to orange to burnt orange from the top down."""
    w, h = 6 * scale * len(s), 7 * scale
    mask = Image.new("L", (w, h), 0)
    text(mask, s, 0, 0, 255, scale)
    # the shadow, two pixels down and right, in the hull's colour
    shadow = Image.new("RGB", (w, h), C["hull3"])
    im.paste(shadow, (x + 2, y + 2), mask)
    # the keyline: the mask grown by one pixel, in the darkest colour
    grown = Image.new("L", (w + 2, h + 2), 0)
    for dx in (0, 1, 2):
        for dy in (0, 1, 2):
            grown.paste(255, (dx, dy), mask)
    im.paste(Image.new("RGB", grown.size, C["shade"]), (x - 1, y - 1), grown)
    # the letters, in bands: the top lit, the middle, the bottom in shadow,
    # and one row of the lightest amber along the top of every stroke
    bands = Image.new("RGB", (w, h))
    for j in range(h):
        col = (C["amber"] if j < h * 0.42 else
               C["orange"] if j < h * 0.78 else C["orange2"])
        rect(bands, 0, j, w, 1, col)
    im.paste(bands, (x, y), mask)
    px = im.load()
    m = mask.load()
    for j in range(h):
        for i in range(w):
            if m[i, j] and (j == 0 or not m[i, j - 1]):
                px[x + i, y + j] = C["lit"]


def glass(im: Image.Image) -> Image.Image:
    """To device pixels, and the CRT over them: one darker line per logical
    row, as look.py's scanlines are, and the corners of the tube."""
    big = im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)
    px = big.load()
    cx, cy = big.width / 2, big.height / 2
    for y in range(big.height):
        scan = 0.83 if y % SCALE == SCALE - 1 else 1.0
        for x in range(big.width):
            dx, dy = (x - cx) / cx, (y - cy) / cy
            v = scan * (1.0 - 0.18 * max(0.0, dx * dx + dy * dy - 0.35))
            r, g, b = px[x, y]
            px[x, y] = (int(r * v), int(g * v), int(b * v))
    return big


# --------------------------------------------------------------------------
# the pieces
# --------------------------------------------------------------------------

def tiger(name: str = "tiger-split.png", wide: int = 96) -> Image.Image:
    return retro(Image.open(os.path.join(HERE, "source", name)), wide)


def banner(cursor: bool, eye: bool) -> Image.Image:
    W, H = 320, 112
    im = Image.new("RGB", (W, H), C["void"])
    t = tiger()
    if not eye:
        # The eye in the shadow, half-lidded for a frame: its amber pixels on
        # the dark side of the face go to the amber's own shadow step.
        px = t.load()
        for y in range(t.height):
            for x in range(t.width // 2, t.width):
                if px[x, y] == C["amber"]:
                    px[x, y] = C["amber2"]
    im.paste(t, (8, 8))
    # the panel the title sits on
    stipple(im, 112, 8, 200, 96, C["hull2"], C["hull"])
    bevel(im, 112, 8, 200, 96)
    wordmark(im, "TIGRIS", 124, 17, 5)
    rect(im, 124, 60, 176, 1, C["grid"])
    text(im, "SECURITY AUDITS FOR LINUX", 124, 66, C["ink"])
    text(im, "TIGER 1993 · TIGRIS 2026", 124, 76, C["dim"])
    x = text(im, "$ ", 124, 90, C["amber"])
    x = text(im, "sudo ./tigris", x, 90, C["ink"])
    if cursor:
        rect(im, x + 1, 90, 5, 7, C["amber"])
    bevel(im, 0, 0, W, H)
    return glass(im)


def social() -> Image.Image:
    """1280 by 640, GitHub's size for a repository's social preview."""
    W, H = 320, 160
    im = Image.new("RGB", (W, H), C["void"])
    im.paste(tiger(wide=128), (8, 16))
    stipple(im, 144, 16, 168, 128, C["hull2"], C["hull"])
    bevel(im, 144, 16, 168, 128)
    wordmark(im, "TIGRIS", 150, 34, 4)
    rect(im, 154, 72, 148, 1, C["grid"])
    text(im, "SECURITY AUDITS", 154, 80, C["ink"])
    text(im, "FOR LINUX, IN SH", 154, 90, C["ink"])
    text(im, "TIGER 1993 · 2026", 154, 106, C["dim"])
    text(im, "github.com/", 154, 122, C["ink2"])
    text(im, "creativeheadz/tigris", 154, 131, C["amber"])
    bevel(im, 0, 0, W, H)
    return glass(im)


def main() -> int:
    out = lambda n: os.path.join(HERE, n)  # noqa: E731
    big = lambda im: im.resize((im.width * SCALE, im.height * SCALE),  # noqa: E731
                               Image.NEAREST)
    big(tiger()).save(out("tiger.png"), optimize=True)
    big(tiger("tiger-full.png")).save(out("tiger-full.png"), optimize=True)
    # The banner moves twice: the cursor blinks, and once in a while the
    # eye in the shadow narrows. Half a second a frame, eight frames.
    frames, durations = [], []
    for i in range(8):
        frames.append(banner(cursor=i % 2 == 0, eye=i != 5))
        durations.append(500 if i != 5 else 180)
    frames[0].save(out("banner.png"), save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, optimize=True)
    social().save(out("social.png"), optimize=True)
    for n in ("tiger.png", "tiger-full.png", "banner.png", "social.png"):
        print(f"{n:15s} {os.path.getsize(out(n)) // 1024:4d} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
