#!/usr/bin/env python3
"""Rasterize the site and Studio launcher icons from the site stamp.

Both icons use the square mark in `_includes/theme/site-logo.html` and the
light-on-dark plate of `assets/icons/favicon.svg`: dark frame, pastel triad.
Studio adds a small plate in the lower right. Nothing important sits outside
the maskable safe zone (the center 80% circle). File names match
`lib/pandorga/jekyll/plugins/web_manifest.rb`. Requires Pillow.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

# 32×32 square site stamp.
PRIMARY = [(0, 0), (23, 0), (15, 17), (0, 20)]
SECONDARY = [(23, 0), (32, 0), (32, 32), (17, 21), (15, 17)]
TERTIARY = [(0, 20), (15, 17), (17, 21), (32, 32), (0, 32)]

PLATE = (0x5E, 0x5D, 0x59)
FILL_PRIMARY = (0xA4, 0xC8, 0xDA)
FILL_SECONDARY = (0x95, 0xC8, 0xA6)
FILL_TERTIARY = (0xDD, 0xD8, 0xA8)
BADGE = (0xB8, 0xB7, 0xAE)

# The mark's box is 52% of the canvas. Its corners stay inside the 80% circle
# (half-diagonal 0.367 of the canvas, safe radius 0.40).
MARK_SCALE = 0.52
# Badge center, as an offset from the canvas center, and its side. The badge
# corners stay inside the same circle.
BADGE_OFFSET = 0.18
BADGE_SIDE = 0.09


def _polygon(points: list[tuple[int, int]], size: int) -> list[tuple[float, float]]:
    span = size * MARK_SCALE
    offset = (size - span) / 2
    return [(offset + x / 32 * span, offset + y / 32 * span) for x, y in points]


def render(size: int, studio: bool) -> Image.Image:
    image = Image.new("RGB", (size, size), PLATE)
    draw = ImageDraw.Draw(image)
    draw.polygon(_polygon(PRIMARY, size), fill=FILL_PRIMARY)
    draw.polygon(_polygon(SECONDARY, size), fill=FILL_SECONDARY)
    draw.polygon(_polygon(TERTIARY, size), fill=FILL_TERTIARY)
    if studio:
        side = size * BADGE_SIDE
        center = size * (0.5 + BADGE_OFFSET)
        origin = center - side / 2
        draw.rectangle([origin, origin, origin + side, origin + side], fill=BADGE)
    return image


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    args = parser.parse_args()
    icons = args.repo_root / "assets" / "icons"
    icons.mkdir(parents=True, exist_ok=True)

    site = {
        512: ["icon-512.png", "icon-maskable-512.png"],
        192: ["icon-192.png", "icon-maskable-192.png"],
        180: ["apple-touch-icon.png"],
        32: ["icon-32.png", "favicon-32.png"],
    }
    studio = {
        512: ["studio-icon-512.png", "studio-maskable-512.png"],
        192: ["studio-icon-192.png", "studio-maskable-192.png"],
        180: ["studio-apple-touch-icon.png"],
        32: ["studio-logo-32.png"],
    }
    for size, names in site.items():
        image = render(size, studio=False)
        for name in names:
            image.save(icons / name, "PNG")
    for size, names in studio.items():
        image = render(size, studio=True)
        for name in names:
            image.save(icons / name, "PNG")
    icon32 = render(32, studio=False)
    icon16 = render(16, studio=False)
    icon32.save(
        icons / "favicon.ico",
        format="ICO",
        sizes=[(16, 16), (32, 32)],
        append_images=[icon16],
    )

    print(f"Wrote launcher icons under {icons.relative_to(args.repo_root)}")


if __name__ == "__main__":
    main()
