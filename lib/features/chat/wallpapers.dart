import 'package:flutter/material.dart';

/// Chat background presets; index 0 = none (the app's own background).
const List<LinearGradient?> wallpapers = [
  null,
  LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0F2027), Color(0xFF2C5364)]),
  LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1D2B64), Color(0xFF6A3093)]),
  LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF134E5E), Color(0xFF71B280)]),
  LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A1C71), Color(0xFFD76D77)]),
  LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF141E30), Color(0xFF243B55)]),
];
