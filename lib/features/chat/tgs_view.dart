import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Animated sticker / animated emoji (.tgs): plays once, tap to replay.
class TgsView extends StatefulWidget {
  const TgsView({super.key, required this.path, this.size = 150, this.emoji = ''});
  final String path;
  final double size;
  final String emoji;

  @override
  State<TgsView> createState() => _TgsViewState();
}

class _TgsViewState extends State<TgsView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_c.duration != null) _c.forward(from: 0);
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Lottie.file(
            File(widget.path),
            controller: _c,
            decoder: LottieComposition.decodeGZip,
            onLoaded: (comp) {
              _c.duration = comp.duration;
              _c.forward();
            },
            errorBuilder: (_, _, _) => Center(
              child: Text(widget.emoji, style: TextStyle(fontSize: widget.size * 0.4)),
            ),
          ),
        ),
      );
}
