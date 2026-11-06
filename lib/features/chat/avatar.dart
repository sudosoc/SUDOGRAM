import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/models.dart';

/// Round avatar: the profile photo when downloaded, otherwise the first
/// letter on a colour derived from the name.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.title,
    this.photo,
    this.size = 48,
    this.ring,
  });

  final String title;
  final Attachment? photo;
  final double size;
  final Color? ring;

  static const _palette = [
    Color(0xFF6366F1), Color(0xFF14B8A6), Color(0xFFF59E0B),
    Color(0xFFEC4899), Color(0xFF3B82F6), Color(0xFF22C55E), Color(0xFFA855F7),
  ];

  @override
  Widget build(BuildContext context) {
    final path = photo != null && photo!.downloaded ? photo!.localPath : null;
    final color = _palette[title.runes.fold<int>(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.55),
        border: ring == null ? null : Border.all(color: ring!, width: 2.5),
        image: path != null && File(path).existsSync()
            ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: path == null
          ? Text(
              title.characters.isEmpty ? '?' : title.characters.first.toUpperCase(),
              style: TextStyle(fontSize: size * 0.4),
            )
          : null,
    );
  }
}
