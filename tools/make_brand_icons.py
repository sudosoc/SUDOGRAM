#!/usr/bin/env python3
"""Builds extra launcher icons from user-supplied logo screenshots + a glass S."""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops
U = '/mnt/user-data/uploads/'
OUT = os.path.join(os.path.dirname(__file__), '..', 'android/app/src/main/res/drawable-nodpi')
ASSETS = os.path.join(os.path.dirname(__file__), '..', 'assets/launcher')

def rounded(im, r_frac):
    im = im.convert('RGB').resize((192, 192), Image.LANCZOS)
    m = Image.new('L', (768, 768), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 767, 767), radius=int(768 * r_frac), fill=255)
    m = m.resize((192, 192), Image.LANCZOS)
    o = Image.new('RGBA', (192, 192), (0, 0, 0, 0)); o.paste(im, (0, 0), m); return o

def crop(name, box): return Image.open(U + name).crop(box)

icons = {}
icons[52] = rounded(crop('253c6475-image.jpg', (40, 664, 1042, 1702)), .25)
icons[53] = rounded(crop('dd231f12-image.jpg', (26, 650, 1056, 1690)), .25)
icons[55] = rounded(crop('9ff320d3-image.jpg', (0, 600, 1080, 1680)), .22)

# ---- glass S in the style of the glass "A" tile
S = 1024
def centerline():
    pts = []
    for i in range(0, 141):                 # upper arc
        a = math.radians(-30 - i * (240 / 140))
        pts.append((512 + 175 * math.cos(a), 380 + 158 * math.sin(a)))
    for i in range(0, 141):                 # lower arc
        a = math.radians(-90 + i * (240 / 140))
        pts.append((512 + 175 * math.cos(a), 690 + 158 * math.sin(a) ))
    return pts
pts = centerline()
def stroke(width, off=(0, 0), fill=255):
    m = Image.new('L', (S, S), 0); d = ImageDraw.Draw(m)
    for i, (x, y) in enumerate(pts):
        t = i / (len(pts) - 1)
        end = max(0, 1 - min(t, 1 - t) * 9)      # swell the two terminals
        r = width / 2 + 34 * end
        d.ellipse((x + off[0] - r, y + off[1] - r, x + off[0] + r, y + off[1] + r), fill=fill)
    return m
body = stroke(150)
bg = Image.new('RGB', (S, S))
px = bg.load()
for y in range(S):
    for x in range(S):
        t = y / S
        px[x, y] = (int(52 - 26 * t), int(54 - 26 * t), int(62 - 28 * t))
tile = bg.convert('RGBA')
# soft rim of the tile
rim = Image.new('L', (S, S), 0); ImageDraw.Draw(rim).rounded_rectangle((8, 8, S - 9, S - 9), radius=210, outline=255, width=6)
rim = rim.filter(ImageFilter.GaussianBlur(2))
tile.paste(Image.new('RGBA', (S, S), (150, 160, 175, 255)), (0, 0), rim.point(lambda v: int(v * .55)))
# glow
glow = Image.new('RGB', (S, S), (0, 0, 0))
glow.paste(Image.new('RGB', (S, S), (40, 210, 200)), (0, 0), stroke(190).filter(ImageFilter.GaussianBlur(46)))
tile = ImageChops.screen(tile.convert('RGB'), glow.point(lambda v: int(v * .75))).convert('RGBA')
# glass body
g = Image.new('RGBA', (S, S), (0, 0, 0, 0))
gp = g.load()
body_px = body.load()
for y in range(S):
    for x in range(S):
        a = body_px[x, y]
        if a:
            t = (y - 230) / 650
            col = (int(120 + 40 * (1 - t)), int(215 - 20 * t), int(222 - 10 * t))
            gp[x, y] = (col[0], col[1], col[2], int(a * .62))
tile.alpha_composite(g)
# hollow core (darker, inside)
core = stroke(58, off=(4, 6)); core_a = Image.new('RGBA', (S, S), (10, 60, 70, 0)); core_a.putalpha(core.point(lambda v: int(v * .55)))
core_a = Image.composite(core_a, Image.new('RGBA', (S, S), (0, 0, 0, 0)), body)
tile.alpha_composite(core_a)
# bright edges: highlight top-left, caustic bottom-right
def edge(off, col, alpha, width_sub):
    inner = stroke(150 - width_sub, off=off)
    band = ImageChops.subtract(body, inner)
    lay = Image.new('RGBA', (S, S), col + (0,)); lay.putalpha(band.point(lambda v: int(v * alpha)))
    return lay.filter(ImageFilter.GaussianBlur(3))
tile.alpha_composite(edge((14, 16), (235, 255, 255), .9, 10))
tile.alpha_composite(edge((-12, -14), (120, 255, 235), .75, 8))
# specular streaks
spec = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(spec)
for (x0, y0, x1, y1) in [(395, 330, 520, 262), (610, 650, 520, 724)]:
    d.line((x0, y0, x1, y1), fill=(255, 255, 255, 210), width=14)
spec = spec.filter(ImageFilter.GaussianBlur(5))
spec.putalpha(ImageChops.multiply(spec.split()[3], body))
tile.alpha_composite(spec)
# crop padding like the original: tile fills the icon
m = Image.new('L', (S * 2, S * 2), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, S * 2 - 1, S * 2 - 1), radius=int(S * 2 * .24), fill=255)
m = m.resize((S, S), Image.LANCZOS)
final = Image.new('RGBA', (S, S), (0, 0, 0, 0)); final.paste(tile.convert('RGB'), (0, 0), m)
icons[54] = final.resize((192, 192), Image.LANCZOS)

for i, im in icons.items():
    im.save(os.path.join(OUT, 'ic_l%02d.png' % i)); im.save(os.path.join(ASSETS, 'ic_l%02d.png' % i))
sheet = Image.new('RGBA', (4 * 200, 200), (36, 36, 40, 255))
for k, i in enumerate(sorted(icons)): sheet.alpha_composite(icons[i], (k * 200 + 4, 4))
sheet.save('/tmp/newicons.png')
