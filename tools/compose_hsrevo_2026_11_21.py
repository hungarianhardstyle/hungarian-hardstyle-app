from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
from pathlib import Path

W, H = 2048, 1152
OUT = Path(r"C:\Users\deero\hungarian_hardstyle_app\generated\flyer\hsrevo-2026-11-21")
OUT.mkdir(parents=True, exist_ok=True)
BG = Path(r"C:\Users\deero\.codex\generated_images\01a05dd0-32bb-7aa3-84ab-046195582839\exec-d2d226b1-bd59-4708-a5b5-5b95ac50ec09.png")
HS = Path(r"G:\Denoiser\Cuccok\HUN HS LOGO Transparent.png")
REVO = Path(r"G:\Denoiser\Cuccok\hsrevo logo white.png")
FONT_DISPLAY = r"C:\Windows\Fonts\AGENCYB.TTF"
FONT_NARROW = r"C:\Windows\Fonts\ARIALN.TTF"
FONT_NARROW_B = r"C:\Windows\Fonts\ARIALNB.TTF"

LIME = (205, 255, 28, 255)
CREAM = (241, 239, 226, 255)
INK = (5, 10, 12, 235)
CYAN = (42, 196, 205, 255)

def font(path, size):
    return ImageFont.truetype(path, size)

def trim_logo(path):
    im = Image.open(path).convert("RGBA")
    alpha = im.getchannel("A")
    box = alpha.getbbox()
    return im.crop(box) if box else im

def fit(im, max_w, max_h):
    scale = min(max_w / im.width, max_h / im.height)
    return im.resize((int(im.width * scale), int(im.height * scale)), Image.Resampling.LANCZOS)

def text(draw, xy, s, f, fill=CREAM, anchor=None, stroke=0, stroke_fill=(0,0,0,0), spacing=4):
    draw.multiline_text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=stroke_fill, spacing=spacing)

def centered(draw, box, s, f, fill=CREAM, stroke=0, stroke_fill=(0,0,0,0)):
    x0,y0,x1,y1=box
    bb=draw.multiline_textbbox((0,0),s,font=f,spacing=0,stroke_width=stroke)
    x=(x0+x1-(bb[2]-bb[0]))/2
    y=(y0+y1-(bb[3]-bb[1]))/2
    text(draw,(x,y),s,f,fill,stroke=stroke,stroke_fill=stroke_fill)

def add_texture(im):
    # restrained second material: a very light paper/grain pass, not decorative clutter
    grain = Image.effect_noise((W,H), 10).convert("L").filter(ImageFilter.GaussianBlur(0.35))
    grain = ImageEnhance.Contrast(grain).enhance(1.25)
    overlay = Image.new("RGBA", (W,H), (210,220,205,0))
    overlay.putalpha(grain.point(lambda p: int(p * 0.055)))
    return Image.alpha_composite(im.convert("RGBA"), overlay)

def base():
    im = Image.open(BG).convert("RGBA").resize((W,H), Image.Resampling.LANCZOS)
    # keep type zones dark and readable while preserving the generated atmosphere
    shade = Image.new("RGBA", (W,H), (0,0,0,0))
    sd = ImageDraw.Draw(shade)
    sd.rectangle((0,0,1170,H), fill=(0,4,7,55))
    sd.rectangle((0,900,W,H), fill=(0,3,5,115))
    return add_texture(Image.alpha_composite(im, shade))

def logos(im, variant):
    layer = Image.new("RGBA", (W,H), (0,0,0,0))
    # Both supplied logos remain untouched as assets; only transparent outer margins are trimmed.
    revo = fit(trim_logo(REVO), 290, 110)
    hun = fit(trim_logo(HS), 190, 85)
    if variant == 1:
        layer.alpha_composite(revo, (1550, 115))
        layer.alpha_composite(hun, (165, 945))
    elif variant == 2:
        layer.alpha_composite(revo, (1550, 112))
        layer.alpha_composite(hun, (1760, 972))
    else:
        layer.alpha_composite(revo, (150, 105))
        layer.alpha_composite(hun, (1710, 972))
    return Image.alpha_composite(im, layer)

ARTISTS = ["DENOISER", "SIDERUNNERS", "ADAM BASS", "IMPULZ", "CAPITAL NOISE", "DR FOLLI", "NOIZEMAKER"]

def info_rail(d, variant):
    # Deliberately high enough for Facebook crop safety; no critical copy touches the bottom edge.
    y = 1012
    if variant == 1:
        text(d,(415,y),"2026.11.21",font(FONT_DISPLAY,48),LIME)
        text(d,(540,y+4),"23:00-05:00   |   STENK   |   1087 BUDAPEST, KEREPESI ÚT",font(FONT_NARROW_B,27),CREAM)
        text(d,(1510,y+4),"JEGYEK: ONETICKET.HU",font(FONT_NARROW_B,25),LIME)
    elif variant == 2:
        text(d,(165,y),"2026.11.21",font(FONT_DISPLAY,46),CREAM)
        text(d,(520,y+5),"23:00-05:00  /  STENK  /  1087 BUDAPEST, KEREPESI ÚT",font(FONT_NARROW_B,25),LIME)
        text(d,(1435,y+5),"ONETICKET.HU",font(FONT_NARROW_B,25),CREAM)
    else:
        text(d,(165,y),"2026.11.21  |  23:00-05:00",font(FONT_NARROW_B,29),CREAM)
        text(d,(720,y),"STENK  |  1087 BUDAPEST, KEREPESI ÚT",font(FONT_NARROW_B,28),LIME)
        text(d,(1435,y),"ONETICKET.HU",font(FONT_NARROW_B,25),CREAM)

def make_variant(n):
    im = logos(base(), n)
    d = ImageDraw.Draw(im)
    # safe design area: x=150..1890, y=95..1060; critical content stays clear of platform crops
    if n == 1:
        # Ref: HSREVO_220528 / 220909 rough display mass, but translated into a date-led hook.
        text(d,(165,178),"21",font(FONT_DISPLAY,420),LIME,stroke=2,stroke_fill=(0,0,0,180))
        text(d,(192,510),"NOV",font(FONT_DISPLAY,110),CREAM)
        text(d,(535,158),"2026.11.21",font(FONT_NARROW_B,48),CREAM,spacing=0)
        # handmade-looking registration bars, structural rather than decorative
        d.rectangle((540,310,1015,323), fill=LIME)
        d.rectangle((540,335,845,342), fill=CYAN)
        text(d,(540,370),"DENOISER   |   SIDERUNNERS\nADAM BASS   |   IMPULZ\nCAPITAL NOISE   |   DR FOLLI   |   NOIZEMAKER",font(FONT_NARROW_B,42),CREAM,spacing=8)
        text(d,(540,620),"#KeepHardstyleHardstyle",font(FONT_DISPLAY,65),LIME)
        info_rail(d,n)
    elif n == 2:
        # Ref: HSREV_221210 / Hard Lake: central type subject and a clean, breathing information rhythm.
        centered(d,(165,160,1880,360),"2026.11.21",font(FONT_DISPLAY,190),CREAM,stroke=2,stroke_fill=(10,30,35,255))
        centered(d,(165,360,1880,480),"#KeepHardstyleHardstyle",font(FONT_NARROW_B,60),LIME)
        # lineup is a designed wall, not a tiny footer
        rows = ["DENOISER   SIDERUNNERS   ADAM BASS", "IMPULZ   CAPITAL NOISE   DR FOLLI", "NOIZEMAKER"]
        yy=560
        for i,row in enumerate(rows):
            col = CREAM if i != 1 else LIME
            centered(d,(160,yy,1885,yy+64),row,font(FONT_DISPLAY,53 if i<2 else 62),col)
            yy += 82
        d.line((260,850,1785,850), fill=CREAM, width=2)
        text(d,(165,875),"#KeepHardstyleHardstyle",font(FONT_NARROW_B,42),LIME)
        info_rail(d,n)
    else:
        # Ref: GPF / Hardcore Frat: asymmetric concept block with strong date and lineup contrast.
        text(d,(180,195),"21",font(FONT_DISPLAY,300),CREAM)
        text(d,(180,500),"2026.11.21",font(FONT_NARROW_B,56),LIME)
        d.rectangle((180,535,860,565), fill=CREAM)
        text(d,(180,590),"#KeepHardstyleHardstyle",font(FONT_DISPLAY,56),CREAM,spacing=-2)
        text(d,(1015,185),"2026.11.21",font(FONT_DISPLAY,100),LIME)
        text(d,(1018,315),"DENOISER\nSIDERUNNERS\nADAM BASS\nIMPULZ\nCAPITAL NOISE\nDR FOLLI\nNOIZEMAKER",font(FONT_DISPLAY,65),CREAM,spacing=2)
        text(d,(1018,840),"#KeepHardstyleHardstyle",font(FONT_NARROW_B,39),LIME)
        info_rail(d,n)
    path = OUT / f"hardstyle-revolution-2026-11-21-v{n}-source.png"
    im.save(path, "PNG", optimize=True)
    return path

if __name__ == "__main__":
    for i in (1,2,3):
        print(make_variant(i))
