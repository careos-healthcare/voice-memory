#!/usr/bin/env python3
"""Generate App Store Connect review screenshot (1290x2796)."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 1290
HEIGHT = 2796
BG_COLOR = "#000000"
TEXT_COLOR = "#FFFFFF"

OUTPUT_PATH = Path.home() / "Desktop" / "app21" / "Review_Screenshot_Monthly.png"

TITLE = "ArchiveMe Pro"
BODY = "Premium archive insights\nand discovery tools"
SUBHEAD = "Monthly Subscription"
FOOTER = (
    "VoiceMemory Pro subscription.\n"
    "Unlock archive insights, discovery tools,\n"
    "and advanced archive features."
)


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = []
    if bold:
        candidates.extend(
            [
                "/System/Library/Fonts/SFNS.ttf",
                "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                "/System/Library/Fonts/Helvetica.ttc",
                "/Library/Fonts/Arial Bold.ttf",
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            ]
        )
    else:
        candidates.extend(
            [
                "/System/Library/Fonts/SFNS.ttf",
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


def text_block_height(
    lines: list[str], font: ImageFont.ImageFont, line_spacing: int
) -> int:
    draw = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    total = 0
    for i, line in enumerate(lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        total += bbox[3] - bbox[1]
        if i < len(lines) - 1:
            total += line_spacing
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

    title_font = load_font(118, bold=True)
    body_font = load_font(52, bold=False)
    subhead_font = load_font(44, bold=False)
    footer_font = load_font(34, bold=False)

    title_lines = [TITLE]
    body_lines = BODY.split("\n")
    footer_lines = FOOTER.split("\n")

    gap_title_body = 64
    gap_body_subhead = 80
    title_spacing = 0
    body_spacing = 14
    footer_spacing = 10

    title_h = text_block_height(title_lines, title_font, title_spacing)
    body_h = text_block_height(body_lines, body_font, body_spacing)
    subhead_bbox = ImageDraw.Draw(Image.new("RGB", (1, 1))).textbbox(
        (0, 0), SUBHEAD, font=subhead_font
    )
    subhead_h = subhead_bbox[3] - subhead_bbox[1]

    main_h = title_h + gap_title_body + body_h + gap_body_subhead + subhead_h
    y_main = (HEIGHT - main_h) // 2 - 120

    image = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(image)

    y = y_main
    y = draw_centered_lines(draw, title_lines, title_font, y, title_spacing)
    y += gap_title_body
    y = draw_centered_lines(draw, body_lines, body_font, y, body_spacing)
    y += gap_body_subhead

    bbox = draw.textbbox((0, 0), SUBHEAD, font=subhead_font)
    sw = bbox[2] - bbox[0]
    draw.text(((WIDTH - sw) // 2, y), SUBHEAD, font=subhead_font, fill=TEXT_COLOR)

    footer_h = text_block_height(footer_lines, footer_font, footer_spacing)
    bottom_pad = 140
    y_footer = HEIGHT - bottom_pad - footer_h
    draw_centered_lines(draw, footer_lines, footer_font, y_footer, footer_spacing)

    image.save(OUTPUT_PATH, format="PNG", optimize=True)

    with Image.open(OUTPUT_PATH) as saved:
        w, h = saved.size

    if w != WIDTH or h != HEIGHT:
        raise SystemExit(f"Expected {WIDTH}x{HEIGHT}, got {w}x{h}")

    print(OUTPUT_PATH.resolve())
    print(f"{w}x{h}")


if __name__ == "__main__":
    main()
