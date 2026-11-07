#!/usr/bin/env python3
"""Generates the built-in chat wallpapers into assets/wallpapers/."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

W, H = 720, 1440
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'wallpapers')
MONO = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'
os.makedirs(OUT, exist_ok=True)

def rgb(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def vgrad(c1, c2, c3=None):
    a, b = rgb(c1), rgb(c2)
    img = Image.new('RGB', (W, H)); px = img.load()
    cc = rgb(c3) if c3 else None
    for y in range(H):
        t = y / (H - 1)
        if cc:
            if t < .5: u = t * 2; col = [a[i] + (b[i] - a[i]) * u for i in range(3)]
            else: u = (t - .5) * 2; col = [b[i] + (cc[i] - b[i]) * u for i in range(3)]
        else:
            col = [a[i] + (b[i] - a[i]) * t for i in range(3)]
        for x in range(W): px[x, y] = tuple(int(v) for v in col)
    return img

def glow(img, fn, blur, strength=1.0):
    layer = Image.new('RGB', img.size, (0, 0, 0))
    fn(ImageDraw.Draw(layer))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    if strength != 1.0: layer = layer.point(lambda v: min(255, int(v * strength)))
    return ImageChops.screen(img, layer)

def overlay(img, fn, alpha=255):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    fn(ImageDraw.Draw(layer))
    if alpha != 255:
        a = layer.split()[3].point(lambda v: v * alpha // 255); layer.putalpha(a)
    base = img.convert('RGBA'); base.alpha_composite(layer); return base.convert('RGB')

def vignette(img, k=0.55):
    mask = Image.new('L', (W, H), 0)
    ImageDraw.Draw(mask).ellipse((-W * .35, -H * .2, W * 1.35, H * 1.2), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(160))
    dark = Image.new('RGB', (W, H), (0, 0, 0))
    return Image.composite(img, Image.blend(img, dark, k), mask)

def grain(img, amt=10, seed=1):
    rnd = random.Random(seed)
    n = Image.effect_noise((W, H), 28).convert('RGB')
    return Image.blend(img, n, 0.035)

def finish(img, name, seed=1):
    img = grain(vignette(img), seed=seed)
    img.save(os.path.join(OUT, name + '.jpg'), quality=84, optimize=True)

def heart(cx, cy, s):
    pts = []
    for i in range(0, 360, 4):
        t = math.radians(i)
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * s, cy - y * s))
    return pts

# ------------------------------------------------------------------ LOVE
def love1():
    img = vgrad('#1a0420', '#4a0a3a', '#14041c')
    img = glow(img, lambda d: d.polygon(heart(W / 2, H * .42, 17), fill=(255, 40, 120)), 60, .9)
    img = glow(img, lambda d: d.line(heart(W / 2, H * .42, 17) + [heart(W / 2, H * .42, 17)[0]], fill=(255, 130, 190), width=9, joint='curve'), 10, 1.0)
    img = overlay(img, lambda d: d.line(heart(W / 2, H * .42, 17) + [heart(W / 2, H * .42, 17)[0]], fill=(255, 215, 235), width=3, joint='curve'))
    finish(img, 'love_1', 1)

def love2():
    r = random.Random(2)
    img = vgrad('#3d0a2a', '#c2185b', '#6a0f3a')
    def f(d):
        for _ in range(26):
            x, y, rr = r.randint(0, W), r.randint(0, H), r.randint(30, 120)
            c = r.choice([(255, 120, 170), (255, 90, 140), (255, 180, 200)])
            d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=tuple(int(v * .45) for v in c))
    img = glow(img, f, 24, 1.0)
    def hs(d):
        for _ in range(14):
            d.polygon(heart(r.randint(40, W - 40), r.randint(60, H - 60), r.uniform(1.2, 3.2)), fill=(255, 255, 255, 120))
    img = overlay(img, hs, 120)
    finish(img, 'love_2', 2)

def love3():
    r = random.Random(3)
    img = vgrad('#2a0510', '#7a0f2a', '#1a0308')
    def pet(d):
        for _ in range(38):
            cx, cy = r.randint(-20, W + 20), r.randint(-20, H + 20)
            a, b = r.randint(14, 34), r.randint(30, 70)
            ang = r.uniform(0, 360)
            im = Image.new('RGBA', (160, 160), (0, 0, 0, 0)); dd = ImageDraw.Draw(im)
            dd.ellipse((80 - a, 80 - b, 80 + a, 80 + b), fill=(220, 40, 70, r.randint(120, 230)))
            im = im.rotate(ang, resample=Image.BICUBIC)
            d._image.paste(im, (cx - 80, cy - 80), im)
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0)); pet(ImageDraw.Draw(layer))
    layer = layer.filter(ImageFilter.GaussianBlur(1.2))
    base = img.convert('RGBA'); base.alpha_composite(layer)
    finish(base.convert('RGB'), 'love_3', 3)

def love4():
    img = vgrad('#2b0620', '#4d0b3a')
    def f(d):
        for gy in range(0, H + 80, 90):
            for gx in range(-40, W + 80, 110):
                ox = 55 if (gy // 90) % 2 else 0
                d.polygon(heart(gx + ox, gy, 1.8), fill=(255, 100, 160, 60))
    img = overlay(img, f, 255)
    img = glow(img, lambda d: d.ellipse((W / 2 - 280, H * .5 - 280, W / 2 + 280, H * .5 + 280), fill=(120, 20, 80)), 140, .8)
    finish(img, 'love_4', 4)

def love5():
    img = vgrad('#0e0620', '#2a0a4a', '#12041e')
    a = heart(W * .40, H * .42, 11); b = heart(W * .60, H * .48, 11)
    img = glow(img, lambda d: (d.line(a + [a[0]], fill=(190, 80, 255), width=10), d.line(b + [b[0]], fill=(255, 70, 150), width=10)), 14, 1.0)
    img = overlay(img, lambda d: (d.line(a + [a[0]], fill=(235, 200, 255), width=3), d.line(b + [b[0]], fill=(255, 205, 225), width=3)))
    finish(img, 'love_5', 5)

def love6():
    img = vgrad('#2a0a3a', '#d6336c', '#ff9a5a')
    img = glow(img, lambda d: d.ellipse((W / 2 - 150, H * .56 - 150, W / 2 + 150, H * .56 + 150), fill=(255, 220, 150)), 40, 1.0)
    def f(d):
        d.polygon(heart(W / 2, H * .30, 6), fill=(255, 240, 240, 230))
        d.polygon([(0, H * .78)] + [(x, H * .78 - 40 * math.sin(x / 70) - 25 * math.sin(x / 31)) for x in range(0, W + 1, 8)] + [(W, H), (0, H)], fill=(25, 6, 28))
    img = overlay(img, f)
    finish(img, 'love_6', 6)

# --------------------------------------------------------------- MYSTERY
def pines(d, base, seed, col, hmin=90, hmax=260, n=26):
    r = random.Random(seed)
    for _ in range(n):
        x = r.randint(-20, W + 20); h = r.randint(hmin, hmax); w = h * .28
        y = base
        for k in range(5):
            t = k / 5
            d.polygon([(x, y - h * (1 - t * .15) + k * h / 6 - h * .0), (x - w * (1 - t * .75), y - h * (t * .62)), (x + w * (1 - t * .75), y - h * (t * .62))], fill=col)
        d.rectangle((x - 3, y - 8, x + 3, y), fill=col)

def mystery1():
    img = vgrad('#050a1c', '#10264a', '#0a1428')
    img = glow(img, lambda d: d.ellipse((W * .5 - 120, H * .2 - 120, W * .5 + 120, H * .2 + 120), fill=(230, 235, 255)), 60, 1.0)
    img = overlay(img, lambda d: d.ellipse((W * .5 - 85, H * .2 - 85, W * .5 + 85, H * .2 + 85), fill=(240, 244, 255, 255)))
    img = overlay(img, lambda d: pines(d, H * .78, 7, (4, 8, 16, 255), 120, 330, 30))
    fog = lambda d: [d.ellipse((x - 260, H * .74 + dy - 60, x + 260, H * .74 + dy + 60), fill=(90, 110, 150)) for x, dy in [(100, 10), (360, -20), (640, 15), (240, 60), (520, 70)]]
    img = glow(img, fog, 40, .5)
    img = overlay(img, lambda d: d.rectangle((0, H * .88, W, H), fill=(3, 6, 12, 255)))
    finish(img, 'mystery_1', 8)

def mystery2():
    img = vgrad('#0b0418', '#220a3c', '#080212')
    cx, cy = W / 2, H * .42
    def eye(d, col, wd):
        pts = [(cx + 300 * math.cos(math.radians(a)), cy - 150 * math.sin(math.radians(a))) for a in range(0, 181, 4)]
        pts2 = [(cx + 300 * math.cos(math.radians(a)), cy + 150 * math.sin(math.radians(a))) for a in range(180, -1, -4)]
        d.line(pts + pts2, fill=col, width=wd, joint='curve')
        d.ellipse((cx - 85, cy - 85, cx + 85, cy + 85), outline=col, width=wd)
        d.ellipse((cx - 28, cy - 28, cx + 28, cy + 28), fill=col)
        for a in range(0, 360, 20):
            d.line((cx + 100 * math.cos(math.radians(a)), cy + 100 * math.sin(math.radians(a)), cx + 135 * math.cos(math.radians(a)), cy + 135 * math.sin(math.radians(a))), fill=col, width=3)
    img = glow(img, lambda d: eye(d, (170, 70, 255), 10), 16, 1.0)
    img = overlay(img, lambda d: eye(d, (232, 205, 255, 255), 3))
    finish(img, 'mystery_2', 9)

def mystery3():
    img = vgrad('#04040a', '#0a0a14')
    cx, cy = W / 2, H * .45
    def beam(d):
        d.polygon([(cx - 30, cy), (cx + 30, cy), (cx + 360, H), (cx - 360, H)], fill=(220, 190, 120))
    img = glow(img, beam, 50, .55)
    def kh(d):
        d.ellipse((cx - 70, cy - 120, cx + 70, cy + 20), fill=(0, 0, 0))
        d.polygon([(cx - 36, cy), (cx + 36, cy), (cx + 70, cy + 150), (cx - 70, cy + 150)], fill=(0, 0, 0))
    img = overlay(img, lambda d: (d.rounded_rectangle((cx - 150, cy - 230, cx + 150, cy + 230), radius=50, fill=(16, 16, 24, 255), outline=(60, 50, 40, 255), width=3), kh(d)))
    img = glow(img, lambda d: (d.ellipse((cx - 70, cy - 120, cx + 70, cy + 20), fill=(255, 200, 110)), d.polygon([(cx - 36, cy), (cx + 36, cy), (cx + 70, cy + 150), (cx - 70, cy + 150)], fill=(255, 200, 110))), 18, .9)
    finish(img, 'mystery_3', 10)

def mystery4():
    img = vgrad('#0a1410', '#1c3a30', '#0a1612')
    for i, (b, col) in enumerate([(H * .62, (24, 52, 44, 255)), (H * .72, (14, 34, 28, 255)), (H * .84, (6, 18, 14, 255))]):
        img = overlay(img, lambda d, b=b, col=col, i=i: (d.polygon([(0, H)] + [(x, b + 30 * math.sin(x / 110 + i)) for x in range(0, W + 1, 12)] + [(W, H)], fill=col), pines(d, b + 40, 20 + i, col, 100 + i * 40, 260 + i * 80, 22)))
        img = glow(img, lambda d, b=b: d.ellipse((-200, b - 90, W + 200, b + 70), fill=(120, 170, 150)), 50, .35)
    img = glow(img, lambda d: d.ellipse((W * .5 - 60, H * .16 - 60, W * .5 + 60, H * .16 + 60), fill=(200, 255, 230)), 50, .8)
    finish(img, 'mystery_4', 11)

def mystery5():
    r = random.Random(12)
    img = vgrad('#0c0618', '#102a3a', '#1a0a30')
    def sm(d):
        for _ in range(16):
            x, y = r.randint(0, W), r.randint(0, H); rr = r.randint(80, 220)
            d.ellipse((x - rr, y - rr * .6, x + rr, y + rr * .6), fill=r.choice([(110, 60, 200), (40, 140, 160), (160, 60, 160)]))
    img = glow(img, sm, 70, .8)
    img = glow(img, lambda d: [d.arc((60 + i * 20, 200 + i * 60, 660 - i * 20, 900 + i * 40), 190 + i * 30, 330 + i * 20, fill=(170, 220, 255), width=3) for i in range(6)], 6, .8)
    finish(img, 'mystery_5', 12)

def mystery6():
    img = vgrad('#050510', '#14082a')
    cx, cy, R = W / 2, H * .44, 250
    def sig(d, col, wd):
        d.ellipse((cx - R, cy - R, cx + R, cy + R), outline=col, width=wd)
        d.ellipse((cx - R - 24, cy - R - 24, cx + R + 24, cy + R + 24), outline=col, width=max(1, wd // 2))
        tri = [(cx + R * math.cos(math.radians(a)), cy + R * math.sin(math.radians(a))) for a in (-90, 30, 150)]
        d.line(tri + [tri[0]], fill=col, width=wd)
        tri2 = [(cx + R * math.cos(math.radians(a)), cy + R * math.sin(math.radians(a))) for a in (90, 210, 330)]
        d.line(tri2 + [tri2[0]], fill=col, width=wd)
        d.ellipse((cx - 30, cy - 30, cx + 30, cy + 30), outline=col, width=wd)
        for a in range(0, 360, 30):
            x, y = cx + (R + 48) * math.cos(math.radians(a)), cy + (R + 48) * math.sin(math.radians(a))
            d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=col)
    img = glow(img, lambda d: sig(d, (130, 60, 255), 8), 14, 1.0)
    img = overlay(img, lambda d: sig(d, (225, 205, 255, 255), 2))
    finish(img, 'mystery_6', 13)

# ------------------------------------------------------------------ CARS
def car(d, x, y, s, body, glass=(30, 40, 60, 255)):
    pts = [(0, 60), (10, 40), (60, 34), (110, 6), (200, -14), (290, -14), (345, 14), (420, 26), (452, 46), (452, 62), (0, 62)]
    d.polygon([(x + a * s, y + b * s) for a, b in pts], fill=body)
    d.polygon([(x + a * s, y + b * s) for a, b in [(118, 8), (205, -8), (282, -8), (330, 16), (120, 16)]], fill=glass)
    for wx in (95, 360):
        d.ellipse((x + (wx - 34) * s, y + 30 * s, x + (wx + 34) * s, y + 98 * s), fill=(8, 8, 10, 255))
        d.ellipse((x + (wx - 18) * s, y + 46 * s, x + (wx + 18) * s, y + 82 * s), fill=(150, 150, 160, 255))

def cars1():
    img = vgrad('#04060e', '#0c1020')
    hz = H * .46
    def road(d):
        d.polygon([(W / 2 - 14, hz), (W / 2 + 14, hz), (W + 260, H), (-260, H)], fill=(18, 20, 28, 255))
        for i in range(10):
            t0, t1 = (i / 10) ** 2, ((i + .55) / 10) ** 2
            y0, y1 = hz + (H - hz) * t0, hz + (H - hz) * t1
            w0, w1 = 2 + 16 * t0, 2 + 16 * t1
            d.polygon([(W / 2 - w0, y0), (W / 2 + w0, y0), (W / 2 + w1, y1), (W / 2 - w1, y1)], fill=(235, 220, 140, 255))
    img = overlay(img, road)
    img = glow(img, lambda d: [d.line((W / 2 + o * .08, hz, W / 2 + o, H), fill=c, width=7) for o, c in [(-380, (255, 40, 40)), (-300, (255, 70, 50)), (380, (255, 40, 40)), (300, (255, 90, 60))]], 12, 1.0)
    img = glow(img, lambda d: d.ellipse((W / 2 - 80, hz - 40, W / 2 + 80, hz + 40), fill=(255, 150, 80)), 30, .7)
    finish(img, 'cars_1', 14)

def cars2():
    img = vgrad('#08090f', '#12060a')
    cx, cy, R = W / 2, H * .46, 290
    def gauge(d, col, wd):
        d.arc((cx - R, cy - R, cx + R, cy + R), 135, 405, fill=col, width=wd)
        for i in range(0, 41):
            a = math.radians(135 + i * 270 / 40)
            L = 34 if i % 5 == 0 else 16
            d.line((cx + (R - 12) * math.cos(a), cy + (R - 12) * math.sin(a), cx + (R - 12 - L) * math.cos(a), cy + (R - 12 - L) * math.sin(a)), fill=col, width=4 if i % 5 == 0 else 2)
        a = math.radians(135 + 270 * .78)
        d.line((cx, cy, cx + (R - 40) * math.cos(a), cy + (R - 40) * math.sin(a)), fill=(255, 255, 255), width=7)
        d.ellipse((cx - 22, cy - 22, cx + 22, cy + 22), fill=col)
    img = glow(img, lambda d: gauge(d, (255, 40, 50), 10), 14, 1.0)
    img = overlay(img, lambda d: gauge(d, (255, 190, 190, 255), 2))
    img = glow(img, lambda d: d.arc((cx - R, cy - R, cx + R, cy + R), 135 + 270 * .78, 405, fill=(255, 20, 20), width=22), 10, 1.0)
    finish(img, 'cars_2', 15)

def cars3():
    img = vgrad('#1a0a3a', '#d6336c', '#ff9f43')
    img = glow(img, lambda d: d.ellipse((W / 2 - 170, H * .52 - 170, W / 2 + 170, H * .52 + 170), fill=(255, 235, 170)), 30, 1.0)
    img = overlay(img, lambda d: d.rectangle((0, H * .72, W, H), fill=(14, 8, 24, 255)))
    img = overlay(img, lambda d: car(d, 60, H * .72 - 38 * 1.45 + 6, 1.45, (10, 8, 18, 255), (255, 160, 110, 255)))
    img = glow(img, lambda d: d.line((0, H * .73, W, H * .73), fill=(255, 120, 150), width=4), 8, 1.0)
    finish(img, 'cars_3', 16)

def cars4():
    img = Image.new('RGB', (W, H), (14, 14, 16)); d = ImageDraw.Draw(img)
    for y in range(0, H, 16):
        for x in range(0, W, 16):
            a = ((x // 16) + (y // 16)) % 2
            d.rectangle((x, y, x + 15, y + 15), fill=(26, 26, 30) if a else (10, 10, 12))
            d.line((x, y, x + 15, y + 15), fill=(40, 40, 46) if a else (22, 22, 26), width=1)
    img = glow(img, lambda d: d.polygon([(-40, H * .3), (W + 40, H * .2), (W + 40, H * .2 + 26), (-40, H * .3 + 26)], fill=(255, 30, 40)), 14, 1.0)
    img = overlay(img, lambda d: d.polygon([(-40, H * .3 + 8), (W + 40, H * .2 + 8), (W + 40, H * .2 + 14), (-40, H * .3 + 14)], fill=(255, 200, 200, 255)))
    finish(img, 'cars_4', 17)

def cars5():
    r = random.Random(18)
    img = vgrad('#04030c', '#0c0620')
    def trails(d):
        for _ in range(26):
            y0 = r.randint(int(H * .3), int(H * .85)); col = r.choice([(255, 60, 60), (255, 210, 120), (255, 90, 40), (255, 255, 255)])
            amp, ph = r.randint(20, 120), r.uniform(0, 6)
            pts = [(x, y0 + amp * math.sin(x / 190 + ph) + (x - W / 2) * .18) for x in range(-20, W + 40, 10)]
            d.line(pts, fill=col, width=r.randint(3, 8), joint='curve')
    img = glow(img, trails, 8, 1.0)
    img = glow(img, trails, 22, .6)
    finish(img, 'cars_5', 18)

def cars6():
    img = vgrad('#05080c', '#0c1620')
    hz = H * .55
    img = overlay(img, lambda d: d.polygon([(0, hz), (W, hz), (W, H), (0, H)], fill=(10, 12, 16, 255)))
    img = glow(img, lambda d: [d.ellipse((x - 90, hz - 110, x + 90, hz + 70), fill=(255, 250, 220)) for x in (W * .28, W * .72)], 24, 1.0)
    img = glow(img, lambda d: [d.polygon([(x - 50, hz), (x + 50, hz), (x + dx, H), (x - dx, H)], fill=(170, 175, 150)) for x, dx in [(W * .28, 330), (W * .72, 330)]], 40, .5)
    img = overlay(img, lambda d: [d.ellipse((x - 46, hz - 66, x + 46, hz + 26), fill=(255, 255, 245, 255)) for x in (W * .28, W * .72)])
    finish(img, 'cars_6', 19)

# ----------------------------------------------------------- MOTORCYCLES
def bike(d, x, y, s, col, wd):
    wr = 78 * s
    for wx in (x, x + 330 * s):
        d.ellipse((wx - wr, y - wr, wx + wr, y + wr), outline=col, width=wd)
        d.ellipse((wx - wr * .55, y - wr * .55, wx + wr * .55, y + wr * .55), outline=col, width=max(1, wd // 2))
        d.ellipse((wx - 6 * s, y - 6 * s, wx + 6 * s, y + 6 * s), fill=col)
    P = lambda a, b: (x + a * s, y + b * s)
    d.line([P(0, 0), P(120, -70), P(220, -70), P(330, 0)], fill=col, width=wd, joint='curve')      # swingarm/frame
    d.line([P(330, 0), P(290, -130), P(260, -170)], fill=col, width=wd)                              # fork
    d.line([P(240, -170), P(300, -185)], fill=col, width=wd + 2)                                      # bars
    d.polygon([P(110, -78), P(210, -132), P(268, -110), P(240, -70), P(130, -64)], outline=col, fill=None, width=wd)   # tank
    d.line([P(60, -92), P(130, -100)], fill=col, width=wd + 4)                                        # seat
    d.line([P(120, -70), P(150, -10), P(210, -10), P(222, -70)], fill=col, width=wd)                  # engine

def moto1():
    img = vgrad('#1a0a2e', '#e8543a', '#ffb347')
    img = glow(img, lambda d: d.ellipse((W / 2 - 130, H * .44 - 130, W / 2 + 130, H * .44 + 130), fill=(255, 235, 170)), 30, 1.0)
    img = overlay(img, lambda d: d.rectangle((0, H * .66, W, H), fill=(12, 6, 18, 255)))
    img = overlay(img, lambda d: bike(d, 150, H * .66 - 78 * 1.4, 1.4, (12, 6, 18, 255), 16))
    finish(img, 'moto_1', 20)

def moto2():
    img = vgrad('#0a0306', '#2a0a04')
    def st(d):
        r = random.Random(21)
        for _ in range(36):
            y = r.randint(0, H); L = r.randint(160, 520); x = r.randint(-100, W)
            d.line((x, y, x + L, y - L * .18), fill=r.choice([(255, 90, 20), (255, 170, 40), (255, 50, 20)]), width=r.randint(3, 9))
    img = glow(img, st, 10, 1.0)
    img = overlay(img, st, 160)
    img = glow(img, lambda d: d.ellipse((W * .5 - 220, H * .75 - 160, W * .5 + 220, H * .75 + 160), fill=(255, 80, 10)), 90, .8)
    finish(img, 'moto_2', 21)

def moto3():
    img = vgrad('#0a0a0c', '#16120e')
    def tread(d):
        for y in range(-40, H + 80, 54):
            for x in range(-40, W + 80, 72):
                ox = 36 if (y // 54) % 2 else 0
                d.polygon([(x + ox, y), (x + ox + 44, y + 12), (x + ox + 30, y + 36), (x + ox - 8, y + 22)], fill=(34, 32, 30, 255), outline=(52, 48, 44, 255))
    img = overlay(img, tread)
    img = glow(img, lambda d: d.rectangle((0, H * .5 - 8, W, H * .5 + 8), fill=(255, 110, 20)), 18, 1.0)
    img = overlay(img, lambda d: d.rectangle((0, H * .5 - 2, W, H * .5 + 2), fill=(255, 220, 160, 255)))
    finish(img, 'moto_3', 22)

def moto4():
    img = vgrad('#2a1040', '#ff7a5a', '#ffd08a')
    for i, (b, col) in enumerate([(H * .55, (60, 30, 80, 255)), (H * .65, (34, 16, 50, 255)), (H * .8, (14, 8, 24, 255))]):
        img = overlay(img, lambda d, b=b, col=col, i=i: d.polygon([(0, H)] + [(x, b - 90 * math.sin(x / 160 + i * 1.7) - 40 * math.sin(x / 60 + i)) for x in range(0, W + 1, 10)] + [(W, H)], fill=col))
    img = overlay(img, lambda d: d.polygon([(W * .45, H), (W * .62, H), (W * .52, H * .74), (W * .48, H * .74)], fill=(30, 26, 40, 255)))
    img = glow(img, lambda d: [d.line((W * .5, H * (.74 + i * .05), W * .5, H * (.76 + i * .05)), fill=(255, 220, 140), width=5) for i in range(6)], 6, 1.0)
    finish(img, 'moto_4', 23)

def moto5():
    img = vgrad('#08090c', '#10131a')
    def gear(d, cx, cy, R, n, col, wd):
        pts = []
        for i in range(n * 2):
            a = math.pi * i / n
            r_ = R if i % 2 == 0 else R * .84
            pts += [(cx + r_ * math.cos(a - .12), cy + r_ * math.sin(a - .12)), (cx + r_ * math.cos(a + .12), cy + r_ * math.sin(a + .12))]
        d.line(pts + [pts[0]], fill=col, width=wd)
        d.ellipse((cx - R * .5, cy - R * .5, cx + R * .5, cy + R * .5), outline=col, width=wd)
        d.ellipse((cx - R * .12, cy - R * .12, cx + R * .12, cy + R * .12), fill=col)
    def f(d, col, wd):
        gear(d, W * .38, H * .36, 190, 14, col, wd)
        gear(d, W * .78, H * .56, 120, 10, col, wd)
        gear(d, W * .3, H * .74, 150, 12, col, wd)
    img = glow(img, lambda d: f(d, (255, 120, 30), 8), 12, 1.0)
    img = overlay(img, lambda d: f(d, (255, 215, 170, 255), 2))
    finish(img, 'moto_5', 24)

def moto6():
    img = vgrad('#03040a', '#0a0c18')
    img = glow(img, lambda d: bike(d, 140, H * .5, 1.45, (30, 220, 255), 12), 14, 1.0)
    img = overlay(img, lambda d: bike(d, 140, H * .5, 1.45, (200, 250, 255, 255), 3))
    img = glow(img, lambda d: d.rectangle((60, H * .5 + 78 * 1.45 + 8, W - 60, H * .5 + 78 * 1.45 + 14), fill=(30, 200, 255)), 14, .8)
    finish(img, 'moto_6', 25)

# --------------------------------------------------------------- HACKERS
def hack1():
    r = random.Random(26)
    img = Image.new('RGB', (W, H), (2, 8, 4))
    f = ImageFont.truetype(MONO, 22)
    chars = '01ABCDEF0123456789<>{}/\\#$%'
    def rain(d, bright):
        for x in range(8, W, 26):
            L = r.randint(6, 34); y0 = r.randint(-200, H)
            for i in range(L):
                y = y0 + i * 26
                if 0 <= y <= H:
                    a = int(255 * (1 - i / L) ** 1.4)
                    c = (200, 255, 210) if (i == L - 1 and bright) else (0, min(255, 80 + a), 40)
                    d.text((x, y), r.choice(chars), font=f, fill=c if i < L - 1 else (210, 255, 220))
    d = ImageDraw.Draw(img); rain(d, True)
    img = glow(img, lambda dd: (lambda: None)(), 1)
    img = img.filter(ImageFilter.GaussianBlur(.6))
    img = glow(img, lambda dd: [dd.text((x, y), '0', font=f, fill=(0, 120, 40)) for x, y in [(r.randint(0, W), r.randint(0, H)) for _ in range(60)]], 6, .8)
    finish(img, 'hacker_1', 26)

def hack2():
    r = random.Random(27)
    img = vgrad('#04120e', '#02221c')
    def tr(d, col, wd):
        for _ in range(26):
            x, y = r.randint(40, W - 40), r.randint(40, H - 40)
            pts = [(x, y)]
            for _ in range(r.randint(3, 6)):
                if r.random() < .5: x += r.choice([-1, 1]) * r.randint(30, 140)
                else: y += r.choice([-1, 1]) * r.randint(30, 160)
                pts.append((x, y))
            d.line(pts, fill=col, width=wd, joint='curve')
            for p in (pts[0], pts[-1]):
                d.ellipse((p[0] - 8, p[1] - 8, p[0] + 8, p[1] + 8), outline=col, width=wd)
    st = r.getstate()
    img = glow(img, lambda d: tr(d, (0, 255, 200), 5), 8, 1.0)
    r.setstate(st)
    img = overlay(img, lambda d: tr(d, (150, 255, 230, 255), 2), 200)
    finish(img, 'hacker_2', 27)

def hack3():
    img = Image.new('RGB', (W, H), (6, 8, 10)); d = ImageDraw.Draw(img)
    f = ImageFont.truetype(MONO, 20)
    lines = ['$ nmap -sV -p- 10.0.0.0/24', 'Starting Nmap 7.94 ( https://nmap.org )', 'PORT    STATE SERVICE  VERSION', '22/tcp  open  ssh      OpenSSH 9.6', '80/tcp  open  http     nginx 1.24', '443/tcp open  https', '$ sudo ./exploit --target 10.0.0.7', '[+] connecting ...', '[+] payload delivered', '[+] shell opened', '# whoami', 'root', '# cat /etc/shadow | head', 'root:$6$sudosoc$....', '$ _']
    y = 70
    for i in range(int(H / 34)):
        t = lines[i % len(lines)]
        c = (60, 220, 120) if t.startswith(('$', '#')) else (110, 150, 140)
        d.text((36, y), t, font=f, fill=tuple(int(v * (0.35 + 0.65 * (1 - abs(y - H * .5) / (H * .6)))) for v in c))
        y += 34
    img = glow(img, lambda dd: dd.rectangle((36, H * .5, 56, H * .5 + 22), fill=(80, 255, 140)), 8, 1.0)
    finish(img, 'hacker_3', 28)

def hack4():
    img = vgrad('#04060e', '#0a1226')
    def hexes(d, col, wd):
        R = 46; dx = R * math.sqrt(3)
        for row in range(-1, int(H / (R * 1.5)) + 2):
            for c in range(-1, int(W / dx) + 2):
                cx = c * dx + (dx / 2 if row % 2 else 0); cy = row * R * 1.5
                pts = [(cx + R * math.cos(math.radians(60 * i + 30)), cy + R * math.sin(math.radians(60 * i + 30))) for i in range(6)]
                d.line(pts + [pts[0]], fill=col, width=wd)
    img = overlay(img, lambda d: hexes(d, (30, 60, 110, 255), 2))
    img = glow(img, lambda d: d.ellipse((W / 2 - 200, H * .42 - 200, W / 2 + 200, H * .42 + 200), fill=(0, 120, 255)), 100, .9)
    img = glow(img, lambda d: d.regular_polygon((W / 2, H * .42, 150), 6, rotation=0, outline=(0, 220, 255), width=8), 12, 1.0)
    img = overlay(img, lambda d: d.regular_polygon((W / 2, H * .42, 150), 6, rotation=0, outline=(210, 250, 255, 255), width=2))
    finish(img, 'hacker_4', 29)

def hack5():
    img = vgrad('#020608', '#06141a')
    f = ImageFont.truetype(MONO, 18)
    r = random.Random(30)
    d = ImageDraw.Draw(img)
    for y in range(0, H, 24):
        d.text((10, y), ''.join(r.choice('01') for _ in range(44)), font=f, fill=(0, 56, 44))
    cx, cy = W / 2, H * .46
    def hood(dd, col):
        dd.ellipse((cx - 200, cy + 150, cx + 200, cy + 600), fill=col)
        dd.ellipse((cx - 150, cy - 230, cx + 150, cy + 190), fill=col)
    img = overlay(img, lambda dd: hood(dd, (4, 10, 12, 255)))
    img = overlay(img, lambda dd: dd.ellipse((cx - 92, cy - 120, cx + 92, cy + 110), fill=(0, 0, 0, 255)))
    img = glow(img, lambda dd: [dd.ellipse((cx - 56, cy - 20, cx - 24, cy + 4), fill=(0, 255, 160)), dd.ellipse((cx + 24, cy - 20, cx + 56, cy + 4), fill=(0, 255, 160))], 10, 1.0)
    img = glow(img, lambda dd: dd.arc((cx - 160, cy - 240, cx + 160, cy + 200), 200, 340, fill=(0, 200, 130), width=5), 8, .9)
    finish(img, 'hacker_5', 30)

def hack6():
    img = vgrad('#05030c', '#0e0620')
    r = random.Random(31)
    def blocks(d, ox, col):
        for _ in range(26):
            x, y = r.randint(0, W), r.randint(0, H); w, h = r.randint(40, 300), r.randint(6, 26)
            d.rectangle((x + ox, y, x + w + ox, y + h), fill=col)
    for ox, col in [(-6, (255, 0, 80)), (6, (0, 255, 240))]:
        st = r.getstate()
        img = glow(img, lambda d, ox=ox, col=col: blocks(d, ox, tuple(int(v * .45) for v in col)), 2, 1.0)
    f = ImageFont.truetype(MONO, 44)
    for ox, col in [(-3, (255, 0, 90)), (3, (0, 255, 240)), (0, (235, 235, 245))]:
        d = ImageDraw.Draw(img)
        d.text((W / 2 + ox, H * .45), 'ACCESS', font=f, fill=col, anchor='mm')
        d.text((W / 2 + ox, H * .45 + 56), 'GRANTED', font=f, fill=col, anchor='mm')
    d = ImageDraw.Draw(img)
    for y in range(0, H, 4): d.line((0, y, W, y), fill=(0, 0, 0))
    finish(img, 'hacker_6', 31)

if __name__ == '__main__':
    for fn in [love1, love2, love3, love4, love5, love6, mystery1, mystery2, mystery3, mystery4, mystery5, mystery6,
               cars1, cars2, cars3, cars4, cars5, cars6, moto1, moto2, moto3, moto4, moto5, moto6,
               hack1, hack2, hack3, hack4, hack5, hack6]:
        fn(); print(fn.__name__)
    # contact sheet
    names = sorted(f for f in os.listdir(OUT) if f.endswith('.jpg'))
    tw, th = 150, 300
    sheet = Image.new('RGB', (tw * 6, th * ((len(names) + 5) // 6)))
    for i, n in enumerate(names):
        im = Image.open(os.path.join(OUT, n)).resize((tw, th))
        sheet.paste(im, ((i % 6) * tw, (i // 6) * th))
    sheet.save('/tmp/wall_sheet.png')
