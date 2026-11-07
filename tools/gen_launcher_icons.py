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

# ---- glyphs, drawn on a 512 canvas in white / accent -------------------
def g_calc(d, a):
    d.rounded_rectangle((130, 100, 382, 200), 18, fill=W)
    for r in range(3):
        for c in range(3):
            d.rounded_rectangle((130 + c * 90, 230 + r * 70, 130 + c * 90 + 72, 230 + r * 70 + 54), 12, fill=W)
def g_notes(d, a):
    d.rounded_rectangle((120, 90, 392, 422), 24, fill=W)
    for i in range(5):
        d.line((160, 160 + i * 52, 352, 160 + i * 52), fill=a, width=10)
def g_clock(d, a):
    d.ellipse((100, 100, 412, 412), outline=W, width=22)
    d.line((256, 256, 256, 150), fill=W, width=20); d.line((256, 256, 330, 290), fill=W, width=20)
def g_cal(d, a):
    d.rounded_rectangle((105, 120, 407, 410), 30, fill=W)
    d.rounded_rectangle((105, 120, 407, 200), 30, fill=a)
    for r in range(3):
        for c in range(4):
            d.ellipse((140 + c * 66, 225 + r * 58, 170 + c * 66, 255 + r * 58), fill=a)
def g_weather(d, a):
    d.ellipse((130, 90, 280, 240), fill=(255, 214, 10))
    for (x, y, r) in ((200, 330, 70), (270, 300, 90), (350, 340, 62)):
        d.ellipse((x - r, y - r, x + r, y + r), fill=W)
    d.rectangle((200, 330, 350, 400), fill=W)
def g_compass(d, a):
    d.ellipse((100, 100, 412, 412), outline=W, width=18)
    d.polygon([(256, 150), (290, 256), (222, 256)], fill=(255, 69, 58))
    d.polygon([(256, 362), (290, 256), (222, 256)], fill=W)
def g_torch(d, a):
    d.polygon([(200, 90), (312, 90), (340, 180), (172, 180)], fill=W)
    d.rounded_rectangle((200, 180, 312, 420), 30, fill=W)
    d.ellipse((236, 260, 276, 300), fill=a)
def g_folder(d, a):
    d.rounded_rectangle((90, 160, 422, 400), 28, fill=W)
    d.rounded_rectangle((90, 120, 230, 200), 22, fill=W)
def g_gallery(d, a):
    d.rounded_rectangle((95, 120, 417, 392), 28, fill=W)
    d.polygon([(120, 370), (230, 230), (320, 340)], fill=a)
    d.polygon([(250, 370), (330, 270), (400, 370)], fill=a)
    d.ellipse((330, 150, 380, 200), fill=(255, 200, 0))
def g_music(d, a):
    d.line((200, 120, 200, 360), fill=W, width=26); d.line((330, 100, 330, 330), fill=W, width=26)
    d.line((200, 120, 330, 100), fill=W, width=30)
    d.ellipse((130, 330, 220, 410), fill=W); d.ellipse((270, 300, 360, 380), fill=W)
def g_radio(d, a):
    d.rounded_rectangle((90, 190, 422, 410), 30, fill=W)
    d.line((140, 190, 380, 100), fill=W, width=14)
    d.ellipse((130, 240, 260, 370), outline=a, width=14)
    for i in range(3):
        d.line((300, 260 + i * 36, 390, 260 + i * 36), fill=a, width=12)
def g_news(d, a):
    d.rounded_rectangle((100, 110, 412, 402), 24, fill=W)
    d.rectangle((135, 150, 250, 230), fill=a)
    for i in range(5):
        d.line((270 if i < 3 else 135, 155 + i * 46, 380, 155 + i * 46), fill=a, width=10)
def g_pin(d, a):
    d.polygon([(256, 440), (150, 250), (362, 250)], fill=W)
    d.ellipse((140, 80, 372, 312), fill=W)
    d.ellipse((216, 156, 296, 236), fill=a)
def g_battery(d, a):
    d.rounded_rectangle((90, 170, 390, 342), 26, outline=W, width=18)
    d.rectangle((400, 220, 428, 292), fill=W)
    d.rectangle((118, 198, 300, 314), fill=(52, 199, 89))
def g_mic(d, a):
    d.rounded_rectangle((196, 90, 316, 290), 60, fill=W)
    d.arc((150, 190, 362, 360), 0, 180, fill=W, width=18)
    d.line((256, 360, 256, 420), fill=W, width=18); d.line((200, 420, 312, 420), fill=W, width=18)
def g_qr(d, a):
    for (x, y) in ((110, 110), (300, 110), (110, 300)):
        d.rectangle((x, y, x + 100, y + 100), outline=W, width=16); d.rectangle((x + 30, y + 30, x + 70, y + 70), fill=W)
    for (x, y) in ((300, 300), (350, 340), (310, 380), (380, 300), (240, 240)):
        d.rectangle((x, y, x + 36, y + 36), fill=W)
def g_translate(d, a):
    d.text((256, 200), 'A', font=font(190), fill=W, anchor='mm')
    d.text((300, 340), 'ع', font=font(150), fill=a, anchor='mm')
def g_book(d, a):
    d.polygon([(256, 140), (110, 120), (110, 380), (256, 400)], fill=W)
    d.polygon([(256, 140), (402, 120), (402, 380), (256, 400)], fill=(230, 230, 235))
    d.line((256, 140, 256, 400), fill=a, width=10)
def g_camera(d, a):
    d.rounded_rectangle((90, 160, 422, 390), 36, fill=W)
    d.rectangle((190, 120, 320, 175), fill=W)
    d.ellipse((186, 200, 326, 340), fill=a); d.ellipse((216, 230, 296, 310), fill=W)
def g_dialer(d, a):
    for r in range(4):
        for c in range(3):
            d.ellipse((135 + c * 100, 100 + r * 85, 185 + c * 100, 150 + r * 85), fill=W)
def g_mail(d, a):
    d.rounded_rectangle((90, 140, 422, 380), 28, fill=W)
    d.line((100, 160, 256, 280), fill=a, width=16); d.line((412, 160, 256, 280), fill=a, width=16)
def g_cart(d, a):
    d.line((90, 130, 150, 130), fill=W, width=22); d.line((150, 130, 190, 320), fill=W, width=22)
    d.polygon([(165, 190), (420, 190), (390, 310), (190, 310)], fill=W)
    d.ellipse((190, 350, 240, 400), fill=W); d.ellipse((340, 350, 390, 400), fill=W)
def g_wallet(d, a):
    d.rounded_rectangle((90, 150, 422, 392), 32, fill=W)
    d.rounded_rectangle((300, 240, 422, 310), 20, fill=a); d.ellipse((335, 262, 365, 292), fill=W)
def g_game(d, a):
    d.rounded_rectangle((70, 180, 442, 360), 80, fill=W)
    d.rectangle((140, 240, 200, 260), fill=a); d.rectangle((160, 220, 180, 280), fill=a)
    d.ellipse((290, 235, 330, 275), fill=a); d.ellipse((345, 270, 385, 310), fill=a)
def g_stopwatch(d, a):
    d.ellipse((100, 130, 412, 442), outline=W, width=22)
    d.rectangle((226, 80, 286, 120), fill=W)
    d.line((256, 286, 256, 190), fill=W, width=18); d.line((256, 286, 320, 320), fill=a, width=18)
def g_bell(d, a):
    d.pieslice((140, 120, 372, 380), 180, 360, fill=W)
    d.rectangle((140, 250, 372, 360), fill=W); d.rectangle((110, 345, 402, 378), fill=W)
    d.ellipse((226, 385, 286, 435), fill=W)
def g_phones(d, a):
    d.arc((120, 110, 392, 380), 180, 360, fill=W, width=26)
    d.rounded_rectangle((100, 250, 170, 390), 26, fill=W); d.rounded_rectangle((342, 250, 412, 390), 26, fill=W)
def g_heart(d, a):
    d.ellipse((100, 130, 262, 292), fill=W); d.ellipse((250, 130, 412, 292), fill=W)
    d.polygon([(106, 235), (406, 235), (256, 410)], fill=W)
def g_thermo(d, a):
    d.rounded_rectangle((216, 80, 296, 330), 40, fill=W)
    d.ellipse((176, 290, 336, 450), fill=W)
    d.rounded_rectangle((242, 160, 270, 360), 12, fill=a); d.ellipse((210, 330, 302, 420), fill=a)
def g_ruler(d, a):
    d.polygon([(90, 330), (330, 90), (422, 182), (182, 422)], fill=W)
    for i in range(6):
        t = 0.12 + i * 0.15
        x = 90 + (182 - 90) * t * 0 + 120 * i * 0.9
def g_dice(d, a):
    d.rounded_rectangle((110, 110, 402, 402), 48, fill=W)
    for (x, y) in ((170, 170), (342, 170), (256, 256), (170, 342), (342, 342)):
        d.ellipse((x - 26, y - 26, x + 26, y + 26), fill=a)
def g_cloud(d, a):
    for (x, y, r) in ((190, 290, 80), (270, 250, 100), (350, 300, 70)):
        d.ellipse((x - r, y - r, x + r, y + r), fill=W)
    d.rectangle((190, 290, 350, 370), fill=W)
def g_wifi(d, a):
    for i, r in enumerate((60, 130, 200)):
        d.arc((256 - r, 380 - r, 256 + r, 380 + r), 225, 315, fill=W, width=26)
    d.ellipse((232, 360, 280, 408), fill=W)
def g_shield(d, a):
    d.polygon([(256, 80), (410, 140), (400, 300), (256, 440), (112, 300), (102, 140)], fill=W)
    d.line((190, 260, 240, 310), fill=a, width=26); d.line((240, 310, 330, 200), fill=a, width=26)
def g_lock(d, a):
    d.arc((170, 80, 342, 280), 180, 360, fill=W, width=34); d.line((170, 180, 170, 240), fill=W, width=34); d.line((342, 180, 342, 240), fill=W, width=34)
    d.rounded_rectangle((120, 230, 392, 420), 34, fill=W); d.ellipse((232, 290, 280, 338), fill=a); d.rectangle((248, 320, 264, 380), fill=a)
def g_chart(d, a):
    for i, h in enumerate((120, 200, 160, 280)):
        d.rounded_rectangle((110 + i * 80, 410 - h, 170 + i * 80, 410), 12, fill=W)
def g_todo(d, a):
    for i in range(3):
        d.rounded_rectangle((110, 130 + i * 100, 160, 180 + i * 100), 12, outline=W, width=12)
        d.line((190, 155 + i * 100, 400, 155 + i * 100), fill=W, width=16)
    d.line((120, 155, 135, 172), fill=W, width=12)
def g_vpn(d, a):
    d.ellipse((100, 100, 412, 412), outline=W, width=18)
    d.ellipse((190, 100, 322, 412), outline=W, width=14); d.line((100, 256, 412, 256), fill=W, width=14)
def g_ghost(d, a):
    d.pieslice((120, 90, 392, 360), 180, 360, fill=W)
    d.rectangle((120, 225, 392, 400), fill=W)
    for i in range(3):
        d.pieslice((120 + i * 91, 360, 211 + i * 91, 440), 0, 180, fill=(0, 0, 0, 0))
    d.ellipse((190, 210, 235, 265), fill=a); d.ellipse((277, 210, 322, 265), fill=a)
def g_plane(d, a):
    d.polygon([(90, 270), (430, 100), (330, 420), (260, 320)], fill=W)
    d.line((260, 320, 430, 100), fill=a, width=14)
def g_dots(d, a):
    for r in range(3):
        for c in range(3):
            d.ellipse((130 + c * 100, 130 + r * 100, 190 + c * 100, 190 + r * 100), fill=W)
def g_leaf(d, a):
    d.pieslice((100, 100, 412, 412), 90, 270, fill=W)
    d.pieslice((100, 100, 412, 412), 270, 450, fill=(255, 255, 255, 0))
    d.polygon([(110, 410), (400, 110), (400, 300), (250, 420)], fill=W)
def g_bolt(d, a):
    d.polygon([(290, 70), (150, 280), (240, 280), (210, 440), (370, 210), (275, 210)], fill=W)

# (id, en label, ar label, glyph, c1, c2, shape)
SPECS = [
 ('sudogram', 'SUDOGRAM', 'سودوجرام', None, None, None, None),
 ('calculator', 'Calculator', 'الآلة الحاسبة', g_calc, '#ff9f0a', '#ff6b00', 'squircle'),
 ('notes', 'Notes', 'الملاحظات', g_notes, '#ffd60a', '#f5a300', 'squircle'),
 ('clock', 'Clock', 'الساعة', g_clock, '#1c1c1e', '#3a3a3c', 'circle'),
 ('calendar', 'Calendar', 'التقويم', g_cal, '#ff453a', '#c9302c', 'squircle'),
 ('weather', 'Weather', 'الطقس', g_weather, '#4aa3ff', '#1b6fe0', 'squircle'),
 ('compass', 'Compass', 'البوصلة', g_compass, '#3a3a3c', '#1c1c1e', 'circle'),
 ('flashlight', 'Flashlight', 'كشاف', g_torch, '#2c2c2e', '#000000', 'squircle'),
 ('files', 'Files', 'الملفات', g_folder, '#34a0ff', '#0a60d0', 'squircle'),
 ('gallery', 'Gallery', 'المعرض', g_gallery, '#bf5af2', '#6e40c9', 'squircle'),
 ('music', 'Music', 'الموسيقى', g_music, '#ff375f', '#c2185b', 'squircle'),
 ('radio', 'Radio', 'الراديو', g_radio, '#5e5ce6', '#3634a3', 'squircle'),
 ('news', 'News', 'الأخبار', g_news, '#ff453a', '#8e1b14', 'square'),
 ('maps', 'Maps', 'الخرائط', g_pin, '#30d158', '#1b8f3a', 'circle'),
 ('battery', 'Battery', 'البطارية', g_battery, '#2c2c2e', '#1c1c1e', 'squircle'),
 ('recorder', 'Recorder', 'مسجل الصوت', g_mic, '#ff3b30', '#b3261e', 'circle'),
 ('scanner', 'QR Scanner', 'قارئ QR', g_qr, '#0a84ff', '#0040a0', 'square'),
 ('translate', 'Translate', 'المترجم', g_translate, '#4285f4', '#1a56c4', 'squircle'),
 ('dictionary', 'Dictionary', 'القاموس', g_book, '#8e5a2b', '#5c3516', 'squircle'),
 ('camera', 'Camera', 'الكاميرا', g_camera, '#636366', '#2c2c2e', 'circle'),
 ('phone', 'Phone', 'الهاتف', g_dialer, '#30d158', '#1a8d3c', 'circle'),
 ('mail', 'Mail', 'البريد', g_mail, '#0a84ff', '#0b4fb3', 'squircle'),
 ('shop', 'Shopping', 'التسوق', g_cart, '#ff9500', '#d1530a', 'squircle'),
 ('wallet', 'Wallet', 'المحفظة', g_wallet, '#2c2c2e', '#111111', 'squircle'),
 ('games', 'Games', 'الألعاب', g_game, '#7d3cff', '#4318b8', 'hex'),
 ('stopwatch', 'Stopwatch', 'ساعة إيقاف', g_stopwatch, '#ff9f0a', '#cc7a00', 'circle'),
 ('alarm', 'Alarm', 'المنبه', g_bell, '#ffcc00', '#d99a00', 'circle'),
 ('podcasts', 'Podcasts', 'البودكاست', g_phones, '#af52de', '#6c2a99', 'squircle'),
 ('health', 'Health', 'الصحة', g_heart, '#ff2d55', '#c2183a', 'squircle'),
 ('thermo', 'Thermometer', 'ميزان الحرارة', g_thermo, '#64d2ff', '#2a8cc4', 'squircle'),
 ('dice', 'Dice', 'النرد', g_dice, '#e63946', '#8c1d2a', 'square'),
 ('cloud', 'Cloud', 'السحابة', g_cloud, '#5ac8fa', '#1c8fd0', 'squircle'),
 ('wifi', 'Wi-Fi Tools', 'أدوات الواي فاي', g_wifi, '#32ade6', '#0b6fa8', 'circle'),
 ('security', 'Security', 'الأمان', g_shield, '#34c759', '#1a7f37', 'hex'),
 ('vault', 'Vault', 'الخزنة', g_lock, '#48484a', '#1c1c1e', 'squircle'),
 ('stats', 'Stats', 'الإحصائيات', g_chart, '#00c7be', '#00877f', 'squircle'),
 ('todo', 'Tasks', 'المهام', g_todo, '#007aff', '#0050b3', 'squircle'),
 ('vpn', 'VPN', 'في بي إن', g_vpn, '#5856d6', '#34328f', 'circle'),
 ('ghost_white', 'Ghost', 'شبح', g_ghost, '#1b1b22', '#000000', 'circle'),
 ('plane_blue', 'Paper Plane', 'طيارة ورق', g_plane, '#2aabee', '#1b7fc0', 'circle'),
 ('plane_dark', 'Dark Plane', 'الطيارة الداكنة', g_plane, '#17212b', '#0e1621', 'squircle'),
 ('dots', 'Menu', 'القائمة', g_dots, '#8e8e93', '#48484a', 'squircle'),
 ('leaf', 'Garden', 'الحديقة', g_leaf, '#30d158', '#0a7a2d', 'diamond'),
 ('bolt', 'Booster', 'المُسرّع', g_bolt, '#ffd60a', '#f08c00', 'hex'),
 ('ghost_pink', 'Ghost Pink', 'شبح وردي', g_ghost, '#ff6fb5', '#b8247a', 'squircle'),
 ('ghost_green', 'Ghost Green', 'شبح أخضر', g_ghost, '#34d399', '#047857', 'hex'),
 ('plane_gold', 'Gold Plane', 'طيارة ذهبية', g_plane, '#f5c542', '#b8860b', 'diamond'),
 ('ghost_violet', 'Ghost Violet', 'شبح بنفسجي', g_ghost, '#8b5cf6', '#4c1d95', 'circle'),
 ('ghost_orange', 'Ghost Orange', 'شبح برتقالي', g_ghost, '#fb923c', '#c2410c', 'diamond'),
 ('plane_red', 'Red Plane', 'طيارة حمراء', g_plane, '#ff5a5f', '#a3141a', 'square'),
]
assert len(SPECS) == 50, len(SPECS)

def render(spec):
    _, _, _, glyph, c1, c2, shape = spec
    bg = grad(hexc(c1), hexc(c2)).convert('RGBA')
    gl = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    glyph(ImageDraw.Draw(gl), hexc(c2))
    bg.alpha_composite(gl)
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask(shape))
    return out.resize((192, 192), Image.LANCZOS)

def main():
    dr = os.path.join(R, 'android/app/src/main/res/drawable-nodpi')
    os.makedirs(dr, exist_ok=True)
    aliases = []
    dart = []
    for i, sp in enumerate(SPECS):
        icon = '@mipmap/ic_launcher'
        if sp[3] is not None:
            render(sp).save(os.path.join(dr, 'ic_l%02d.png' % i))
            icon = '@drawable/ic_l%02d' % i
        en = sp[1]
        aliases.append(
            '        <activity-alias android:name=".Alias%02d" android:targetActivity=".MainActivity" android:enabled="%s" android:exported="true" android:icon="%s" android:label="%s">\n'
            '            <intent-filter>\n                <action android:name="android.intent.action.MAIN"/>\n                <category android:name="android.intent.category.LAUNCHER"/>\n            </intent-filter>\n        </activity-alias>'
            % (i, 'true' if i == 0 else 'false', icon, en))
        dart.append("  LauncherIcon(%d, '%s', '%s', '%s')," % (i, sp[0], en.replace("'", "\\'"), sp[2]))
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
