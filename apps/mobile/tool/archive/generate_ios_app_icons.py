#!/usr/bin/env python3
"""Regenerate iOS AppIcon.appiconset from the ArchiveMe master icon."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets" / "branding" / "app_icon_master_1024.png"
ICONSET = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

# filename -> square pixel size
ICON_SIZES: dict[str, int] = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

BACKGROUND = (12, 22, 42)


def load_master(path: Path) -> Image.Image:
    source = Image.open(path).convert("RGBA")
    background = Image.new("RGBA", source.size, (*BACKGROUND, 255))
    flattened = Image.alpha_composite(background, source).convert("RGB")
    if flattened.size != (1024, 1024):
        flattened = flattened.resize((1024, 1024), Image.Resampling.LANCZOS)
    return flattened


def write_master(source_path: Path, destination: Path) -> Image.Image:
    master = load_master(source_path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    master.save(destination, format="PNG", optimize=True)
    return master


def generate_iconset(master: Image.Image, iconset_dir: Path) -> None:
    iconset_dir.mkdir(parents=True, exist_ok=True)
    for filename, size in ICON_SIZES.items():
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(iconset_dir / filename, format="PNG", optimize=True)


def main() -> None:
    source = ICONSET / "Icon-App-1024x1024@1x.png"
    if not source.exists():
        raise SystemExit(f"Missing source icon: {source}")

    master = write_master(source, MASTER)
    generate_iconset(master, ICONSET)
    print(f"Wrote master icon: {MASTER}")
    print(f"Regenerated {len(ICON_SIZES)} files in {ICONSET}")


if __name__ == "__main__":
    main()
