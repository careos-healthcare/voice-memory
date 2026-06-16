#!/usr/bin/env python3
"""App Store review screenshot — VoiceMemory yearly subscription screen (1024x1024)."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 1024
HEIGHT = 1024
OUTPUT_PATH = Path("/Users/chiragpatel/Desktop/app21/Review_Screenshot_Yearly.png")

# iOS dark premium palette
BG = "#000000"
SURFACE = "#1C1C1E"
SURFACE_ELEVATED = "#2C2C2E"
TEXT_PRIMARY = "#FFFFFF"
TEXT_SECONDARY = "#AEAEB2"
TEXT_TERTIARY = "#636366"
ACCENT = "#5E5CE6"
DIVIDER = "#38383A"

APP_TITLE = "VoiceMemory"
HERO_TITLE = "ArchiveMe Pro"
HERO_BODY = "Premium archive insights\nand discovery tools"
BENEFITS = [
    "Belief evolution tracking",
    "Archive search",
    "Evidence timeline",
    "Long-term memory archive",
]
PLAN_LABEL = "Yearly Subscription"
PLAN_PRICE = "£59.99/year"


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    paths = (
        [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        ]
        if bold
        else [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
        ]
    )
    paths += ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
    for p in paths:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                continue
    return ImageFont.load_default()


def rounded_rect(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int, int, int],
    radius: int,
    fill: str,
) -> None:
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def draw_centered(
    draw: ImageDraw.ImageDraw,
    y: int,
    text: str,
    font: ImageFont.ImageFont,
    fill: str,
) -> int:
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (WIDTH - tw) // 2
    draw.text((x, y), text, font=font, fill=fill)
    return th


def draw_status_bar(draw: ImageDraw.ImageDraw) -> None:
    font = load_font(28, bold=False)
    draw.text((48, 52), "9:41", font=font, fill=TEXT_PRIMARY)
    # Minimal signal/battery glyphs (simple shapes, not placeholder boxes)
    bx = WIDTH - 48
    draw.rounded_rectangle((bx - 44, 58, bx, 72), radius=4, fill=TEXT_TERTIARY)
    draw.rounded_rectangle((bx - 72, 60, bx - 50, 70), radius=2, fill=TEXT_SECONDARY)
    draw.ellipse((bx - 96, 56, bx - 78, 74), outline=TEXT_SECONDARY, width=2)


def main() -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    img = Image.new("RGB", (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(img)

    draw_status_bar(draw)

    nav_font = load_font(34, bold=False)
    th = draw_centered(draw, 108, APP_TITLE, nav_font, TEXT_SECONDARY)

    # Hero card
    card_margin = 56
    card_top = 200
    card_w = WIDTH - card_margin * 2
    card_h = 520
    card_left = card_margin
    rounded_rect(
        draw,
        (card_left, card_top, card_left + card_w, card_top + card_h),
        radius=28,
        fill=SURFACE,
    )

    hero_font = load_font(72, bold=True)
    body_font = load_font(40, bold=False)
    benefit_font = load_font(36, bold=False)
    bullet_font = load_font(36, bold=True)

    y = card_top + 56
    y += draw_centered(draw, y, HERO_TITLE, hero_font, TEXT_PRIMARY) + 28

    for line in HERO_BODY.split("\n"):
        y += draw_centered(draw, y, line, body_font, TEXT_SECONDARY) + 8
    y += 36

    draw.line(
        (card_left + 48, y, card_left + card_w - 48, y),
        fill=DIVIDER,
        width=2,
    )
    y += 40

    for benefit in BENEFITS:
        row_y = y
        bullet_x = card_left + 64
        draw.text((bullet_x, row_y), "•", font=bullet_font, fill=ACCENT)
        draw.text(
            (bullet_x + 36, row_y),
            benefit,
            font=benefit_font,
            fill=TEXT_PRIMARY,
        )
        bbox = draw.textbbox((0, 0), benefit, font=benefit_font)
        y += (bbox[3] - bbox[1]) + 28

    # Bottom subscription panel
    panel_h = 200
    panel_top = HEIGHT - panel_h - 48
    rounded_rect(draw, (card_margin, panel_top, WIDTH - card_margin, HEIGHT - 48), 24, SURFACE_ELEVATED)

    plan_font = load_font(44, bold=True)
    price_font = load_font(52, bold=True)
    sub_font = load_font(32, bold=False)

    py = panel_top + 40
    py += draw_centered(draw, py, PLAN_LABEL, plan_font, TEXT_PRIMARY) + 16
    draw_centered(draw, py, PLAN_PRICE, price_font, ACCENT)

    # Subtle home indicator
    ind_w = 280
    ind_h = 10
    ind_x = (WIDTH - ind_w) // 2
    ind_y = HEIGHT - 28
    draw.rounded_rectangle(
        (ind_x, ind_y, ind_x + ind_w, ind_y + ind_h),
        radius=5,
        fill=TEXT_TERTIARY,
    )

    img.save(OUTPUT_PATH, format="PNG")

    with Image.open(OUTPUT_PATH) as saved:
        w, h = saved.size

    if w != WIDTH or h != HEIGHT:
        raise SystemExit(f"Expected {WIDTH}x{HEIGHT}, got {w}x{h}")

    print(OUTPUT_PATH.resolve())
    print(f"{w}x{h}")


if __name__ == "__main__":
    main()
