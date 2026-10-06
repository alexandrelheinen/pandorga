#!/usr/bin/env python3
"""Rasterize launcher icons for the Studio and Website Expo shells.

Studio uses the hex mark (stroke frame, pastel fills). Website uses the square
site logo from `_includes/theme/site-logo.html`. Requires Pillow.

Writes 1024px PNGs under `studio-mobile/assets/studio/` and
`studio-mobile/assets/website/`.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

# 32×32 hex viewBox (Studio mark, light scheme fills).
STUDIO_PRIMARY = [(16, 1), (24, 5), (13, 14), (2, 17), (2, 9)]
STUDIO_SECONDARY = [(24, 5), (30, 9), (30, 23), (22, 28), (19, 18), (13, 14)]
STUDIO_TERTIARY = [(2, 17), (13, 14), (19, 18), (22, 28), (16, 31), (2, 23)]
STUDIO_FRAME = [(16, 1), (30, 9), (30, 23), (16, 31), (2, 23), (2, 9)]

# 32×32 square site logo (_includes/theme/site-logo.html).
WEBSITE_PRIMARY = [(0, 0), (23, 0), (15, 17), (0, 20)]
WEBSITE_SECONDARY = [(23, 0), (32, 0), (32, 32), (17, 21), (15, 17)]
WEBSITE_TERTIARY = [(0, 20), (15, 17), (17, 21), (32, 32), (0, 32)]
WEBSITE_FRAME = [(1, 1), (31, 1), (31, 31), (1, 31)]

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


def _stroke_polygon(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    color: str,
    width: int,
) -> None:
    closed = points + [points[0]]
    for start, end in zip(closed, closed[1:]):
        draw.line([start, end], fill=color, width=width)


def _draw_mark(
    base: Image.Image,
    span: float,
    primary: list[tuple[int, int]],
    secondary: list[tuple[int, int]],
    tertiary: list[tuple[int, int]],
    frame: list[tuple[int, int]],
) -> None:
    offset = (SIZE - span) / 2
    draw = ImageDraw.Draw(base)
    mapped_frame = _map(frame, span, offset)
    cx = sum(point[0] for point in mapped_frame) / len(mapped_frame)
    cy = sum(point[1] for point in mapped_frame) / len(mapped_frame)
    inset = 0.045

    def shrink(points: list[tuple[int, int]]) -> list[tuple[float, float]]:
        mapped = _map(points, span, offset)
        return [
            (cx + (x - cx) * (1 - inset), cy + (y - cy) * (1 - inset))
            for x, y in mapped
        ]

    draw.polygon(shrink(primary), fill=FILL_PRIMARY)
    draw.polygon(shrink(secondary), fill=FILL_SECONDARY)
    draw.polygon(shrink(tertiary), fill=FILL_TERTIARY)
    stroke_w = max(2, int(span * 0.028))
    _stroke_polygon(draw, mapped_frame, STROKE_FRAME, stroke_w)


def _write_set(
    target: Path,
    primary: list[tuple[int, int]],
    secondary: list[tuple[int, int]],
    tertiary: list[tuple[int, int]],
    frame: list[tuple[int, int]],
    scales: tuple[float, float, float],
) -> None:
    target.mkdir(parents=True, exist_ok=True)
    icon_scale, splash_scale, adaptive_scale = scales

    icon = Image.new("RGB", (SIZE, SIZE), "#ffffff")
    _draw_mark(icon, SIZE * icon_scale, primary, secondary, tertiary, frame)
    icon.save(target / "icon.png", "PNG")

    splash = Image.new("RGB", (SIZE, SIZE), "#ffffff")
    _draw_mark(splash, SIZE * splash_scale, primary, secondary, tertiary, frame)
    splash.save(target / "splash.png", "PNG")

    adaptive = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _draw_mark(adaptive, SIZE * adaptive_scale, primary, secondary, tertiary, frame)
    adaptive.save(target / "adaptive-icon.png", "PNG")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Pandorga repository root (parent of studio-mobile/)",
    )
    args = parser.parse_args()
    mobile_root = args.repo_root / "studio-mobile"
    studio_assets = mobile_root / "assets" / "studio"
    website_assets = mobile_root / "assets" / "website"
    scales = (0.72, 0.46, 0.62)

    _write_set(
        studio_assets,
        STUDIO_PRIMARY,
        STUDIO_SECONDARY,
        STUDIO_TERTIARY,
        STUDIO_FRAME,
        scales,
    )
    _write_set(
        website_assets,
        WEBSITE_PRIMARY,
        WEBSITE_SECONDARY,
        WEBSITE_TERTIARY,
        WEBSITE_FRAME,
        scales,
    )

    print(f"Wrote Studio icons under {studio_assets.relative_to(args.repo_root)}")
    print(f"Wrote Website icons under {website_assets.relative_to(args.repo_root)}")


if __name__ == "__main__":
    main()
