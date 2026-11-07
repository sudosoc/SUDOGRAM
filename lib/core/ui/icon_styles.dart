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
];

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
  final slot = switch (style) {
    'filled' || 'glow' => 0,
    'outlined' || 'badge' => 1,
    'rounded' => 2,
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
