from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter

W,H=2048,1152
OUT=Path(r"C:\Users\deero\hungarian_hardstyle_app\generated\flyer\hsrevo-2026-11-21-reference-led"); OUT.mkdir(parents=True,exist_ok=True)
BG=Path(r"C:\Users\deero\.codex\generated_images\01a05dd0-32bb-7aa3-84ab-046195582839\exec-e2d22b6a-6c51-47e7-8f1e-cad5a16c79f9.png")
# fallback to known generated base
if not BG.exists(): BG=Path(r"C:\Users\deero\.codex\generated_images\01a05dd0-32bb-7aa3-84ab-046195582839\exec-f04de281-4a5b-4d58-ac1e-f11753b0b431.png")
LOGO=Path(r"G:\Denoiser\Cuccok\hsrevo logo white.png"); HUHS=Path(r"G:\Denoiser\Cuccok\HUN HS LOGO Transparent.png")
FB=r"C:\Windows\Fonts\AGENCYB.TTF"; FR=r"C:\Windows\Fonts\AGENCYR.TTF"; FN=r"C:\Windows\Fonts\ARIALNB.TTF"; FS=r"C:\Windows\Fonts\STENCIL.TTF"
CREAM=(244,240,225,255); RED=(239,30,59,255); CYAN=(42,231,212,255); INK=(2,6,9,235); WHITE=(250,248,239,255)
ART1="DENOISER  /  SIDERUNNERS  /  ADAM BASS  /  IMPULZ"; ART2="CAPITAL NOISE  /  DR FOLLI  /  NOIZEMAKER"
DATA="2026.11.21  |  23:00-05:00  |  STENK  |  1087 BUDAPEST, KEREPESI ÚT  |  JEGYEK: ONETICKET.HU"

def f(path,size): return ImageFont.truetype(path,size)
def crop(im):
    im=im.convert("RGBA"); b=im.getbbox(); return im.crop(b) if b else im
def logo(dst,path,x,y,w,h):
    im=crop(Image.open(path)); im.thumbnail((w,h),Image.Resampling.LANCZOS); dst.alpha_composite(im,(x,y))
def fit(d,s,maxw,size,path=FB):
    while size>18 and d.textbbox((0,0),s,font=f(path,size))[2]>maxw: size-=2
    return f(path,size)
def center(d,s,y,ft,fill,x0=0,x1=W,sw=0):
    b=d.textbbox((0,0),s,font=ft,stroke_width=sw); x=x0+((x1-x0)-(b[2]-b[0]))//2
    d.text((x,y),s,font=ft,fill=fill,stroke_width=sw,stroke_fill=INK); return x
def base(mode):
    im=Image.open(BG).convert("RGBA").resize((W,H),Image.Resampling.LANCZOS)
    im=ImageEnhance.Contrast(im).enhance(1.18); im=ImageEnhance.Color(im).enhance(.88)
    ov=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(ov)
    d.rectangle((106,78,1942,1072),fill=(0,0,0,55))
    if mode=="A":
        d.polygon([(108,78),(850,78),(580,1072),(108,1072)],fill=(0,0,0,48))
        d.line((120,780,1925,480),fill=RED,width=7)
        d.line((120,797,1925,497),fill=CYAN,width=3)
    elif mode=="B":
        d.rectangle((112,780,1936,1052),fill=(0,0,0,115))
        d.line((120,220,1928,220),fill=RED,width=5)
        d.line((120,234,1928,234),fill=CYAN,width=2)
    else:
        d.polygon([(112,78),(1936,78),(1936,1072),(112,1072)],outline=(240,240,220,70),width=2)
        d.line((112,620,1936,620),fill=RED,width=8)
    return Image.alpha_composite(im,ov)
def rough_word(im,text,x,y,size,fill=CREAM,accent=CYAN,spacing=-4):
    d=ImageDraw.Draw(im); ft=f(FB,size); pos=x
    for i,ch in enumerate(text):
        if ch==" ": pos+=size//2; continue
        # offset registration creates the hand-built reference feel
        d.text((pos+8,y+7+(i%3)*2),ch,font=ft,fill=accent,stroke_width=2,stroke_fill=INK)
        d.text((pos,y),ch,font=ft,fill=fill,stroke_width=3,stroke_fill=INK)
        if i%2==0: d.line((pos+size//3,y+size-11,pos+size//3+10,y+size+4),fill=accent,width=3)
        pos+=d.textbbox((0,0),ch,font=ft)[2]+spacing
    return pos
def rail(d,y):
    d.rectangle((135,y,1913,y+82),fill=INK)
    d.text((165,y+19),DATA,font=fit(d,DATA,1700,41,FN),fill=CREAM,stroke_width=1,stroke_fill=(0,0,0,255))

def A():
    im=base("A"); d=ImageDraw.Draw(im)
    logo(im,LOGO,150,116,330,120); logo(im,HUHS,1782,126,90,114)
    d.text((155,275),"H A R D S T Y L E",font=f(FR,43),fill=CYAN,stroke_width=1,stroke_fill=INK)
    rough_word(im,"HARDSTYLE",150,350,178,CREAM,CYAN,-8)
    d.text((157,575),"2026.11.21",font=f(FS,138),fill=RED,stroke_width=5,stroke_fill=INK)
    d.text((155,710),"#KeepHardstyleHardstyle",font=fit(d,"#KeepHardstyleHardstyle",790,70,FS),fill=CYAN,stroke_width=2,stroke_fill=INK)
    d.rectangle((1080,305,1888,770),fill=(0,0,0,125),outline=RED,width=4)
    d.text((1120,420),ART1,font=fit(d,ART1,710,48,FR),fill=WHITE,spacing=8)
    d.text((1120,565),ART2,font=fit(d,ART2,710,48,FR),fill=CYAN,spacing=8)
    d.line((1120,680,1820,680),fill=CREAM,width=3)
    rail(d,935); return im
def B():
    im=base("B"); d=ImageDraw.Draw(im)
    logo(im,LOGO,1600,112,300,115); logo(im,HUHS,150,120,90,112)
    center(d,"H A R D S T Y L E",270,f(FR,44),CYAN,150,1898)
    # Large date as a poster object, with a second register in the style of the photo-free references.
    ft=f(FB,290); x=330
    d.text((x+18,330),"21",font=ft,fill=CYAN,stroke_width=5,stroke_fill=INK)
    d.text((x,315),"21",font=ft,fill=CREAM,stroke_width=5,stroke_fill=INK)
    d.text((760,430),"2026.11.21",font=f(FS,105),fill=RED,stroke_width=3,stroke_fill=INK)
    d.text((174,705),"#KeepHardstyleHardstyle",font=fit(d,"#KeepHardstyleHardstyle",800,70,FS),fill=RED,stroke_width=2,stroke_fill=INK)
    d.rectangle((110,800,1938,910),fill=INK)
    center(d,ART1,818,fit(d,ART1,1690,55,FR),CREAM,150,1898)
    center(d,ART2,870,fit(d,ART2,1500,52,FR),CYAN,270,1778)
    rail(d,958); return im
def C():
    im=base("C"); d=ImageDraw.Draw(im)
    logo(im,LOGO,145,112,315,112); logo(im,HUHS,1790,122,88,108)
    d.text((155,285),"2026.11.21",font=f(FR,46),fill=CYAN,stroke_width=1,stroke_fill=INK)
    rough_word(im,"HARDSTYLE",150,360,160,CREAM,RED,-9)
    # Dense typographic matrix, not a single flat horizontal list.
    d.rectangle((150,640,1895,810),fill=(0,0,0,135))
    d.text((190,665),"DENOISER",font=f(FB,72),fill=RED,stroke_width=2,stroke_fill=INK)
    d.text((690,665),"SIDERUNNERS",font=f(FB,72),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((1400,665),"ADAM BASS",font=f(FB,62),fill=CYAN,stroke_width=2,stroke_fill=INK)
    d.text((190,745),"IMPULZ  /  CAPITAL NOISE  /  DR FOLLI  /  NOIZEMAKER",font=fit(d,"IMPULZ  /  CAPITAL NOISE  /  DR FOLLI  /  NOIZEMAKER",1640,50,FR),fill=WHITE,stroke_width=1,stroke_fill=INK)
    d.text((150,840),"#KeepHardstyleHardstyle",font=fit(d,"#KeepHardstyleHardstyle",750,69,FS),fill=CYAN,stroke_width=2,stroke_fill=INK)
    rail(d,956); return im
def MAIN():
    # Primary reference: HSREVO_220528 / 220909. Borrowed: one dominant rough display word,
    # wide tracked preface/date, dense two-level artist block, and a compact bottom data rail.
    im=base("A"); d=ImageDraw.Draw(im)
    # Stable identity rail: the logo carries the event name; HUHS is a small secondary mark.
    logo(im,LOGO,150,112,350,126); logo(im,HUHS,1790,122,88,108)
    d.text((157,285),"2026.11.21",font=f(FR,48),fill=CYAN,stroke_width=1,stroke_fill=INK)
    # Authored graphic lettering: offset registration, uneven baseline, and cut-like accent strokes.
    rough_word(im,"HARDSTYLE",150,350,190,CREAM,CYAN,-10)
    d.line((150,585,1835,585),fill=RED,width=8)
    d.line((150,601,1835,601),fill=CYAN,width=3)
    # The artist list is the second visual subject, not footer copy.
    d.rectangle((150,650,1895,858),fill=(0,0,0,170))
    d.text((188,678),"DENOISER",font=f(FB,78),fill=RED,stroke_width=2,stroke_fill=INK)
    d.text((710,678),"SIDERUNNERS",font=f(FB,72),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((1408,678),"ADAM BASS",font=f(FB,58),fill=CYAN,stroke_width=2,stroke_fill=INK)
    d.text((188,774),"IMPULZ",font=f(FB,54),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((510,774),"CAPITAL NOISE",font=f(FB,54),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((1040,774),"DR FOLLI",font=f(FB,54),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((1390,774),"NOIZEMAKER",font=f(FB,54),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((155,886),"#KeepHardstyleHardstyle",font=fit(d,"#KeepHardstyleHardstyle",900,70,FS),fill=RED,stroke_width=2,stroke_fill=INK)
    rail(d,956)
    return im

def REF_A():
    im=base("A"); d=ImageDraw.Draw(im)
    logo(im,LOGO,1600,112,300,115); logo(im,HUHS,150,120,90,112)
    # Reference-led hook: the date is treated as a large printed registration block.
    d.text((155,280),"2026.11.21",font=f(FS,126),fill=RED,stroke_width=3,stroke_fill=INK)
    d.text((155,432),"DENOISER",font=f(FB,112),fill=CREAM,stroke_width=3,stroke_fill=INK)
    d.text((155,555),"SIDERUNNERS",font=f(FB,103),fill=CYAN,stroke_width=3,stroke_fill=INK)
    d.text((155,675),"ADAM BASS",font=f(FB,90),fill=CREAM,stroke_width=3,stroke_fill=INK)
    d.text((1160,440),"IMPULZ",font=f(FB,82),fill=RED,stroke_width=2,stroke_fill=INK)
    d.text((1160,535),"CAPITAL NOISE",font=f(FB,66),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((1160,620),"DR FOLLI",font=f(FB,70),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((1160,705),"NOIZEMAKER",font=f(FB,61),fill=CYAN,stroke_width=2,stroke_fill=INK)
    d.text((155,815),"#KeepHardstyleHardstyle",font=fit(d,"#KeepHardstyleHardstyle",850,67,FS),fill=RED,stroke_width=2,stroke_fill=INK)
    rail(d,956); return im

def REF_B():
    im=base("B"); d=ImageDraw.Draw(im)
    logo(im,LOGO,150,112,310,116); logo(im,HUHS,1800,122,82,105)
    d.text((149,275),"2026.11.21",font=f(FR,48),fill=CYAN,stroke_width=1,stroke_fill=INK)
    # The lineup becomes the graphic lettering itself, following the dense artist-first reference rhythm.
    d.text((145,345),"DENOISER",font=f(FB,152),fill=CREAM,stroke_width=4,stroke_fill=INK)
    d.text((145,495),"SIDERUNNERS",font=f(FB,121),fill=RED,stroke_width=3,stroke_fill=INK)
    d.line((145,650,1900,650),fill=CYAN,width=4)
    d.text((150,682),"ADAM BASS  /  IMPULZ",font=f(FB,78),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((150,778),"CAPITAL NOISE  /  DR FOLLI  /  NOIZEMAKER",font=fit(d,"CAPITAL NOISE  /  DR FOLLI  /  NOIZEMAKER",1740,63,FR),fill=CYAN,stroke_width=2,stroke_fill=INK)
    d.text((150,866),"#KeepHardstyleHardstyle",font=fit(d,"#KeepHardstyleHardstyle",780,62,FS),fill=RED,stroke_width=2,stroke_fill=INK)
    rail(d,956); return im

def REF_C():
    im=base("C"); d=ImageDraw.Draw(im)
    logo(im,LOGO,1600,112,300,115); logo(im,HUHS,150,120,90,110)
    d.text((155,275),"2026.11.21",font=f(FR,47),fill=CYAN,stroke_width=1,stroke_fill=INK)
    # A single typographic collision: featured artists large, the remaining names as a tight lower matrix.
    rough_word(im,"DENOISER",145,360,155,CREAM,RED,-8)
    rough_word(im,"SIDERUNNERS",145,520,115,CREAM,CYAN,-7)
    d.rectangle((145,690,1900,850),fill=(0,0,0,170))
    d.text((185,710),"ADAM BASS",font=f(FB,75),fill=CYAN,stroke_width=2,stroke_fill=INK)
    d.text((770,710),"IMPULZ",font=f(FB,75),fill=RED,stroke_width=2,stroke_fill=INK)
    d.text((1300,710),"CAPITAL NOISE",font=f(FB,53),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((185,790),"DR FOLLI  /  NOIZEMAKER",font=f(FR,55),fill=CREAM,stroke_width=2,stroke_fill=INK)
    d.text((145,875),"#KeepHardstyleHardstyle",font=fit(d,"#KeepHardstyleHardstyle",800,64,FS),fill=CYAN,stroke_width=2,stroke_fill=INK)
    rail(d,956); return im

for n,fn in (("A",REF_A),("B",REF_B),("C",REF_C)):
    p=OUT/f"hsrevo-2026-11-21-{n}.png"; fn().convert("RGB").save(p,optimize=True); print(p)
