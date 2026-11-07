import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../theme/glass.dart';
import 'icon_table.g.dart';

/// Icon looks the user can pick in Appearance → Icons.
const kIconStyles = [
  'default',
  'outlined',
  'filled',
  'rounded',
  'sharp',
  'glow',
  'badge',
  'duotone',
  'neon',
  'tile',
  'bold',
  'cupertino',
];

/// Common icons that also exist in the iOS-style set.
final Map<int, IconData> _cupertino = {
  Icons.search.codePoint: CupertinoIcons.search,
  Icons.settings.codePoint: CupertinoIcons.gear,
  Icons.person.codePoint: CupertinoIcons.person,
  Icons.people.codePoint: CupertinoIcons.person_2,
  Icons.group.codePoint: CupertinoIcons.person_2,
  Icons.person_add.codePoint: CupertinoIcons.person_add,
  Icons.chat_bubble.codePoint: CupertinoIcons.chat_bubble,
  Icons.chat.codePoint: CupertinoIcons.chat_bubble_2,
  Icons.delete.codePoint: CupertinoIcons.trash,
  Icons.edit.codePoint: CupertinoIcons.pencil,
  Icons.add.codePoint: CupertinoIcons.add,
  Icons.close.codePoint: CupertinoIcons.xmark,
  Icons.check.codePoint: CupertinoIcons.checkmark,
  Icons.arrow_back.codePoint: CupertinoIcons.back,
  Icons.arrow_forward.codePoint: CupertinoIcons.forward,
  Icons.send.codePoint: CupertinoIcons.paperplane,
  Icons.lock.codePoint: CupertinoIcons.lock,
  Icons.lock_open.codePoint: CupertinoIcons.lock_open,
  Icons.photo_camera.codePoint: CupertinoIcons.camera,
  Icons.photo.codePoint: CupertinoIcons.photo,
  Icons.photo_library.codePoint: CupertinoIcons.photo_on_rectangle,
  Icons.mic.codePoint: CupertinoIcons.mic,
  Icons.phone.codePoint: CupertinoIcons.phone,
  Icons.mail.codePoint: CupertinoIcons.mail,
  Icons.star.codePoint: CupertinoIcons.star,
  Icons.favorite.codePoint: CupertinoIcons.heart,
  Icons.share.codePoint: CupertinoIcons.share,
  Icons.ios_share.codePoint: CupertinoIcons.share,
  Icons.copy.codePoint: CupertinoIcons.doc_on_doc,
  Icons.info.codePoint: CupertinoIcons.info,
  Icons.notifications.codePoint: CupertinoIcons.bell,
  Icons.home.codePoint: CupertinoIcons.house,
  Icons.folder.codePoint: CupertinoIcons.folder,
  Icons.location_on.codePoint: CupertinoIcons.location,
  Icons.videocam.codePoint: CupertinoIcons.videocam,
  Icons.download.codePoint: CupertinoIcons.arrow_down_circle,
  Icons.link.codePoint: CupertinoIcons.link,
  Icons.push_pin.codePoint: CupertinoIcons.pin,
  Icons.flag.codePoint: CupertinoIcons.flag,
  Icons.event.codePoint: CupertinoIcons.calendar,
  Icons.schedule.codePoint: CupertinoIcons.clock,
  Icons.visibility.codePoint: CupertinoIcons.eye,
  Icons.visibility_off.codePoint: CupertinoIcons.eye_slash,
  Icons.more_vert.codePoint: CupertinoIcons.ellipsis_vertical,
  Icons.more_horiz.codePoint: CupertinoIcons.ellipsis,
  Icons.refresh.codePoint: CupertinoIcons.refresh,
  Icons.cloud.codePoint: CupertinoIcons.cloud,
  Icons.bookmark.codePoint: CupertinoIcons.bookmark,
  Icons.archive.codePoint: CupertinoIcons.archivebox,
  Icons.block.codePoint: CupertinoIcons.nosign,
  Icons.qr_code.codePoint: CupertinoIcons.qrcode,
  Icons.attach_file.codePoint: CupertinoIcons.paperclip,
  Icons.emoji_emotions.codePoint: CupertinoIcons.smiley,
  Icons.play_arrow.codePoint: CupertinoIcons.play_fill,
  Icons.pause.codePoint: CupertinoIcons.pause_fill,
  Icons.shield.codePoint: CupertinoIcons.shield,
  Icons.language.codePoint: CupertinoIcons.globe,
  Icons.palette.codePoint: CupertinoIcons.paintbrush,
  Icons.tune.codePoint: CupertinoIcons.slider_horizontal_3,
  Icons.done_all.codePoint: CupertinoIcons.checkmark_alt_circle,
  Icons.chevron_right.codePoint: CupertinoIcons.chevron_right,
  Icons.chevron_left.codePoint: CupertinoIcons.chevron_left,
  Icons.keyboard_arrow_down.codePoint: CupertinoIcons.chevron_down,
  Icons.keyboard_arrow_up.codePoint: CupertinoIcons.chevron_up,
  Icons.wifi.codePoint: CupertinoIcons.wifi,
  Icons.battery_full.codePoint: CupertinoIcons.battery_full,
  Icons.help.codePoint: CupertinoIcons.question_circle,
};

Map<int, int>? _index;

/// Row start (in [kIconVariants]) for every known code point.
Map<int, int> get _idx {
  final m = _index;
  if (m != null) return m;
  final out = <int, int>{};
  for (var i = 0; i < kIconVariants.length; i += 4) {
    for (var j = 0; j < 4; j++) {
      out.putIfAbsent(kIconVariants[i + j], () => i);
    }
  }
  return _index = out;
}

/// Swaps a Material icon for the same icon in another variant.
IconData restyle(IconData d, String style) {
  if (d.fontFamily != 'MaterialIcons') return d;
  if (style == 'cupertino') {
    final base = _idx[d.codePoint];
    final f = base == null ? d.codePoint : kIconVariants[base];
    return _cupertino[f] ?? _cupertino[d.codePoint] ?? d;
  }
  final slot = switch (style) {
    'filled' || 'glow' || 'tile' => 0,
    'outlined' || 'badge' || 'neon' || 'duotone' => 1,
    'rounded' || 'bold' => 2,
    'sharp' => 3,
    _ => -1,
  };
  if (slot < 0) return d;
  final row = _idx[d.codePoint];
  if (row == null) return d;
  // ignore: non_const_argument_for_const_parameter
  return IconData(kIconVariants[row + slot], fontFamily: 'MaterialIcons');
}

/// Drop-in for [Icon] that follows the chosen global icon style.
class SIcon extends StatelessWidget {
  const SIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
    this.styleOverride,
  });

  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final String? styleOverride;

  @override
  Widget build(BuildContext context) {
    final style = styleOverride ?? GlassScope.of(context).iconStyle;
    final d = icon == null ? null : restyle(icon!, style);
    Widget w = Icon(
      d,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
      shadows: style == 'glow'
          ? [
              Shadow(
                color: (color ?? IconTheme.of(context).color ?? Colors.white)
                    .withValues(alpha: 0.9),
                blurRadius: 10,
              ),
            ]
          : null,
    );
    final accent = GlassScope.of(context).accent;
    final base = color ?? IconTheme.of(context).color ?? Colors.white;
    final sz = size ?? IconTheme.of(context).size ?? 24;
    if (style == 'neon') {
      final nc = color ?? IconTheme.of(context).color ?? accent;
      w = Icon(d, size: size, color: color, semanticLabel: semanticLabel, shadows: [
        Shadow(color: nc.withValues(alpha: 0.9), blurRadius: 5),
        Shadow(color: nc.withValues(alpha: 0.5), blurRadius: 12),
      ]);
    } else if (style == 'duotone' && icon != null) {
      final fill = restyle(icon!, 'filled');
      w = Stack(alignment: Alignment.center, children: [
        Icon(fill, size: size, color: base.withValues(alpha: 0.28)),
        Icon(d, size: size, color: color, semanticLabel: semanticLabel),
      ]);
    } else if (style == 'bold') {
      w = Stack(alignment: Alignment.center, children: [
        Transform.translate(offset: const Offset(0.7, 0), child: Icon(d, size: size, color: color)),
        Transform.translate(offset: const Offset(-0.7, 0), child: Icon(d, size: size, color: color)),
        Icon(d, size: size, color: color, semanticLabel: semanticLabel),
      ]);
    } else if (style == 'tile') {
      w = Container(
        width: sz + 12,
        height: sz + 12,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular((sz + 12) * 0.3),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, accent.withValues(alpha: 0.6)],
          ),
        ),
        child: Icon(d, size: sz * 0.82, color: Colors.white, semanticLabel: semanticLabel),
      );
    }
    if (style == 'badge') {
      final s = size ?? IconTheme.of(context).size ?? 24;
      final c = color ?? IconTheme.of(context).color ?? Colors.white;
      w = Container(
        width: s + 10,
        height: s + 10,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withValues(alpha: 0.16),
        ),
        child: Icon(d, size: s * 0.8, color: color, semanticLabel: semanticLabel),
      );
    }
    return w;
  }
}
