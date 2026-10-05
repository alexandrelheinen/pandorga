#!/usr/bin/env python3
"""Rasterize the Studio hexagon for the Android shell icons.

Geometry and light-scheme fills match assets/icons/studio-logo.svg.
Requires Pillow. Writes 1024px PNGs under studio-mobile/assets/.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"

# 32×32 viewBox from assets/icons/studio-logo.svg (light scheme).
PRIMARY = [(16, 1), (24, 5), (13, 14), (2, 17), (2, 9)]
SECONDARY = [(24, 5), (30, 9), (30, 23), (22, 28), (19, 18), (13, 14)]
TERTIARY = [(2, 17), (13, 14), (19, 18), (22, 28), (16, 31), (2, 23)]
FRAME = [(16, 1), (30, 9), (30, 23), (16, 31), (2, 23), (2, 9)]

FILL_PRIMARY = "#a4c8da"
FILL_SECONDARY = "#95c8a6"
FILL_TERTIARY = "#ddd8a8"
STROKE_FRAME = "#5e5d59"
VIEWBOX = 32
SIZE = 1024


def _map(
    points: list[tuple[int, int]], span: float, offset: float
) -> list[tuple[float, float]]:
    factor = span / VIEWBOX
    return [(offset + x * factor, offset + y * factor) for x, y in points]


def _draw(base: Image.Image, span: float) -> None:
    offset = (SIZE - span) / 2
    draw = ImageDraw.Draw(base)
    frame = _map(FRAME, span, offset)
    draw.polygon(frame, fill=STROKE_FRAME)
    cx = sum(point[0] for point in frame) / len(frame)
    cy = sum(point[1] for point in frame) / len(frame)
    inset = 0.045

    def shrink(points: list[tuple[int, int]]) -> list[tuple[float, float]]:
        mapped = _map(points, span, offset)
        return [
            (cx + (x - cx) * (1 - inset), cy + (y - cy) * (1 - inset))
            for x, y in mapped
        ]

    draw.polygon(shrink(PRIMARY), fill=FILL_PRIMARY)
    draw.polygon(shrink(SECONDARY), fill=FILL_SECONDARY)
    draw.polygon(shrink(TERTIARY), fill=FILL_TERTIARY)


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)

    icon = Image.new("RGB", (SIZE, SIZE), "#ffffff")
    _draw(icon, SIZE * 0.72)
    icon.save(ASSETS / "icon.png", "PNG")

    splash = Image.new("RGB", (SIZE, SIZE), "#ffffff")
    _draw(splash, SIZE * 0.46)
    splash.save(ASSETS / "splash.png", "PNG")

    # Adaptive foreground keeps the mark inside the center 66% safe zone.
    adaptive = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _draw(adaptive, SIZE * 0.62)
    adaptive.save(ASSETS / "adaptive-icon.png", "PNG")

    print("Wrote icon.png, splash.png, adaptive-icon.png")


if __name__ == "__main__":
    main()
