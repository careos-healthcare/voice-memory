#!/usr/bin/env python3
"""Generate ArchiveMe Pro monthly subscription marketing image (1024x1024)."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 1024
HEIGHT = 1024
BG_COLOR = "#000000"
TEXT_COLOR = "#FFFFFF"

OUTPUT_PATH = Path.home() / "Desktop" / "app21" / "ArchiveMe_Pro_Monthly_1024.png"

TITLE = "ArchiveMe Pro"
BODY = "Premium archive insights\nand discovery tools"
FOOTER = "Monthly Subscription"


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = []
    if bold:
        candidates.extend(
            [
                "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                "/System/Library/Fonts/Helvetica.ttc",
                "/Library/Fonts/Arial Bold.ttf",
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            ]
        )
    else:
        candidates.extend(
            [
                "/System/Library/Fonts/Supplemental/Arial.ttf",
                "/System/Library/Fonts/Helvetica.ttc",
                "/Library/Fonts/Arial.ttf",
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


def draw_centered_block(
    draw: ImageDraw.ImageDraw,
    lines: list[str],
    font: ImageFont.ImageFont,
    y_start: int,
    line_spacing: int,
) -> int:
    y = y_start
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
    footer_font = load_font(36, bold=False)

    title_lines = [TITLE]
    body_lines = BODY.split("\n")

    gap_after_title = 56
    gap_after_body = 72
    title_line_spacing = 8
    body_line_spacing = 12

    title_h = text_block_height(title_lines, title_font, title_line_spacing)
    body_h = text_block_height(body_lines, body_font, body_line_spacing)
    footer_bbox = ImageDraw.Draw(Image.new("RGB", (1, 1))).textbbox(
        (0, 0), FOOTER, font=footer_font
    )
    footer_h = footer_bbox[3] - footer_bbox[1]

    total_h = title_h + gap_after_title + body_h + gap_after_body + footer_h
    y = (HEIGHT - total_h) // 2

    image = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(image)

    y = draw_centered_block(draw, title_lines, title_font, y, title_line_spacing)
    y += gap_after_title
    y = draw_centered_block(draw, body_lines, body_font, y, body_line_spacing)
    y += gap_after_body

    footer_bbox = draw.textbbox((0, 0), FOOTER, font=footer_font)
    fw = footer_bbox[2] - footer_bbox[0]
    draw.text(((WIDTH - fw) // 2, y), FOOTER, font=footer_font, fill=TEXT_COLOR)

    image.save(OUTPUT_PATH, format="PNG")

    with Image.open(OUTPUT_PATH) as saved:
        w, h = saved.size

    if w != WIDTH or h != HEIGHT:
        raise SystemExit(f"Expected {WIDTH}x{HEIGHT}, got {w}x{h}")

    print(OUTPUT_PATH.resolve())
    print(f"{w}x{h}")


if __name__ == "__main__":
    main()
