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
  });

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
      old.performanceMode != performanceMode || old.accent != accent;
}

/// Soft colored light blobs on a dark base. Uses radial gradients instead of
/// blur filters, which keeps it cheap. No ornaments or patterns.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final accent = GlassScope.of(context).accent;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: GlassTokens.base),
        _Blob(color: accent, alpha: 0.55, size: 520, top: -190, end: -200),
        _Blob(color: GlassTokens.cyan, alpha: 0.32, size: 560, top: 260, start: -280),
        _Blob(color: GlassTokens.violet, alpha: 0.45, size: 500, bottom: -230, end: -150),
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
    final borderRadius = BorderRadius.circular(radius);
    final base = tint ?? Colors.white;
    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: base.withValues(alpha: fill),
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
          sigmaX: GlassTokens.blurSigma,
          sigmaY: GlassTokens.blurSigma,
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
