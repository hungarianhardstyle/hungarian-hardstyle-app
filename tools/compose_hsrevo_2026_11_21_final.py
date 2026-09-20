from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

W, H = 2048, 1152
ROOT = Path(r"C:\Users\deero\hungarian_hardstyle_app\generated\flyer\hsrevo-2026-11-21-final")
ROOT.mkdir(parents=True, exist_ok=True)
BG = Path(r"C:\Users\deero\.codex\generated_images\01a05dd0-32bb-7aa3-84ab-046195582839\exec-e2d22b6a-6c51-47e7-8e6a-a8146e9d3515.png")
LOGO = Path(r"G:\Denoiser\Cuccok\hsrevo logo white.png")
HUHS = Path(r"G:\Denoiser\Cuccok\HUN HS LOGO Transparent.png")
FONT_DISPLAY = r"C:\Windows\Fonts\AGENCYB.TTF"
FONT_COND = r"C:\Windows\Fonts\AGENCYR.TTF"
FONT_NARROW = r"C:\Windows\Fonts\ARIALNB.TTF"
FONT_STENCIL = r"C:\Windows\Fonts\STENCIL.TTF"

CREAM = (242, 238, 225, 255)
RED = (239, 35, 61, 255)
CYAN = (65, 231, 210, 255)
BLACK = (4, 7, 10, 255)

def font(path, size):
    return ImageFont.truetype(path, size)

def crop_alpha(im):
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    box = im.getbbox()
    return im.crop(box) if box else im

def paste_logo(canvas, path, box, tint=None):
    im = crop_alpha(Image.open(path))
    im.thumbnail((box[2], box[3]), Image.Resampling.LANCZOS)
    if tint:
        alpha = im.getchannel("A")
        solid = Image.new("RGBA", im.size, tint)
        solid.putalpha(alpha)
        im = solid
    canvas.alpha_composite(im, (box[0], box[1]))

def fit_text(draw, text, max_width, start, path=FONT_DISPLAY, spacing=0):
    size = start
    while size > 20:
        f = font(path, size)
        if draw.textbbox((0, 0), text, font=f, spacing=spacing)[2] <= max_width:
            return f
        size -= 2
    return font(path, 20)

def text_center(draw, y, text, f, fill, stroke=0, stroke_fill=BLACK, x0=0, x1=W):
    bb = draw.textbbox((0, 0), text, font=f, stroke_width=stroke)
    x = x0 + ((x1 - x0) - (bb[2] - bb[0])) // 2
    draw.text((x, y), text, font=f, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)
    return (x, y, x + bb[2] - bb[0], y + bb[3] - bb[1])

def base(variant):
    im = Image.open(BG).convert("RGBA")
    im = ImageEnhance.Contrast(im).enhance(1.10)
    im = ImageEnhance.Color(im).enhance(0.92)
    im = im.resize((W, H), Image.Resampling.LANCZOS)
    # Dark central plate for deterministic type readability, retaining the printed edges.
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    if variant == "A":
        od.rectangle((125, 90, 1923, 1054), fill=(0, 0, 0, 48))
        od.polygon([(120, 170), (790, 90), (1110, 1054), (120, 1054)], fill=(0, 0, 0, 35))
    elif variant == "B":
        od.rectangle((95, 84, 1950, 1065), fill=(1, 4, 7, 45))
        od.rectangle((95, 760, 1950, 1065), fill=(0, 0, 0, 90))
    else:
        od.rectangle((100, 80, 1948, 1072), fill=(0, 0, 0, 55))
    return Image.alpha_composite(im, overlay)

ARTISTS = "DENOISER  |  SIDERUNNERS  |  ADAM BASS  |  IMPULZ  |  CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER"
ADDRESS = "STENK  |  1087 BUDAPEST, KEREPESI ÚT"
DATE = "2026.11.21"
TIME = "23:00-05:00"

def variant_a():
    im = base("A"); d = ImageDraw.Draw(im)
    paste_logo(im, LOGO, (145, 118, 330, 116))
    paste_logo(im, HUHS, (1750, 132, 100, 116))
    # Reference 220528/220909 grammar: spaced kicker + rough registration-like display block.
    kicker = font(FONT_COND, 44)
    text_center(d, 270, "H A R D S T Y L E", kicker, CYAN, 1, BLACK, 170, 1878)
    title = fit_text(d, "21", 780, 440, FONT_DISPLAY)
    text_center(d, 335, "21", title, CREAM, 8, BLACK, 155, 1030)
    text_center(d, 548, "NOVEMBER", font(FONT_COND, 82), RED, 2, BLACK, 155, 1030)
    # Offset registration accents are structural, not a generic glow.
    d.line((180, 650, 1000, 650), fill=RED, width=11)
    d.line((205, 665, 1025, 665), fill=CYAN, width=4)
    hook = fit_text(d, "KEEP HARDSTYLE HARDSTYLE", 830, 72, FONT_STENCIL)
    d.text((153, 698), "#KeepHardstyleHardstyle", font=hook, fill=CYAN, stroke_width=2, stroke_fill=BLACK)
    lineup = fit_text(d, ARTISTS, 1770, 52, FONT_COND)
    text_center(d, 842, ARTISTS, lineup, CREAM, 1, BLACK, 120, 1928)
    d.rectangle((130, 942, 1918, 1024), fill=(3, 8, 12, 210))
    data = f"{DATE}   |   {TIME}   |   {ADDRESS}   |   JEGYEK: ONETICKET.HU"
    df = fit_text(d, data, 1720, 41, FONT_NARROW)
    text_center(d, 965, data, df, CREAM, 1, BLACK, 155, 1893)
    return im

def variant_b():
    im = base("B"); d = ImageDraw.Draw(im)
    paste_logo(im, LOGO, (1600, 120, 315, 110))
    paste_logo(im, HUHS, (142, 128, 92, 110))
    # Reference 221210/221015 grammar: central typographic field + spaced secondary line.
    text_center(d, 140, "HARDSTYLE", font(FONT_COND, 48), CYAN, 1, BLACK, 250, 1790)
    f21 = fit_text(d, "21", 780, 500, FONT_DISPLAY)
    text_center(d, 235, "21", f21, CREAM, 6, BLACK, 275, 1773)
    nov = font(FONT_STENCIL, 145)
    text_center(d, 515, "NOV", nov, RED, 3, BLACK, 275, 1773)
    d.line((335, 700, 1710, 700), fill=CREAM, width=5)
    h = fit_text(d, "#KeepHardstyleHardstyle", 920, 66, FONT_DISPLAY)
    text_center(d, 724, "#KeepHardstyleHardstyle", h, CYAN, 2, BLACK, 190, 1858)
    d.rectangle((140, 812, 1908, 925), fill=(2, 5, 8, 195))
    l1 = "DENOISER  |  SIDERUNNERS  |  ADAM BASS  |  IMPULZ"
    l2 = "CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER"
    text_center(d, 829, l1, fit_text(d, l1, 1630, 57, FONT_COND), CREAM, 1, BLACK, 210, 1838)
    text_center(d, 883, l2, fit_text(d, l2, 1420, 57, FONT_COND), CREAM, 1, BLACK, 310, 1738)
    data = f"{DATE}   /   {TIME}   /   {ADDRESS}   /   JEGYEK: ONETICKET.HU"
    df = fit_text(d, data, 1720, 41, FONT_NARROW)
    text_center(d, 970, data, df, CREAM, 1, BLACK, 155, 1893)
    return im

def variant_c():
    im = base("C"); d = ImageDraw.Draw(im)
    paste_logo(im, LOGO, (150, 130, 345, 120))
    paste_logo(im, HUHS, (1788, 130, 92, 112))
    # Reference 221119 / 230114 grammar: giant central word treatment, restrained grid, compact rails.
    text_center(d, 125, "21 / 11 / 26", font(FONT_COND, 43), CYAN, 1, BLACK, 150, 1890)
    # Large custom letterform-like block built from exact date text; no invented headline.
    datef = fit_text(d, DATE, 1600, 186, FONT_DISPLAY)
    bb = d.textbbox((0, 0), DATE, font=datef, stroke_width=2)
    x = (W - (bb[2] - bb[0])) // 2
    d.text((x + 12, 300), DATE, font=datef, fill=CYAN, stroke_width=2, stroke_fill=BLACK)
    d.text((x, 286), DATE, font=datef, fill=CREAM, stroke_width=2, stroke_fill=BLACK)
    d.line((320, 600, 1728, 600), fill=RED, width=13)
    d.line((320, 620, 1728, 620), fill=CYAN, width=3)
    artists = "DENOISER  /  SIDERUNNERS  /  ADAM BASS  /  IMPULZ  /  CAPITAL NOISE  /  DR FOLLI  /  NOIZEMAKER"
    text_center(d, 670, artists, fit_text(d, artists, 1700, 49, FONT_COND), CREAM, 1, BLACK, 150, 1898)
    tag = fit_text(d, "#KeepHardstyleHardstyle", 720, 65, FONT_STENCIL)
    d.text((170, 755), "#KeepHardstyleHardstyle", font=tag, fill=RED, stroke_width=2, stroke_fill=BLACK)
    d.rectangle((135, 890, 1913, 1015), fill=(1, 5, 8, 205))
    d.text((175, 916), TIME, font=font(FONT_DISPLAY, 66), fill=CYAN, stroke_width=1, stroke_fill=BLACK)
    info = f"STENK  |  1087 BUDAPEST, KEREPESI ÚT  |  JEGYEK: ONETICKET.HU"
    text_center(d, 935, info, fit_text(d, info, 1300, 39, FONT_NARROW), CREAM, 1, BLACK, 585, 1878)
    return im

for label, maker in (("A", variant_a), ("B", variant_b), ("C", variant_c)):
    out = ROOT / f"hsrevo-2026-11-21-{label}.png"
    maker().convert("RGB").save(out, quality=95, optimize=True)
    print(out)
