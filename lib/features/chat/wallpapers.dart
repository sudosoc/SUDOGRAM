import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/i18n/tr.dart';
import '../../core/theme/glass.dart';
import '../settings/widgets.dart';

/// Chat background presets; index 0 = none (the app's own background).
const List<LinearGradient?> wallpapers = [
  null,
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D2B64), Color(0xFF6A3093)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF134E5E), Color(0xFF71B280)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A1C71), Color(0xFFD76D77)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF141E30), Color(0xFF243B55)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF1A1A2E)],
  ),
  LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF42275A), Color(0xFF734B6D)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF200122), Color(0xFF6F0000)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF004E92), Color(0xFF000428)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B486B), Color(0xFFF56217)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F4037), Color(0xFF99F2C8)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF232526), Color(0xFF414345)],
  ),
];


/// One built-in picture wallpaper (assets/wallpapers, one jpg per id).
class WallItem {
  const WallItem(this.id, this.cat);
  final String id;
  final String cat;
}

const wallCats = <String, List<String>>{
  'love': ['Love', 'حب'],
  'mystery': ['Mystery', 'غموض'],
  'cars': ['Cars', 'سيارات'],
  'moto': ['Motorcycles', 'موتوسيكلات'],
  'hacker': ['Hackers', 'هاكرز'],
  'gradient': ['Gradients', 'ألوان'],
  'mine': ['My photos', 'صوري'],
};

final wallCatalog = <WallItem>[
  for (final e in const {
    'love': 6,
    'mystery': 6,
    'cars': 6,
    'moto': 6,
    'hacker': 6,
  }.entries)
    for (var i = 1; i <= e.value; i++) WallItem('${e.key}_$i', e.key),
  for (var i = 1; i < wallpapers.length; i++) WallItem('g$i', 'gradient'),
];

LinearGradient? _grad(String id) {
  if (id.length > 1 && id.startsWith('g')) {
    final i = int.tryParse(id.substring(1));
    if (i != null && i > 0 && i < wallpapers.length) return wallpapers[i];
  }
  return null;
}

/// Image/gradient for a wallpaper id as a widget (thumbnail or full).
Widget wallImage(String id, {int? cacheWidth}) {
  if (id.startsWith('file:')) {
    return Image.file(
      File(id.substring(5)),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black26),
    );
  }
  final g = _grad(id);
  if (g != null) return DecoratedBox(decoration: BoxDecoration(gradient: g));
  return Image.asset(
    'assets/wallpapers/$id.jpg',
    fit: BoxFit.cover,
    cacheWidth: cacheWidth,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

/// Chat backdrop: wallpaper (if any) + dim layer, with [child] on top.
class WallBackdrop extends StatelessWidget {
  const WallBackdrop({super.key, required this.id, required this.dim, required this.child});
  final String id;
  final double dim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (id.isEmpty || id == 'none') return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        wallImage(id, cacheWidth: 900),
        if (_grad(id) == null)
          ColoredBox(color: Colors.black.withValues(alpha: dim.clamp(0.0, 0.8))),
        child,
      ],
    );
  }
}

Future<void> pickChatWallpaper(BuildContext context, WidgetRef ref, int chatId) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WallpaperPicker(chatId: chatId)),
    );

/// Picker page. [chatId] == null edits the default for all chats.
class WallpaperPicker extends ConsumerStatefulWidget {
  const WallpaperPicker({super.key, this.chatId});
  final int? chatId;
  @override
  ConsumerState<WallpaperPicker> createState() => _WallpaperPickerState();
}

class _WallpaperPickerState extends ConsumerState<WallpaperPicker> {
  String _cat = 'love';

  Future<void> _addFromGallery() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88);
    if (x == null || !mounted) return;
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/wallpapers');
    await dir.create(recursive: true);
    final dst = '${dir.path}/custom_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(dst);
    if (!mounted) return;
    final c = ref.read(settingsProvider.notifier);
    final cur = ((ref.read(settingsProvider).x['customWalls'] as List?) ?? const []).cast<String>();
    c.setX('customWalls', [dst, ...cur]);
    final id = 'file:$dst';
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _WallPreview(id: id)));
    if (ok == true && mounted) _apply(id);
  }

  void _apply(String id) {
    final s = ref.read(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    if (widget.chatId != null) {
      final m = Map<String, dynamic>.of(s.chatWall);
      if (id.isEmpty) {
        m.remove('${widget.chatId}');
      } else {
        m['${widget.chatId}'] = id;
      }
      c.setX('chatWall', m);
    } else {
      c.setX('wallId', id.isEmpty ? null : id);
      if (s.wallpaper != 0) c.setWallpaper(0);
    }
  }

  void _removeCustom(String id) {
    final path = id.substring(5);
    final c = ref.read(settingsProvider.notifier);
    final cur = ((ref.read(settingsProvider).x['customWalls'] as List?) ?? const []).cast<String>();
    c.setX('customWalls', cur.where((e) => e != path).toList());
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final per = widget.chatId != null;
    final cur = per
        ? (s.chatWall['${widget.chatId}'] as String? ?? '')
        : (s.wallId.isNotEmpty ? s.wallId : (s.wallpaper > 0 ? 'g${s.wallpaper}' : ''));
    void pick(String id) {
      if (per) {
        final m = Map<String, dynamic>.of(s.chatWall);
        if (id.isEmpty) {
          m.remove('${widget.chatId}');
        } else {
          m['${widget.chatId}'] = id;
        }
        c.setX('chatWall', m);
      } else {
        c.setX('wallId', id.isEmpty ? null : id);
        if (s.wallpaper != 0) c.setWallpaper(0);
      }
    }

    final w = (MediaQuery.of(context).size.width - 32 - 20) / 3;
    final custom = ((s.x['customWalls'] as List?) ?? const []).cast<String>();
    final items = _cat == 'mine'
        ? [for (final f in custom) WallItem('file:$f', 'mine')]
        : wallCatalog.where((e) => e.cat == _cat).toList();
    Widget tile(String id, {required String label}) {
      final sel = cur == id;
      return GestureDetector(
        onTap: () async {
          if (id.isEmpty || id == 'none') {
            pick(id);
            return;
          }
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => _WallPreview(id: id)),
          );
          if (ok == true) pick(id);
        },
        onLongPress: id.startsWith('file:') ? () => _removeCustom(id) : null,
        child: Container(
          width: w,
          height: w * 1.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? Colors.white : Colors.white24, width: sel ? 2.5 : 1),
            color: Colors.white10,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (id.isEmpty || id == 'none')
                Center(child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: GlassTokens.textSecondary)))
              else
                wallImage(id, cacheWidth: 300),
              if (sel)
                const Positioned(top: 6, right: 6, child: CircleAvatar(radius: 11, backgroundColor: Colors.white, child: Icon(Icons.check, size: 16, color: Colors.black))),
            ],
          ),
        ),
      );
    }

    return SPage(
      title: per ? context.t('Chat background', 'خلفية الشات') : context.t('Default background', 'الخلفية الافتراضية'),
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final e in wallCats.entries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(context.isAr ? e.value[1] : e.value[0]),
                    selected: _cat == e.key,
                    onSelected: (_) => setState(() => _cat = e.key),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_cat == 'mine')
                GestureDetector(
                  onTap: _addFromGallery,
                  child: Container(
                    width: w,
                    height: w * 1.9,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: GlassScope.of(context).accent, width: 1.5),
                      color: Colors.white10,
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 30, color: GlassScope.of(context).accent),
                      const SizedBox(height: 6),
                      Text(context.t('From gallery', 'من المعرض'),
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                )
              else ...[
                tile('', label: per ? context.t('Use default', 'الافتراضية') : context.t('None', 'بدون')),
                if (per) tile('none', label: context.t('No background', 'بدون خلفية')),
              ],
              for (final e in items) tile(e.id, label: ''),
            ],
          ),
        ),
        SGroup(children: [
          SliderRow(
            icon: Icons.brightness_6_outlined,
            title: context.t('Darken background', 'تعتيم الخلفية'),
            keyName: 'wallDim',
            value: s.wallDim,
            min: 0,
            max: .7,
            divisions: 14,
            fmt: (v) => '${(v * 100).round()}%',
          ),
        ]),
      ],
    );
  }
}


/// Full-screen preview of a wallpaper with a fake conversation on top.
class _WallPreview extends ConsumerStatefulWidget {
  const _WallPreview({required this.id});
  final String id;
  @override
  ConsumerState<_WallPreview> createState() => _WallPreviewState();
}

class _WallPreviewState extends ConsumerState<_WallPreview> {
  double? _dim;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final accent = s.chatOut != null ? Color(s.chatOut!) : GlassScope.of(context).accent;
    final dim = _dim ?? s.wallDim;
    Widget bubble(String t, bool out) => Align(
          alignment: out ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: out
                  ? accent.withValues(alpha: .55)
                  : (s.chatIn != null ? Color(s.chatIn!) : Colors.white.withValues(alpha: .14)),
            ),
            child: Text(t),
          ),
        );
    return Scaffold(
      backgroundColor: Colors.black,
      body: WallBackdrop(
        id: widget.id,
        dim: dim,
        child: SafeArea(
          child: Column(children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              Expanded(
                child: Text(context.t('Preview', 'معاينة'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
            const Spacer(),
            bubble(context.t('How does this background look?', 'شكل الخلفية دي عامل إزاي؟'), false),
            bubble(context.t('Looks great!', 'تحفة!'), true),
            bubble(context.t('Text stays readable on top of it.', 'والكلام بيفضل واضح فوقها.'), false),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.black.withValues(alpha: .55),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (!widget.id.startsWith('g'))
                  Row(children: [
                    const Icon(Icons.brightness_6_outlined, size: 18),
                    Expanded(
                      child: Slider(
                        value: dim.clamp(0.0, .7),
                        min: 0,
                        max: .7,
                        onChanged: (v) => setState(() => _dim = v),
                      ),
                    ),
                  ]),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(context.t('Back', 'رجوع')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (_dim != null) ref.read(settingsProvider.notifier).setX('wallDim', _dim);
                        Navigator.of(context).pop(true);
                      },
                      child: Text(context.t('Use this background', 'استخدم الخلفية دي')),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
