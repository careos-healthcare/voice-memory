#!/usr/bin/env python3
"""Generate ArchiveMe Pro yearly subscription image (1024x1024)."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 1024
HEIGHT = 1024
BG_COLOR = "#000000"
TEXT_COLOR = "#FFFFFF"

OUTPUT_PATH = Path("/Users/chiragpatel/Desktop/app21/ArchiveMe_Pro_Yearly_1024.png")

TITLE = "ArchiveMe Pro"
BODY = "Premium archive insights\nand discovery tools"
FOOTER = "Yearly Subscription"


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = []
    if bold:
        candidates.extend(
            [
                "/System/Library/Fonts/SFNS.ttf",
                "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                "/System/Library/Fonts/Helvetica.ttc",
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            ]
        )
    else:
        candidates.extend(
            [
                "/System/Library/Fonts/SFNS.ttf",
                "/System/Library/Fonts/Supplemental/Arial.ttf",
                "/System/Library/Fonts/Helvetica.ttc",
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            ]
        )

    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def text_block_height(lines: list[str], font: ImageFont.ImageFont, spacing: int) -> int:
    draw = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    total = 0
    for i, line in enumerate(lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        total += bbox[3] - bbox[1]
        if i < len(lines) - 1:
            total += spacing
    return total


def draw_centered_lines(
    draw: ImageDraw.ImageDraw,
    lines: list[str],
    font: ImageFont.ImageFont,
    y: int,
    line_spacing: int,
) -> int:
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        x = (WIDTH - tw) // 2
        draw.text((x, y), line, font=font, fill=TEXT_COLOR)
        y += th + line_spacing
    return y


def main() -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    title_font = load_font(96, bold=True)
    body_font = load_font(44, bold=False)
    footer_font = load_font(40, bold=False)

    title_lines = [TITLE]
    body_lines = BODY.split("\n")

    gap_title_body = 56
    body_line_spacing = 14

    title_h = text_block_height(title_lines, title_font, 0)
    body_h = text_block_height(body_lines, body_font, body_line_spacing)
    main_h = title_h + gap_title_body + body_h
    y_main = (HEIGHT - main_h) // 2 - 60

    image = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(image)

    y = y_main
    y = draw_centered_lines(draw, title_lines, title_font, y, 0)
    y += gap_title_body
    draw_centered_lines(draw, body_lines, body_font, y, body_line_spacing)

    footer_bbox = draw.textbbox((0, 0), FOOTER, font=footer_font)
    fw = footer_bbox[2] - footer_bbox[0]
    fh = footer_bbox[3] - footer_bbox[1]
    bottom_pad = 120
    draw.text(
        ((WIDTH - fw) // 2, HEIGHT - bottom_pad - fh),
        FOOTER,
        font=footer_font,
        fill=TEXT_COLOR,
    )

    image.save(OUTPUT_PATH, format="PNG")

    with Image.open(OUTPUT_PATH) as saved:
        w, h = saved.size

    if w != WIDTH or h != HEIGHT:
        raise SystemExit(f"Expected {WIDTH}x{HEIGHT}, got {w}x{h}")

    print(OUTPUT_PATH.resolve())
    print(f"{w}x{h}")


if __name__ == "__main__":
    main()
