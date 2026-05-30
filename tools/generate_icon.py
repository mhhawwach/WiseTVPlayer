#!/usr/bin/env python3
"""
WiseTVPlayer — Icon PNG Generator
Converts the master SVG to PNG files that flutter_launcher_icons can use.

Requirements (one-time install):
    pip install cairosvg Pillow

Then run from the project root:
    python tools/generate_icon.py

After that, generate all platform sizes:
    dart run flutter_launcher_icons
"""
import os
import sys


def check_deps():
    missing = []
    try:
        import cairosvg  # noqa: F401
    except ImportError:
        missing.append("cairosvg")
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        missing.append("Pillow")
    if missing:
        print(f"Missing: {', '.join(missing)}")
        print(f"Install with:  pip install {' '.join(missing)}")
        sys.exit(1)


def convert(svg_path: str, png_path: str, size: int) -> None:
    import cairosvg
    os.makedirs(os.path.dirname(png_path), exist_ok=True)
    cairosvg.svg2png(
        url=svg_path,
        write_to=png_path,
        output_width=size,
        output_height=size,
    )
    kb = os.path.getsize(png_path) // 1024
    print(f"  ✓  {os.path.relpath(png_path)}  ({size}×{size}, {kb} KB)")


def main():
    check_deps()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    img_dir = os.path.join(root, "assets", "images")

    tasks = [
        # (svg filename, png filename, size)
        ("app_icon.svg",            "app_icon.png",            1024),
        ("app_icon_foreground.svg", "app_icon_foreground.png", 1024),
    ]

    print("\n── WiseTVPlayer Icon Generator ──────────────────────────────")
    for svg_name, png_name, size in tasks:
        convert(
            os.path.join(img_dir, svg_name),
            os.path.join(img_dir, png_name),
            size,
        )

    print()
    print("Done!  Next step:")
    print("  dart run flutter_launcher_icons")
    print()


if __name__ == "__main__":
    main()
