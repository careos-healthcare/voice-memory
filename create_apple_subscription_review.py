#!/usr/bin/env python3
"""Minimal 1024x1024 RGB PNG for Apple subscription review."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 1024
HEIGHT = 1024
OUTPUT_PATH = Path("/Users/chiragpatel/Desktop/app21/Apple_Subscription_Review_1024.png")

LINE1 = "ArchiveMe Pro"
LINE2 = "Yearly Subscription"


def system_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        [
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        ]
        if bold
        else [
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        ]
    ):
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def block_height(lines: list[str], font: ImageFont.ImageFont, gap: int) -> int:
    probe = ImageDraw.Draw(Image.new("RGB", (WIDTH, HEIGHT)))
    h = 0
    for i, text in enumerate(lines):
        bbox = probe.textbbox((0, 0), text, font=font)
        h += bbox[3] - bbox[1]
        if i < len(lines) - 1:
            h += gap
    return h


def main() -> None:
    if WIDTH != 1024 or HEIGHT != 1024:
        raise SystemExit("Canvas must be 1024x1024")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    font1 = system_font(96, bold=True)
    font2 = system_font(52, bold=False)
    gap = 48

    total_h = block_height([LINE1], font1, 0) + gap + block_height([LINE2], font2, 0)
    y = (HEIGHT - total_h) // 2

    image = Image.new("RGB", (WIDTH, HEIGHT), "#000000")
    draw = ImageDraw.Draw(image)

    for text, font in ((LINE1, font1), (LINE2, font2)):
        bbox = draw.textbbox((0, 0), text, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        draw.text(((WIDTH - tw) // 2, y), text, fill="#FFFFFF", font=font)
        y += th + (gap if text == LINE1 else 0)

    if image.size != (1024, 1024):
        raise SystemExit(f"Pre-save size check failed: {image.size}")

    image.save(OUTPUT_PATH, format="PNG")

    with Image.open(OUTPUT_PATH) as saved:
        if saved.mode != "RGB":
            raise SystemExit(f"Expected RGB, got {saved.mode}")
        w, h = saved.size

    if w != 1024 or h != 1024:
        raise SystemExit(f"Post-save size check failed: {w}x{h}")

    size_bytes = OUTPUT_PATH.stat().st_size
    print(f"width={w}")
    print(f"height={h}")
    print(f"file_size_bytes={size_bytes}")
    print(OUTPUT_PATH.resolve())


if __name__ == "__main__":
    main()
