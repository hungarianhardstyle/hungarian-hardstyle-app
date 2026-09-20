from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"C:\Users\deero\hungarian_hardstyle_app\generated\flyer\hardstyle-revolution-2026-11-21")
W, H = 1920, 1080
CREAM = (241, 237, 225, 255)
RED = (214, 24, 55, 255)
CYAN = (32, 194, 204, 255)
BLACK = (7, 8, 10, 255)
MUTED = (190, 189, 179, 255)

F_AGENCY = r"C:\Windows\Fonts\AGENCYB.TTF"
F_BAHN = r"C:\Windows\Fonts\bahnschrift.ttf"
F_ARIALN = r"C:\Windows\Fonts\ARIALN.TTF"
F_ARIALNB = r"C:\Windows\Fonts\ARIALNB.TTF"

def font(path, size):
    return ImageFont.truetype(path, size)

def paste_logo(base, path, xy, target_w):
    logo = Image.open(path).convert("RGBA")
    bbox = logo.getbbox()
    logo = logo.crop(bbox)  # only fully transparent outer margin
    ratio = target_w / logo.width
    logo = logo.resize((target_w, int(logo.height * ratio)), Image.Resampling.LANCZOS)
    base.alpha_composite(logo, xy)
    return logo.size

def text(draw, xy, value, f, fill=CREAM, anchor=None, stroke=0):
    draw.text(xy, value, font=f, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=BLACK)

def wrap(draw, value, f, max_w):
    words = value.split()
    lines, cur = [], ""
    for word in words:
        test = f"{cur} {word}".strip()
        if cur and draw.textbbox((0, 0), test, font=f)[2] > max_w:
            lines.append(cur); cur = word
        else:
            cur = test
    if cur: lines.append(cur)
    return lines

def footer(draw, variant):
    f = font(F_ARIALNB, 26)
    y = 963
    draw.line((120, y-24, 1800, y-24), fill=RED if variant != 1 else CYAN, width=3)
    text(draw, (120, y), "23:00—05:00", f, RED if variant != 1 else CYAN)
    text(draw, (350, y), "STENK", f)
    text(draw, (520, y), "CÍM: 1087 BUDAPEST, KEREPESI ÚT", f)
    text(draw, (1310, y), "JEGYEK: ONETICKET.HU", f)
    text(draw, (120, 1013), "#KeepHardstyleHardstyle", font(F_ARIALN, 24), MUTED)

def logos(base, variant):
    revo = r"G:\Denoiser\Cuccok\hsrevo logo white.png"
    huhs = r"G:\Denoiser\Cuccok\HUN HS LOGO Transparent.png"
    if variant == 0:
        paste_logo(base, revo, (126, 92), 360)
        paste_logo(base, huhs, (1602, 887), 205)
    elif variant == 1:
        paste_logo(base, huhs, (126, 90), 190)
        paste_logo(base, revo, (1578, 88), 250)
    else:
        paste_logo(base, revo, (126, 86), 300)
        paste_logo(base, huhs, (1610, 890), 200)

def render(name, background, variant):
    base = Image.open(ROOT / background).convert("RGBA").resize((W, H), Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(base)
    logos(base, variant)

    # A calm translucent reading field is structure, not a decorative card.
    if variant == 0:
        draw.rectangle((90, 235, 930, 900), fill=(7, 8, 10, 180))
        f_num = font(F_AGENCY, 370)
        text(draw, (120, 250), "21", f_num, RED)
        text(draw, (122, 590), "NOVEMBER", font(F_AGENCY, 88), CREAM)
        text(draw, (122, 680), "2026", font(F_BAHN, 48), CYAN)
        draw.line((124, 754, 800, 754), fill=CREAM, width=5)
        text(draw, (121, 790), "23:00—05:00", font(F_ARIALNB, 42), CREAM)
        lineups = ["DENOISER", "SIDERUNNERS", "ADAM BASS", "IMPULZ", "CAPITAL NOISE", "DR FOLLI", "NOIZEMAKER"]
        text(draw, (1040, 245), "LINE-UP", font(F_ARIALN, 28), RED)
        y = 304
        for i, artist in enumerate(lineups):
            text(draw, (1040, y), artist, font(F_AGENCY, 66 if i < 3 else 53), CREAM if i < 3 else MUTED)
            y += 74 if i < 3 else 62
    elif variant == 1:
        draw.rectangle((86, 180, 1834, 920), fill=(4, 10, 18, 128))
        text(draw, (960, 220), "21 / 11 / 2026", font(F_BAHN, 58), CYAN, anchor="ma")
        text(draw, (110, 330), "HARDSTYLE", font(F_AGENCY, 160), CREAM)
        text(draw, (110, 475), "REVOLUTION", font(F_AGENCY, 160), RED)
        draw.line((116, 660, 1810, 660), fill=CYAN, width=4)
        lineups = "DENOISER  |  SIDERUNNERS  |  ADAM BASS  |  IMPULZ  |  CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER"
        lines = wrap(draw, lineups, font(F_ARIALNB, 34), 1650)
        y = 700
        for line in lines:
            text(draw, (110, y), line, font(F_ARIALNB, 34), CREAM); y += 44
        text(draw, (110, 820), "23:00—05:00   /   STENK   /   1087 BUDAPEST, KEREPESI ÚT", font(F_BAHN, 32), MUTED)
        text(draw, (110, 872), "JEGYEK: ONETICKET.HU", font(F_ARIALNB, 28), CYAN)
    else:
        draw.rectangle((90, 220, 1060, 900), fill=(5, 6, 8, 178))
        text(draw, (125, 265), "21", font(F_AGENCY, 430), CREAM)
        text(draw, (465, 312), "NOV", font(F_AGENCY, 120), RED)
        text(draw, (465, 435), "2026", font(F_BAHN, 72), CYAN)
        text(draw, (115, 740), "STENK", font(F_AGENCY, 100), RED)
        text(draw, (120, 835), "23:00—05:00", font(F_ARIALNB, 34), CREAM)
        text(draw, (1250, 220), "DENOISER", font(F_AGENCY, 83), CREAM)
        text(draw, (1250, 320), "SIDERUNNERS", font(F_AGENCY, 70), CREAM)
        text(draw, (1250, 420), "ADAM BASS", font(F_AGENCY, 70), CREAM)
        text(draw, (1250, 530), "IMPULZ", font(F_AGENCY, 70), RED)
        text(draw, (1250, 640), "CAPITAL NOISE", font(F_AGENCY, 60), MUTED)
        text(draw, (1250, 735), "DR FOLLI  /  NOIZEMAKER", font(F_ARIALNB, 37), MUTED)
        text(draw, (1250, 820), "1087 BUDAPEST, KEREPESI ÚT", font(F_ARIALN, 28), CREAM)
        text(draw, (1250, 865), "JEGYEK: ONETICKET.HU", font(F_ARIALNB, 26), CYAN)
    if variant == 0:
        footer(draw, variant)
    else:
        text(draw, (120, 1013), "#KeepHardstyleHardstyle", font(F_ARIALN, 24), MUTED)
    out = ROOT / name
    base.convert("RGB").save(out, quality=96, optimize=True)
    return out

for args in [
    ("hardstyle-revolution-facebook-v1.png", "base-red.png", 0),
    ("hardstyle-revolution-facebook-v2.png", "base-club.png", 1),
    ("hardstyle-revolution-facebook-v3.png", "base-circle.png", 2),
]:
    print(render(*args))
