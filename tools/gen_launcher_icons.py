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

def render_brand(theme, style):
    _, _, _, c1, c2, acc, ghostc = theme
    dark_ghost = sum(hexc(ghostc)) < 300
    eye = hexa('#ffffff') if dark_ghost else hexa(c1)
    if style == 'flat':
        bg = Image.new('RGBA', (B, B), hexa(c2))
        eye = hexa(c2)
    elif style == 'neon':
        bg = Image.new('RGBA', (B, B), hexa('#07070b'))
    else:
        bg = gradient(c1, c2, radial=(style == 'circle'))
    art = Image.new('RGBA', (B, B), (0, 0, 0, 0))
    d = ImageDraw.Draw(art)
    g = ghost_pts()
    if style == 'neon':
        acc = acc if sum(hexc(acc)) > 330 else c2
        glow = Image.new('RGBA', (B, B), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.line(g + [g[0]], fill=hexa(acc), width=34, joint='curve')
        gd.polygon(plane_pts(), fill=hexa(acc))
        for ex in (430, 594):
            gd.ellipse((ex - 34, 440, ex + 34, 530), fill=hexa(acc))
        art.alpha_composite(glow.filter(ImageFilter.GaussianBlur(28)))
        art.alpha_composite(glow.filter(ImageFilter.GaussianBlur(8)))
        d = ImageDraw.Draw(art)
        d.line(g + [g[0]], fill=hexa(acc), width=20, joint='curve')
        d.polygon(plane_pts(), fill=hexa(acc))
        for ex in (430, 594):
            d.ellipse((ex - 30, 445, ex + 30, 525), fill=hexa(acc))
    elif style == 'outline':
        d.line(g + [g[0]], fill=hexa(ghostc), width=40, joint='curve')
        d.polygon(plane_pts(), fill=hexa(acc))
        for ex in (430, 594):
            d.ellipse((ex - 30, 445, ex + 30, 525), fill=hexa(ghostc))
    else:
        if style == 'classic':
            sh = Image.new('RGBA', (B, B), (0, 0, 0, 0))
            ImageDraw.Draw(sh).polygon([(x, y + 26) for x, y in g], fill=(0, 0, 0, 110))
            art.alpha_composite(sh.filter(ImageFilter.GaussianBlur(22)))
            d = ImageDraw.Draw(art)
        d.polygon(g, fill=hexa(ghostc))
        for ex in (430, 594):
            d.ellipse((ex - 30, 445, ex + 30, 525), fill=eye)
        d.polygon(plane_pts(), fill=hexa(acc))
        d.line([(520, 630), (640, 505)], fill=hexa(ghostc, 150), width=8)
    out = Image.new('RGBA', (B, B), (0, 0, 0, 0))
    comp = bg.copy()
    comp.alpha_composite(art)
    out.paste(comp, (0, 0), shape_mask('circle' if style == 'circle' else 'squircle'))
    return out.resize((192, 192), Image.LANCZOS)

SPECS = [('sudogram', 'SUDOGRAM', 'سودوجرام (الأصلية)', None)]
for th in THEMES:
    for st in STYLES:
        if th[0] == 'violet' and st[0] == 'classic':
            continue
        SPECS.append(('%s_%s' % (th[0], st[0]), '%s · %s' % (th[1], st[1]), '%s · %s' % (th[2], st[2]), (th, st[0])))
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
    sheet = Image.new('RGBA', (10 * 100, 5 * 100), (30, 30, 34, 255))
    for i, sp in enumerate(SPECS):
        p = os.path.join(dr, 'ic_l%02d.png' % i)
        im = Image.open(p) if os.path.exists(p) else Image.open(os.path.join(R, 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'))
        im = im.convert('RGBA').resize((90, 90))
        sheet.alpha_composite(im, ((i % 10) * 100 + 5, (i // 10) * 100 + 5))
    sheet.save('/tmp/launcher_sheet.png')

main()
