from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
from pathlib import Path

W, H = 2048, 1152
OUT = Path(r"C:\Users\deero\hungarian_hardstyle_app\generated\flyer\hsrevo-2026-11-21-v2")
OUT.mkdir(parents=True, exist_ok=True)
BG = Path(r"C:\Users\deero\.codex\generated_images\01a05dd0-32bb-7aa3-84ab-046195582839\exec-d2d226b1-bd59-4708-a5b5-5b95ac50ec09.png")
HS = Path(r"G:\Denoiser\Cuccok\HUN HS LOGO Transparent.png")
REVO = Path(r"G:\Denoiser\Cuccok\hsrevo logo white.png")
DISPLAY = r"C:\Windows\Fonts\AGENCYB.TTF"
NARROW = r"C:\Windows\Fonts\ARIALN.TTF"
NARROW_B = r"C:\Windows\Fonts\ARIALNB.TTF"
CREAM=(241,239,226,255); LIME=(205,255,28,255); CYAN=(41,200,205,255); BLACK=(2,7,9,230)

def F(p,s): return ImageFont.truetype(p,s)
def trim(p):
    im=Image.open(p).convert('RGBA'); b=im.getchannel('A').getbbox(); return im.crop(b) if b else im
def fit(im,w,h):
    k=min(w/im.width,h/im.height); return im.resize((int(im.width*k),int(im.height*k)),Image.Resampling.LANCZOS)
def txt(d,xy,s,f,fill=CREAM,anchor=None,sw=0,sf=(0,0,0,0),spacing=0):
    d.multiline_text(xy,s,font=f,fill=fill,anchor=anchor,stroke_width=sw,stroke_fill=sf,spacing=spacing)
def center(d,box,s,f,fill=CREAM,sw=0,sf=(0,0,0,0)):
    x0,y0,x1,y1=box; b=d.multiline_textbbox((0,0),s,font=f,stroke_width=sw)
    txt(d,((x0+x1-b[2]+b[0])/2,(y0+y1-b[3]+b[1])/2),s,f,fill,sw=sw,sf=sf)
def texture(im):
    g=Image.effect_noise((W,H),9).convert('L').filter(ImageFilter.GaussianBlur(.3))
    g=ImageEnhance.Contrast(g).enhance(1.2)
    o=Image.new('RGBA',(W,H),(220,225,210,0)); o.putalpha(g.point(lambda p:int(p*.045)))
    return Image.alpha_composite(im,o)
def base():
    im=Image.open(BG).convert('RGBA').resize((W,H),Image.Resampling.LANCZOS)
    shade=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(shade)
    d.rectangle((0,0,1240,H),fill=(0,3,5,70)); d.rectangle((0,914,W,H),fill=(0,3,5,115))
    return texture(Image.alpha_composite(im,shade))
def add_logos(im,v):
    layer=Image.new('RGBA',(W,H),(0,0,0,0)); revo=fit(trim(REVO),300,112); hs=fit(trim(HS),190,82)
    if v==1:
        layer.alpha_composite(revo,(1570,100)); layer.alpha_composite(hs,(1690,965))
    else:
        layer.alpha_composite(revo,(150,98)); layer.alpha_composite(hs,(1700,965))
    return Image.alpha_composite(im,layer)
def registration_date(d,x,y,s=170,accent=LIME):
    # One reference-grounded offset registration move, used only on the date hook.
    f=F(DISPLAY,s)
    txt(d,(x+12,y+12),'2026.11.21',f,CYAN)
    txt(d,(x,y),'2026.11.21',f,CREAM,sw=1,sf=(0,0,0,160))
    # a single clipped-looking ink interruption, not a generic underline
    d.rectangle((x+25,y+s-16,x+int(s*2.5),y+s-4),fill=accent)
    return f
def rail(d,v):
    d.line((150,930,1890,930),fill=(241,239,226,190),width=2)
    if v==1:
        txt(d,(165,962),'2026.11.21',F(DISPLAY,42),LIME)
        txt(d,(450,966),'23:00-05:00   |   STENK   |   1087 BUDAPEST, KEREPESI ÚT',F(NARROW_B,25),CREAM)
        txt(d,(1370,966),'JEGYEK: ONETICKET.HU',F(NARROW_B,23),LIME)
    else:
        txt(d,(165,966),'2026.11.21  |  23:00-05:00',F(NARROW_B,27),CREAM)
        txt(d,(720,966),'STENK  |  1087 BUDAPEST, KEREPESI ÚT',F(NARROW_B,27),LIME)
        txt(d,(1460,966),'ONETICKET.HU',F(NARROW_B,24),CREAM)
def make(v):
    im=add_logos(base(),v); d=ImageDraw.Draw(im)
    if v==1:
        registration_date(d,165,160,172,LIME)
        txt(d,(165,382),'#KeepHardstyleHardstyle',F(DISPLAY,62),LIME)
        # Two designed rows: the lineup is a main content block, not a footer.
        txt(d,(165,520),'DENOISER   |   SIDERUNNERS',F(DISPLAY,57),CREAM)
        txt(d,(165,596),'ADAM BASS   |   IMPULZ',F(DISPLAY,57),CREAM)
        txt(d,(165,672),'CAPITAL NOISE',F(DISPLAY,57),LIME)
        txt(d,(165,748),'DR FOLLI   |   NOIZEMAKER',F(DISPLAY,57),CREAM)
        # A vertical typographic counterweight derived from the photo-free references.
        txt(d,(1420,270),'21',F(DISPLAY,390),LIME)
        txt(d,(1465,650),'2026.11.21',F(NARROW_B,32),CREAM)
    else:
        txt(d,(170,205),'21',F(DISPLAY,380),CREAM,sw=2,sf=(0,0,0,180))
        txt(d,(180,610),'2026.11.21',F(DISPLAY,63),LIME)
        d.rectangle((180,700,810,725),fill=LIME)
        txt(d,(180,760),'#KeepHardstyleHardstyle',F(DISPLAY,51),CREAM)
        # Tall lineup stack, with alternating scale/colour for a clear reading path.
        names=['DENOISER','SIDERUNNERS','ADAM BASS','IMPULZ','CAPITAL NOISE','DR FOLLI','NOIZEMAKER']
        y=210
        for i,n in enumerate(names):
            txt(d,(960,y),n,F(DISPLAY,67 if i<3 else 59),LIME if i in (0,3,6) else CREAM)
            y += 82 if i<3 else 70
        d.line((960,790,1835,790),fill=CREAM,width=2)
    rail(d,v)
    p=OUT/f'hardstyle-revolution-2026-11-21-v{v}-source.png'; im.save(p,'PNG',optimize=True); print(p)
for v in (1,2): make(v)
