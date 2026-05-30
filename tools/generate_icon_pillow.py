#!/usr/bin/env python3
"""
WiseTVPlayer - Icon PNG Generator (Pillow-only, no Cairo required)
Draws the TV icon directly with Pillow + NumPy gradients.

Run from project root:
    python tools/generate_icon_pillow.py
"""

import os
import numpy as np
from PIL import Image, ImageDraw

SIZE = 1024
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "images")


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def make_radial_gradient(w, h, inner_hex, outer_hex):
    inner = np.array(hex_to_rgb(inner_hex), dtype=np.float32)
    outer = np.array(hex_to_rgb(outer_hex), dtype=np.float32)
    cx, cy = w * 0.45, h * 0.40
    Y, X = np.mgrid[0:h, 0:w]
    dist = np.sqrt(((X - cx) / w) ** 2 + ((Y - cy) / h) ** 2)
    t = np.clip(dist / 0.68, 0, 1)[..., np.newaxis]
    pixels = (inner * (1 - t) + outer * t).astype(np.uint8)
    return Image.fromarray(pixels, "RGB")


def make_linear_gradient_img(w, h, top_hex, bot_hex):
    top = np.array(hex_to_rgb(top_hex), dtype=np.float32)
    bot = np.array(hex_to_rgb(bot_hex), dtype=np.float32)
    t = np.linspace(0, 1, h, dtype=np.float32)[:, np.newaxis, np.newaxis]
    pixels = (top * (1 - t) + bot * t).astype(np.uint8)
    pixels = np.broadcast_to(pixels, (h, w, 3)).copy()
    return Image.fromarray(pixels, "RGB")


def draw_rounded_rect(draw, x, y, w, h, rx, fill):
    draw.rounded_rectangle([x, y, x + w, y + h], radius=rx, fill=fill)


def make_play_gradient(pts, w, h):
    """Diagonal gradient for the play triangle: purple -> violet -> teal."""
    c0 = np.array(hex_to_rgb("#A89BFF"), dtype=np.float32)
    c1 = np.array(hex_to_rgb("#6C63FF"), dtype=np.float32)
    c2 = np.array(hex_to_rgb("#00D4AA"), dtype=np.float32)
    x0, y0 = 300, 228
    x1, y1 = 750, 660
    dx, dy = x1 - x0, y1 - y0
    length_sq = dx * dx + dy * dy
    Y, X = np.mgrid[0:h, 0:w]
    t = np.clip(((X - x0) * dx + (Y - y0) * dy) / length_sq, 0, 1)
    t2 = t[..., np.newaxis]
    t_mid = np.clip(t2 / 0.4, 0, 1)
    t_end = np.clip((t2 - 0.4) / 0.6, 0, 1)
    pixels = (c0 * (1 - t_mid) + c1 * t_mid) * (1 - t_end) + c2 * t_end
    return pixels.astype(np.uint8)


def build_main_icon(size=1024):
    """Full icon (for non-adaptive Android, iOS, etc.)"""
    # Background radial gradient
    img = make_radial_gradient(size, size, "#1E1E2C", "#07070F").convert("RGBA")
    draw = ImageDraw.Draw(img)

    # TV body
    body_grad = make_linear_gradient_img(848, 572, "#26263A", "#18181F").convert("RGBA")
    body_mask = Image.new("L", (848, 572), 0)
    ImageDraw.Draw(body_mask).rounded_rectangle([0, 0, 847, 571], radius=62, fill=255)
    img.paste(body_grad, (88, 152), body_mask)

    # Screen black
    draw.rounded_rectangle([116, 180, 908, 696], radius=46, fill="#08080E")

    # Play triangle gradient
    play_arr = make_play_gradient(None, size, size)
    play_img = Image.fromarray(play_arr, "RGB").convert("RGBA")
    tri_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(tri_mask).polygon([(300, 228), (300, 660), (754, 444)], fill=255)
    img.paste(play_img, (0, 0), tri_mask)

    # TV stand neck
    draw.rounded_rectangle([464, 724, 560, 778], radius=14, fill="#16161E")
    # TV stand base
    draw.rounded_rectangle([336, 778, 688, 824], radius=23, fill="#16161E")

    # Subtle screen border
    draw.rounded_rectangle([116, 180, 908, 696], radius=46,
                            outline=(255, 255, 255, 10), width=2)

    return img


def build_foreground_icon(size=1024):
    """
    Adaptive foreground: just the TV + play on transparent background.
    Scaled to fit the 72% safe zone (content in centre 66%).
    """
    # Work at 2x then downsample for quality
    scale = 2
    s = size * scale
    # Content sits in the inner 66% of the adaptive icon
    margin = int(s * 0.17)
    content_w = s - 2 * margin
    content_h = s - 2 * margin

    full = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(full)

    # Scale factors relative to 1024 source
    sf = content_w / 1024

    def sx(v): return int(margin + v * sf)
    def sy(v): return int(margin + v * sf)
    def sw(v): return int(v * sf)

    # TV body
    body_grad = make_linear_gradient_img(sw(848), sw(572), "#26263A", "#18181F").convert("RGBA")
    body_mask = Image.new("L", (sw(848), sw(572)), 0)
    ImageDraw.Draw(body_mask).rounded_rectangle(
        [0, 0, sw(848) - 1, sw(572) - 1], radius=int(62 * sf), fill=255)
    full.paste(body_grad, (sx(88), sy(152)), body_mask)

    # Screen
    draw.rounded_rectangle([sx(116), sy(180), sx(116) + sw(792), sy(180) + sw(516)],
                            radius=int(46 * sf), fill="#08080E")

    # Play triangle gradient
    play_arr = make_play_gradient(None, s, s)
    play_img = Image.fromarray(play_arr, "RGB").convert("RGBA")
    pts = [(sx(300), sy(228)), (sx(300), sy(660)), (sx(754), sy(444))]
    tri_mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(tri_mask).polygon(pts, fill=255)
    full.paste(play_img, (0, 0), tri_mask)

    # Stand
    draw.rounded_rectangle([sx(464), sy(724), sx(464) + sw(96), sy(724) + sw(54)],
                            radius=int(14 * sf), fill="#16161E")
    draw.rounded_rectangle([sx(336), sy(778), sx(336) + sw(352), sy(778) + sw(46)],
                            radius=int(23 * sf), fill="#16161E")

    return full.resize((size, size), Image.LANCZOS)


def save(img, name):
    path = os.path.join(OUT_DIR, name)
    img.save(path, "PNG", optimize=True)
    kb = os.path.getsize(path) // 1024
    print(f"  OK  {name}  ({kb} KB)")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("\n-- WiseTVPlayer Icon Generator (Pillow) --")

    print("  Generating app_icon.png ...")
    save(build_main_icon(1024), "app_icon.png")

    print("  Generating app_icon_foreground.png ...")
    save(build_foreground_icon(1024), "app_icon_foreground.png")

    print("\nDone! Now run:")
    print("  dart run flutter_launcher_icons")
    print()


if __name__ == "__main__":
    main()
