import 'package:flutter/material.dart';

/// A complete look: background colours and the accent that goes with it.
class ThemePreset {
  const ThemePreset(this.id, this.en, this.ar, this.base, this.accent, this.c2,
      this.c3);
  final String id;
  final String en;
  final String ar;
  final Color base;
  final Color accent;
  final Color c2;
  final Color c3;
}

const themePresets = <ThemePreset>[
  ThemePreset('aurora', 'Aurora', 'أورورا', Color(0xFF090E1E), Color(0xFF4F46E5),
      Color(0xFF06B6D4), Color(0xFF7C3AED)),
  ThemePreset('midnight', 'Midnight', 'منتصف الليل', Color(0xFF05070F),
      Color(0xFF3B82F6), Color(0xFF1E3A8A), Color(0xFF312E81)),
  ThemePreset('ocean', 'Ocean', 'محيط', Color(0xFF04141F), Color(0xFF0EA5E9),
      Color(0xFF14B8A6), Color(0xFF2563EB)),
  ThemePreset('sunset', 'Sunset', 'غروب', Color(0xFF1A0B14), Color(0xFFF97316),
      Color(0xFFEC4899), Color(0xFFEAB308)),
  ThemePreset('forest', 'Forest', 'غابة', Color(0xFF07140E), Color(0xFF22C55E),
      Color(0xFF065F46), Color(0xFF84CC16)),
  ThemePreset('rose', 'Rose', 'وردي', Color(0xFF1B0A17), Color(0xFFF43F5E),
      Color(0xFFD946EF), Color(0xFFFB7185)),
  ThemePreset('cyber', 'Cyberpunk', 'سايبربانك', Color(0xFF0B0615),
      Color(0xFFFF2BD6), Color(0xFF00F0FF), Color(0xFF7C3AED)),
  ThemePreset('matrix', 'Matrix', 'ماتريكس', Color(0xFF000800), Color(0xFF00FF66),
      Color(0xFF00A844), Color(0xFF003B1A)),
  ThemePreset('amoled', 'AMOLED black', 'أسود أموليد', Color(0xFF000000),
      Color(0xFF8B5CF6), Color(0xFF1F1F1F), Color(0xFF111111)),
  ThemePreset('royal', 'Royal gold', 'ذهبي ملكي', Color(0xFF0F0A04),
      Color(0xFFD4AF37), Color(0xFF92400E), Color(0xFF7C2D12)),
  ThemePreset('slate', 'Slate', 'رمادي هادي', Color(0xFF0D1117),
      Color(0xFF64748B), Color(0xFF334155), Color(0xFF1E293B)),
  ThemePreset('candy', 'Candy', 'حلوى', Color(0xFF150B1F), Color(0xFFA78BFA),
      Color(0xFFF0ABFC), Color(0xFF67E8F9)),
];

ThemePreset presetById(String id) =>
    themePresets.firstWhere((p) => p.id == id, orElse: () => themePresets.first);
