# Generates the 声阅 launcher icon (Android mipmaps + adaptive layers).
#
# Design: warm-paper card (#FBF6EA) with a pine-green serif 「声」 glyph,
# a terracotta bookmark ribbon dropping from the top-right, and soft page
# edges — matching the app's PaperPalette tokens (see
# lib/app/design/paper_tokens.dart).
#
# Usage: python tool/make_app_icon.py
# Requires: Pillow
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024

PAPER = (0xFB, 0xF6, 0xEA, 255)  # PaperPalette.surface
PAPER_EDGE = (0xE4, 0xD9, 0xC1, 255)  # PaperPalette.divider — page edges
BRAND = (0x2E, 0x5E, 0x4E, 255)  # PaperPalette.brand — pine
ACCENT = (0xC4, 0x70, 0x3A, 255)  # PaperPalette.accent — terracotta bookmark

# Adaptive-icon safe zone: the inner 66% circle must contain the glyph,
# so keep the mark well inside the canvas.
FONT = ImageFont.truetype(
    str(ROOT / "assets/fonts/NotoSerifSC-Regular.ttf"), int(SIZE * 0.52)
)


def rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def build_icon() -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Paper card with generous margin so legacy icons don't touch the mask.
    margin = int(SIZE * 0.045)
    radius = int(SIZE * 0.21)
    card = (margin, margin, SIZE - margin, SIZE - margin)
    # Soft drop shadow.
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (card[0] + 6, card[1] + 14, card[2] + 6, card[3] + 14),
        radius=radius,
        fill=(60, 45, 25, 70),
    ).image if False else None
    img.alpha_composite(shadow.filter(__import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(18)))
    rounded_rect(d, card, radius, PAPER)

    # Page edges: two faint horizontal rules near the bottom, like stacked
    # pages under the glyph. Pre-blended against the paper color because
    # ImageDraw writes RGBA values without compositing.
    def blend(alpha):
        a = alpha / 255
        return tuple(int(PAPER[i] * (1 - a) + PAPER_EDGE[i] * a) for i in range(3))

    for i, alpha in ((0, 90), (1, 50)):
        y = int(SIZE * (0.80 + 0.035 * i))
        d.rounded_rectangle(
            (int(SIZE * 0.17), y, int(SIZE * 0.83), y + int(SIZE * 0.016)),
            radius=int(SIZE * 0.008),
            fill=blend(alpha),
        )

    # Terracotta bookmark ribbon from the top edge, clear of the glyph.
    bx = int(SIZE * 0.72)
    bw = int(SIZE * 0.115)
    notch = int(SIZE * 0.045)
    tip = int(SIZE * 0.42)
    d.polygon(
        [
            (bx, margin),
            (bx + bw, margin),
            (bx + bw, tip),
            (bx + bw // 2, tip - notch),
            (bx, tip),
        ],
        fill=ACCENT,
    )

    # The 「声」 glyph in pine green, optically centered slightly above middle
    # (the page rules below balance it).
    glyph = "声"
    left, top, right, bottom = FONT.getbbox(glyph)
    gw, gh = right - left, bottom - top
    x = int(SIZE * 0.46) - gw // 2 - left
    y = int(SIZE * 0.47) - gh // 2 - top
    d.text((x, y), glyph, font=FONT, fill=BRAND)

    return img


def build_foreground() -> Image.Image:
    # Adaptive-icon foreground: same mark on transparency, scaled into the
    # 66% safe zone (draw at 2/3 size, centered on 108dp canvas convention).
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    mark = build_icon()
    inner = mark.crop((margin := int(SIZE * 0.045), margin, SIZE - margin, SIZE - margin))
    scale = 0.66
    w = int(inner.width * scale)
    inner = inner.resize((w, w), Image.LANCZOS)
    img.alpha_composite(inner, ((SIZE - w) // 2, (SIZE - w) // 2))
    return img


def main() -> None:
    icon = build_icon()
    icon.save(ROOT / "assets/icon/app-icon.png")

    fg = build_foreground()
    fg.save(ROOT / "assets/icon/app-icon-foreground.png")

    # Adaptive background: plain paper.
    Image.new("RGBA", (SIZE, SIZE), PAPER).save(
        ROOT / "assets/icon/app-icon-background.png"
    )

    out = ROOT / "android/app/src/main/res"
    sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    adaptive_sizes = {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }
    for density, px in sizes.items():
        folder = out / f"mipmap-{density}"
        folder.mkdir(exist_ok=True)
        icon.resize((px, px), Image.LANCZOS).save(folder / "ic_launcher.png")
        icon.resize((px, px), Image.LANCZOS).save(folder / "ic_launcher_round.png")
    for density, px in adaptive_sizes.items():
        folder = out / f"mipmap-{density}"
        fg.resize((px, px), Image.LANCZOS).save(folder / "ic_launcher_foreground.png")
        Image.new("RGBA", (px, px), PAPER).save(
            folder / "ic_launcher_background.png"
        )

    print("icon written")


if __name__ == "__main__":
    main()
