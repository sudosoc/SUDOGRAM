"""Generates the 50 launcher icons, manifest aliases and the Dart catalog."""
import math, os, colorsys
from PIL import Image, ImageDraw, ImageFont, ImageChops

R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 512
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

def font(sz):
    return ImageFont.truetype(FONT, sz)

def grad(c1, c2):
    im = Image.new('RGB', (S, S))
    px = im.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * S)
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return im

def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def mask(shape):
    m = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(m)
    if shape == 'circle':
        d.ellipse((8, 8, S - 8, S - 8), fill=255)
    elif shape == 'squircle':
        d.rounded_rectangle((8, 8, S - 8, S - 8), radius=120, fill=255)
    elif shape == 'square':
        d.rounded_rectangle((8, 8, S - 8, S - 8), radius=40, fill=255)
    elif shape == 'hex':
        pts = [(S / 2 + 246 * math.cos(math.radians(60 * i + 30)), S / 2 + 246 * math.sin(math.radians(60 * i + 30))) for i in range(6)]
        d.polygon(pts, fill=255)
    elif shape == 'diamond':
        d.rounded_rectangle((70, 70, S - 70, S - 70), radius=50, fill=255)
        m = m.rotate(45, resample=Image.BICUBIC).resize((S, S))
        m = ImageChops.lighter(m, m)
    return m

W = (255, 255, 255)


import math
from PIL import ImageFilter

# ---------------------------------------------------------------- brand art
# Everything is the SUDOGRAM ghost + paper plane, in 10 colourways and 5
# treatments (10 x 5 = 50). Drawn at 1024 and scaled down for crisp edges.
B = 1024

def ghost_pts():
    pts = []
    cx, top, r = 512, 190, 240
    for i in range(0, 181, 6):
        a = math.radians(180 + i)
        pts.append((cx + r * math.cos(a), top + r + r * math.sin(a)))
    base = top + r
    for k in range(0, 61):
        t = k / 60
        x = cx + r - 2 * r * t
        y = 790 + 34 * math.cos(2 * math.pi * 3 * t) * -1 + 0
        pts.append((x, y))
    return pts

def plane_pts(dx=0, dy=0, sc=1.0):
    base = [(430, 590), (640, 505), (560, 705), (520, 630)]
    return [(512 + (x - 512) * sc + dx, 600 + (y - 600) * sc + dy) for x, y in base]

THEMES = [
 ('violet', 'Violet', 'بنفسجي', '#1a1446', '#6b46e0', '#4fa3ff', '#ffffff'),
 ('sunset', 'Sunset', 'غروب', '#3b0a45', '#ff6a3d', '#ffd166', '#ffffff'),
 ('ocean', 'Ocean', 'محيط', '#022b4a', '#0aa5d6', '#bdf2ff', '#ffffff'),
 ('emerald', 'Emerald', 'زمردي', '#04251c', '#10b981', '#fde68a', '#ffffff'),
 ('rose', 'Rose', 'وردي', '#3a0b25', '#ec4899', '#ffd1e8', '#ffffff'),
 ('gold', 'Gold', 'ذهبي', '#1c1405', '#d4a017', '#3a2a00', '#fff7da'),
 ('graphite', 'Graphite', 'جرافيت', '#0b0b0f', '#2c2c36', '#9aa4ff', '#e8e8f0'),
 ('snow', 'Snow', 'ثلجي', '#f4f4fa', '#cfd2e4', '#6c63ff', '#1d1d27'),
 ('crimson', 'Crimson', 'قرمزي', '#2a0508', '#e11d48', '#ffe4e6', '#ffffff'),
 ('mint', 'Mint', 'نعناع', '#073b3a', '#5eead4', '#0f172a', '#ffffff'),
]
STYLES = [
 ('classic', 'Classic', 'كلاسيك'),
 ('circle', 'Circle', 'دائرة'),
 ('outline', 'Outline', 'خطوط'),
 ('flat', 'Flat', 'مسطّح'),
 ('neon', 'Neon', 'نيون'),
]

def hexa(h, a=255):
    r, g, b = hexc(h)
    return (r, g, b, a)

def gradient(c1, c2, radial=False):
    im = Image.new('RGBA', (B, B))
    px = im.load()
    a, b = hexc(c1), hexc(c2)
    for y in range(B):
        for x in range(B):
            if radial:
                t = min(1.0, math.hypot(x - B * 0.5, y - B * 0.38) / (B * 0.75))
            else:
                t = (x * 0.35 + y * 0.65) / B
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)
    return im

def shape_mask(kind):
    m = Image.new('L', (B, B), 0)
    d = ImageDraw.Draw(m)
    if kind == 'circle':
        d.ellipse((14, 14, B - 14, B - 14), fill=255)
    else:
        d.rounded_rectangle((14, 14, B - 14, B - 14), radius=230, fill=255)
    return m

def poly_ring(d, pts, fill, w):
    d.line(pts + [pts[0]], fill=fill, width=w, joint='curve')

def g_ghost(d, fg, ac, cut):
    g = ghost_pts()
    d.polygon(g, fill=fg)
    for ex in (430, 594):
        d.ellipse((ex - 32, 445, ex + 32, 530), fill=cut)
    d.polygon(plane_pts(), fill=ac)

def g_plane(d, fg, ac, cut):
    d.polygon([(230, 560), (800, 240), (520, 615)], fill=fg)
    d.polygon([(520, 615), (800, 240), (610, 800)], fill=ac)
    d.polygon([(520, 615), (610, 800), (565, 650)], fill=cut)
    for i, (x, y, r) in enumerate([(300, 740, 26), (220, 800, 18), (150, 840, 11)]):
        d.ellipse((x - r, y - r, x + r, y + r), fill=ac)

def g_mono(d, fg, ac, cut):
    f = ImageFont.truetype(FONT, 760)
    d.text((512, 480), 'S', font=f, fill=fg, anchor='mm')
    d.rounded_rectangle((300, 830, 724, 880), radius=25, fill=ac)

def g_lock(d, fg, ac, cut):
    d.arc((340, 190, 684, 560), 180, 360, fill=ac, width=64)
    d.rectangle((340, 375, 404, 480), fill=ac)
    d.rectangle((620, 375, 684, 480), fill=ac)
    d.rounded_rectangle((270, 470, 754, 840), radius=70, fill=fg)
    d.ellipse((442, 560, 582, 700), fill=cut)
    d.polygon([(482, 660), (542, 660), (562, 770), (462, 770)], fill=cut)

def g_eye(d, fg, ac, cut):
    pts = []
    for i in range(0, 181, 5):
        a_ = math.radians(i)
        pts.append((512 + 340 * math.cos(a_), 512 - 210 * math.sin(a_)))
    for i in range(180, 361, 5):
        a_ = math.radians(i)
        pts.append((512 + 340 * math.cos(a_), 512 - 210 * math.sin(a_)))
    d.polygon(pts, fill=fg)
    d.ellipse((412, 412, 612, 612), fill=ac)
    d.ellipse((470, 470, 554, 554), fill=cut)
    d.line([(250, 250), (774, 774)], fill=cut, width=120)
    d.line([(250, 250), (774, 774)], fill=ac, width=64)

def g_term(d, fg, ac, cut):
    d.rounded_rectangle((170, 250, 854, 774), radius=70, fill=fg)
    d.rounded_rectangle((200, 330, 824, 744), radius=40, fill=cut)
    for i, x in enumerate((250, 320, 390)):
        d.ellipse((x - 18, 275, x + 18, 311), fill=ac if i == 0 else cut)
    d.line([(300, 450), (430, 540), (300, 630)], fill=ac, width=56, joint='curve')
    d.rounded_rectangle((480, 625, 680, 670), radius=22, fill=fg)

def g_hood(d, fg, ac, cut):
    d.ellipse((190, 760, 834, 1240), fill=fg)
    d.ellipse((270, 190, 754, 780), fill=fg)
    d.ellipse((380, 360, 644, 690), fill=cut)
    for ex in (452, 572):
        d.ellipse((ex - 22, 480, ex + 22, 530), fill=ac)

def g_shield(d, fg, ac, cut):
    d.polygon([(512, 190), (800, 290), (780, 570), (512, 850), (244, 570), (224, 290)], fill=fg)
    d.line([(380, 520), (480, 625), (660, 400)], fill=ac, width=70, joint='curve')

def g_bubble(d, fg, ac, cut):
    d.rounded_rectangle((200, 240, 824, 690), radius=170, fill=fg)
    d.polygon([(320, 670), (290, 830), (500, 685)], fill=fg)
    for i, x in enumerate((372, 512, 652)):
        d.ellipse((x - 40, 425, x + 40, 505), fill=ac if i == 1 else cut)

def g_finger(d, fg, ac, cut):
    for i, r in enumerate(range(60, 330, 52)):
        col = ac if i % 3 == 1 else fg
        d.arc((512 - r, 540 - r, 512 + r, 540 + r), 160 + i * 9, 380 - i * 7, fill=col, width=30)
    d.line([(512, 540), (512, 780)], fill=fg, width=30)

GLYPHS = [('ghost', 'Ghost', 'شبح', g_ghost), ('plane', 'Plane', 'طيارة', g_plane),
          ('mono', 'Monogram', 'حرف S', g_mono), ('lock', 'Lock', 'قفل', g_lock),
          ('eye', 'No-eye', 'عين مشطوبة', g_eye), ('term', 'Terminal', 'تيرمنال', g_term),
          ('hood', 'Hood', 'هودي', g_hood), ('shield', 'Shield', 'درع', g_shield),
          ('bubble', 'Bubble', 'فقاعة', g_bubble), ('finger', 'Print', 'بصمة', g_finger)]

PALETTES = [
 ('violet', 'Violet', 'بنفسجي', 'grad', '#1a1446', '#6b46e0', '#ffffff', '#4fa3ff'),
 ('sunset', 'Sunset', 'غروب', 'grad', '#3b0a45', '#ff6a3d', '#ffffff', '#ffd166'),
 ('ocean', 'Ocean', 'محيط', 'grad', '#022b4a', '#0aa5d6', '#ffffff', '#bdf2ff'),
 ('emerald', 'Emerald', 'زمردي', 'flat', '#04251c', '#10b981', '#ffffff', '#fde68a'),
 ('rose', 'Rose', 'وردي', 'grad', '#3a0b25', '#ec4899', '#ffffff', '#ffd1e8'),
 ('gold', 'Gold', 'ذهبي', 'dark', '#0c0a04', '#0c0a04', '#d4a017', '#fff0b0'),
 ('graphite', 'Graphite', 'جرافيت', 'dark', '#0b0b0f', '#0b0b0f', '#e8e8f0', '#7c86ff'),
 ('snow', 'Snow', 'ثلجي', 'light', '#f4f4fa', '#e2e4f2', '#1d1d27', '#6c63ff'),
 ('lime', 'Lime', 'ليموني', 'flat', '#0f1a05', '#a3e635', '#14210a', '#ffffff'),
 ('crimson', 'Crimson', 'قرمزي', 'grad', '#2a0505', '#e11d48', '#ffffff', '#fecdd3'),
]
SHAPES = ['squircle', 'circle', 'hex', 'square', 'tear']

def shape_mask(kind):
    m = Image.new('L', (B, B), 0)
    d = ImageDraw.Draw(m)
    if kind == 'circle':
        d.ellipse((14, 14, B - 14, B - 14), fill=255)
    elif kind == 'square':
        d.rounded_rectangle((14, 14, B - 14, B - 14), radius=70, fill=255)
    elif kind == 'hex':
        d.polygon([(B / 2 + 500 * math.cos(math.radians(60 * i + 30)), B / 2 + 500 * math.sin(math.radians(60 * i + 30))) for i in range(6)], fill=255)
    elif kind == 'tear':
        d.ellipse((14, 14, B - 14, B - 14), fill=255)
        d.rounded_rectangle((B // 2, 14, B - 14, B // 2), radius=40, fill=255)
    else:
        d.rounded_rectangle((14, 14, B - 14, B - 14), radius=230, fill=255)
    return m

def poly_ring(d, pts, fill, w):
    d.line(pts + [pts[0]], fill=fill, width=w, joint='curve')

def g_ghost(d, fg, ac, cut):
    g = ghost_pts()
    d.polygon(g, fill=fg)
    for ex in (430, 594):
        d.ellipse((ex - 32, 445, ex + 32, 530), fill=cut)
    d.polygon(plane_pts(), fill=ac)

def g_plane(d, fg, ac, cut):
    d.polygon([(230, 560), (800, 240), (520, 615)], fill=fg)
    d.polygon([(520, 615), (800, 240), (610, 800)], fill=ac)
    d.polygon([(520, 615), (610, 800), (565, 650)], fill=cut)
    for i, (x, y, r) in enumerate([(300, 740, 26), (220, 800, 18), (150, 840, 11)]):
        d.ellipse((x - r, y - r, x + r, y + r), fill=ac)

def g_mono(d, fg, ac, cut):
    f = ImageFont.truetype(FONT, 760)
    d.text((512, 480), 'S', font=f, fill=fg, anchor='mm')
    d.rounded_rectangle((300, 830, 724, 880), radius=25, fill=ac)

def g_lock(d, fg, ac, cut):
    d.arc((340, 190, 684, 560), 180, 360, fill=ac, width=64)
    d.rectangle((340, 375, 404, 480), fill=ac)
    d.rectangle((620, 375, 684, 480), fill=ac)
    d.rounded_rectangle((270, 470, 754, 840), radius=70, fill=fg)
    d.ellipse((442, 560, 582, 700), fill=cut)
    d.polygon([(482, 660), (542, 660), (562, 770), (462, 770)], fill=cut)

def g_eye(d, fg, ac, cut):
    pts = []
    for i in range(0, 181, 5):
        a_ = math.radians(i)
        pts.append((512 + 340 * math.cos(a_), 512 - 210 * math.sin(a_)))
    for i in range(180, 361, 5):
        a_ = math.radians(i)
        pts.append((512 + 340 * math.cos(a_), 512 - 210 * math.sin(a_)))
    d.polygon(pts, fill=fg)
    d.ellipse((412, 412, 612, 612), fill=ac)
    d.ellipse((470, 470, 554, 554), fill=cut)
    d.line([(250, 250), (774, 774)], fill=cut, width=120)
    d.line([(250, 250), (774, 774)], fill=ac, width=64)

def g_term(d, fg, ac, cut):
    d.rounded_rectangle((170, 250, 854, 774), radius=70, fill=fg)
    d.rounded_rectangle((200, 330, 824, 744), radius=40, fill=cut)
    for i, x in enumerate((250, 320, 390)):
        d.ellipse((x - 18, 275, x + 18, 311), fill=ac if i == 0 else cut)
    d.line([(300, 450), (430, 540), (300, 630)], fill=ac, width=56, joint='curve')
    d.rounded_rectangle((480, 625, 680, 670), radius=22, fill=fg)

def g_hood(d, fg, ac, cut):
    d.ellipse((190, 760, 834, 1240), fill=fg)
    d.ellipse((270, 190, 754, 780), fill=fg)
    d.ellipse((380, 360, 644, 690), fill=cut)
    for ex in (452, 572):
        d.ellipse((ex - 22, 480, ex + 22, 530), fill=ac)

def g_shield(d, fg, ac, cut):
    d.polygon([(512, 190), (800, 290), (780, 570), (512, 850), (244, 570), (224, 290)], fill=fg)
    d.line([(380, 520), (480, 625), (660, 400)], fill=ac, width=70, joint='curve')

def g_bubble(d, fg, ac, cut):
    d.rounded_rectangle((200, 240, 824, 690), radius=170, fill=fg)
    d.polygon([(320, 670), (290, 830), (500, 685)], fill=fg)
    for i, x in enumerate((372, 512, 652)):
        d.ellipse((x - 40, 425, x + 40, 505), fill=ac if i == 1 else cut)

def g_finger(d, fg, ac, cut):
    for i, r in enumerate(range(60, 330, 52)):
        col = ac if i % 3 == 1 else fg
        d.arc((512 - r, 540 - r, 512 + r, 540 + r), 160 + i * 9, 380 - i * 7, fill=col, width=30)
    d.line([(512, 540), (512, 780)], fill=fg, width=30)

GLYPHS = [('ghost', 'Ghost', 'شبح', g_ghost), ('plane', 'Plane', 'طيارة', g_plane),
          ('mono', 'Monogram', 'حرف S', g_mono), ('lock', 'Lock', 'قفل', g_lock),
          ('eye', 'No-eye', 'عين مشطوبة', g_eye), ('term', 'Terminal', 'تيرمنال', g_term),
          ('hood', 'Hood', 'هودي', g_hood), ('shield', 'Shield', 'درع', g_shield),
          ('bubble', 'Bubble', 'فقاعة', g_bubble), ('finger', 'Print', 'بصمة', g_finger)]

PALETTES = [
 ('violet', 'Violet', 'بنفسجي', 'grad', '#1a1446', '#6b46e0', '#ffffff', '#4fa3ff'),
 ('sunset', 'Sunset', 'غروب', 'grad', '#3b0a45', '#ff6a3d', '#ffffff', '#ffd166'),
 ('ocean', 'Ocean', 'محيط', 'grad', '#022b4a', '#0aa5d6', '#ffffff', '#bdf2ff'),
 ('emerald', 'Emerald', 'زمردي', 'flat', '#04251c', '#10b981', '#ffffff', '#fde68a'),
 ('rose', 'Rose', 'وردي', 'grad', '#3a0b25', '#ec4899', '#ffffff', '#ffd1e8'),
 ('gold', 'Gold', 'ذهبي', 'dark', '#0c0a04', '#0c0a04', '#d4a017', '#fff0b0'),
 ('graphite', 'Graphite', 'جرافيت', 'dark', '#0b0b0f', '#0b0b0f', '#e8e8f0', '#7c86ff'),
 ('snow', 'Snow', 'ثلجي', 'light', '#f4f4fa', '#e2e4f2', '#1d1d27', '#6c63ff'),
 ('lime', 'Lime', 'ليموني', 'flat', '#0f1a05', '#a3e635', '#14210a', '#ffffff'),
 ('crimson', 'Crimson', 'قرمزي', 'grad', '#2a0505', '#e11d48', '#ffffff', '#fecdd3'),
]
SHAPES = ['squircle', 'circle', 'hex', 'square', 'tear']

def shape_mask(kind):
    m = Image.new('L', (B, B), 0)
    d = ImageDraw.Draw(m)
    if kind == 'circle':
        d.ellipse((14, 14, B - 14, B - 14), fill=255)
    elif kind == 'square':
        d.rounded_rectangle((14, 14, B - 14, B - 14), radius=70, fill=255)
    elif kind == 'hex':
        d.polygon([(B / 2 + 500 * math.cos(math.radians(60 * i + 30)), B / 2 + 500 * math.sin(math.radians(60 * i + 30))) for i in range(6)], fill=255)
    elif kind == 'diamond':
        big = Image.new('L', (B, B), 0)
        ImageDraw.Draw(big).rounded_rectangle((170, 170, B - 170, B - 170), radius=110, fill=255)
        m = big.rotate(45, resample=Image.BICUBIC)
        m = m.resize((int(B * 1.36), int(B * 1.36)), Image.BICUBIC).crop((int(B * 0.18), int(B * 0.18), int(B * 0.18) + B, int(B * 0.18) + B))
    else:
        d.rounded_rectangle((14, 14, B - 14, B - 14), radius=230, fill=255)
    return m

def render_brand(glyph, pal, shape):
    _, _, _, mode, c1, c2, fg, ac = pal
    if mode == 'flat':
        bg = Image.new('RGBA', (B, B), hexa(c2)); cut = hexa(c2)
    elif mode in ('dark', 'light'):
        bg = Image.new('RGBA', (B, B), hexa(c1)); cut = hexa(c1)
    else:
        bg = gradient(c1, c2, radial=(shape == 'circle')); cut = hexa(c1)
    art = Image.new('RGBA', (B, B), (0, 0, 0, 0))
    d = ImageDraw.Draw(art)
    glyph(d, hexa(fg), hexa(ac), cut)
    if shape == 'hex':
        art = art.resize((int(B * 0.8), int(B * 0.8)), Image.LANCZOS)
        full = Image.new('RGBA', (B, B), (0, 0, 0, 0))
        full.paste(art, (int(B * 0.1), int(B * 0.1)))
        art = full
    if mode == 'dark':
        ImageDraw.Draw(bg).ellipse((60, 60, B - 60, B - 60), outline=hexa(ac, 90), width=10)
    comp = bg.copy()
    comp.alpha_composite(art)
    out = Image.new('RGBA', (B, B), (0, 0, 0, 0))
    out.paste(comp, (0, 0), shape_mask(shape))
    return out.resize((192, 192), Image.LANCZOS)

SPECS = []
for fi, gl in enumerate(GLYPHS):
    for v in range(5):
        pal = PALETTES[(fi + v * 2) % 10]
        shape = SHAPES[(v + fi) % 5]
        if fi == 0 and v == 0:
            SPECS.append(('sudogram', 'SUDOGRAM', 'سودوجرام (الأصلية)', None))
            continue
        SPECS.append(('%s_%s' % (gl[0], pal[0]), '%s · %s' % (gl[1], pal[1]), '%s · %s' % (gl[2], pal[2]), (gl[3], pal, shape)))
assert len(SPECS) == 50, len(SPECS)

def main():
    dr = os.path.join(R, 'android/app/src/main/res/drawable-nodpi')
    os.makedirs(dr, exist_ok=True)
    aliases = []
    dart = []
    for i, sp in enumerate(SPECS):
        icon = '@mipmap/ic_launcher'
        if sp[3] is not None:
            render_brand(*sp[3]).save(os.path.join(dr, 'ic_l%02d.png' % i))
            icon = '@drawable/ic_l%02d' % i
        en = 'SUDOGRAM'
        aliases.append(
            '        <activity-alias android:name=".Alias%02d" android:targetActivity=".MainActivity" android:enabled="%s" android:exported="true" android:icon="%s" android:label="%s">\n'
            '            <intent-filter>\n                <action android:name="android.intent.action.MAIN"/>\n                <category android:name="android.intent.category.LAUNCHER"/>\n            </intent-filter>\n        </activity-alias>'
            % (i, 'true' if i == 0 else 'false', icon, en))
        dart.append("  LauncherIcon(%d, '%s', '%s', '%s')," % (i, sp[0], sp[1], sp[2]))
    mf = os.path.join(R, 'android/app/src/main/AndroidManifest.xml')
    s = open(mf).read()
    a = s.find('        <!-- LAUNCHER-ALIASES-BEGIN -->')
    if a >= 0:
        b = s.index('<!-- LAUNCHER-ALIASES-END -->') + len('<!-- LAUNCHER-ALIASES-END -->\n')
        s = s[:a] + s[b:]
    block = '        <!-- LAUNCHER-ALIASES-BEGIN -->\n' + '\n'.join(aliases) + '\n        <!-- LAUNCHER-ALIASES-END -->\n'
    s = s.replace('        <!-- Don\'t delete the meta-data below.', block + '        <!-- Don\'t delete the meta-data below.', 1)
    open(mf, 'w').write(s)
    open(os.path.join(R, 'lib/features/settings/launcher_icons.g.dart'), 'w').write(
        "// GENERATED by tools/gen_launcher_icons.py\nclass LauncherIcon {\n  const LauncherIcon(this.index, this.id, this.en, this.ar);\n  final int index;\n  final String id;\n  final String en;\n  final String ar;\n}\n\nconst kLauncherIcons = <LauncherIcon>[\n" + '\n'.join(dart) + '\n];\n')
    # contact sheet for eyeballing
    asd = os.path.join(R, 'assets/launcher')
    os.makedirs(asd, exist_ok=True)
    import shutil
    for i in range(50):
        pp = os.path.join(dr, 'ic_l%02d.png' % i)
        if os.path.exists(pp):
            shutil.copy(pp, os.path.join(asd, 'ic_l%02d.png' % i))
    sheet = Image.new('RGBA', (10 * 100, 5 * 100), (30, 30, 34, 255))
    for i, sp in enumerate(SPECS):
        p = os.path.join(dr, 'ic_l%02d.png' % i)
        im = Image.open(p) if os.path.exists(p) else Image.open(os.path.join(R, 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'))
        im = im.convert('RGBA').resize((90, 90))
        sheet.alpha_composite(im, ((i % 10) * 100 + 5, (i // 10) * 100 + 5))
    sheet.save('/tmp/launcher_sheet.png')

main()
