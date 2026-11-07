import 'dart:ui';

import 'package:flutter/material.dart';

/// Design tokens for the glass look. Change values here to restyle the app.
class GlassTokens {
  const GlassTokens._();

  static const Color base = Color(0xFF090E1E);
  static const Color accentDefault = Color(0xFF4F46E5);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color violet = Color(0xFF7C3AED);

  static const double blurSigma = 28;
  static const double fill = 0.08;
  static const double fillStrong = 0.12;
  static const double border = 0.14;
  static const double borderStrong = 0.22;

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xBDFFFFFF); // ~74%
  static const Color textTertiary = Color(0xA6FFFFFF); // ~65%

  static const Color ringSafe = Color(0xFF4ADE80);
  static const Color ringCaution = Color(0xFFFBBF24);
  static const Color ringDanger = Color(0xFFF87171);
  static const Color ghost = Color(0xFFA5F3FC);
}

/// Carries app-wide glass options down the tree.
class GlassScope extends InheritedWidget {
  const GlassScope({
    super.key,
    required this.performanceMode,
    required this.accent,
    required super.child,
    this.base = GlassTokens.base,
    this.c2 = GlassTokens.cyan,
    this.c3 = GlassTokens.violet,
    this.intensity = 1,
    this.fillScale = 1,
    this.blurSigma = GlassTokens.blurSigma,
    this.radiusScale = 1,
    this.showBlobs = true,
  });

  final Color base;
  final Color c2;
  final Color c3;

  /// Strength of the coloured light behind everything (0 = flat colour).
  final double intensity;

  /// Multiplies the glass fill opacity (higher = more solid panels).
  final double fillScale;
  final double blurSigma;
  final double radiusScale;
  final bool showBlobs;

  /// When true, real backdrop blur is disabled everywhere (cheap translucent
  /// fills only). Meant for weak devices.
  final bool performanceMode;
  final Color accent;

  static GlassScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GlassScope>();
    return scope ??
        const GlassScope(
          performanceMode: false,
          accent: GlassTokens.accentDefault,
          child: SizedBox.shrink(),
        );
  }

  @override
  bool updateShouldNotify(GlassScope old) =>
      old.performanceMode != performanceMode ||
      old.accent != accent ||
      old.base != base ||
      old.c2 != c2 ||
      old.c3 != c3 ||
      old.intensity != intensity ||
      old.fillScale != fillScale ||
      old.blurSigma != blurSigma ||
      old.radiusScale != radiusScale ||
      old.showBlobs != showBlobs;
}

/// Soft colored light blobs on a dark base. Uses radial gradients instead of
/// blur filters, which keeps it cheap. No ornaments or patterns.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final sc = GlassScope.of(context);
    final k = sc.intensity;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: sc.base),
        if (sc.showBlobs && k > 0) ...[
          _Blob(color: sc.accent, alpha: (0.55 * k).clamp(0, 1), size: 520, top: -190, end: -200),
          _Blob(color: sc.c2, alpha: (0.32 * k).clamp(0, 1), size: 560, top: 260, start: -280),
          _Blob(color: sc.c3, alpha: (0.45 * k).clamp(0, 1), size: 500, bottom: -230, end: -150),
        ],
        ?child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.color,
    required this.alpha,
    required this.size,
    this.top,
    this.bottom,
    this.start,
    this.end,
  });

  final Color color;
  final double alpha;
  final double size;
  final double? top;
  final double? bottom;
  final double? start;
  final double? end;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: top,
      bottom: bottom,
      start: start,
      end: end,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: alpha),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A translucent glass panel. Use [blur] only for large, stable surfaces
/// (bars, sheets); list items should keep it off for performance.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = false,
    this.fill = GlassTokens.fill,
    this.border = GlassTokens.border,
    this.padding,
    this.shadow = false,
    this.borderColor,
    this.tint,
  });

  final Widget child;
  final double radius;
  final bool blur;
  final double fill;
  final double border;
  final EdgeInsetsGeometry? padding;
  final bool shadow;
  final Color? borderColor;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scope = GlassScope.of(context);
    final borderRadius = BorderRadius.circular(radius * scope.radiusScale);
    final base = tint ?? Colors.white;
    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: base.withValues(alpha: (fill * scope.fillScale).clamp(0.0, 0.9)),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: border),
        ),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: child,
    );
    if (!blur || scope.performanceMode) {
      return decorated;
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: scope.blurSigma,
          sigmaY: scope.blurSigma,
        ),
        child: decorated,
      ),
    );
  }
}

/// Round glass icon button, 44px touch target.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.onLongPress,
    this.size = 44,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          onLongPress: onLongPress,
          child: SizedBox(
            width: size,
            height: size,
            child: GlassSurface(
              radius: size / 2,
              fill: 0.10,
              border: GlassTokens.borderStrong,
              child: Center(
                child: Icon(icon, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData buildGlassTheme(Brightness _) {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: GlassTokens.base,
    colorScheme: ColorScheme.fromSeed(
      seedColor: GlassTokens.accentDefault,
      brightness: Brightness.dark,
    ),
    textTheme: Typography.whiteMountainView.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );
}
