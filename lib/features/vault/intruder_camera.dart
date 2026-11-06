import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Silently takes a front-camera photo (no preview) after a wrong passcode.
/// Photos stay in the app's private storage.
class IntruderCamera {
  const IntruderCamera._();

  static Future<CameraController?> _open() async {
    final cams = await availableCameras();
    if (cams.isEmpty) return null;
    final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first);
    final c = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
    await c.initialize();
    return c;
  }

  /// Triggers the permission prompt without taking a picture.
  static Future<void> requestPermission() async {
    try {
      (await _open())?.dispose();
    } catch (e) {
      debugPrint('camera permission: $e');
    }
  }

  /// Returns the saved photo path, or null if the camera isn't available.
  static Future<String?> capture(String dir) async {
    CameraController? c;
    try {
      c = await _open();
      if (c == null) return null;
      final shot = await c.takePicture();
      await Directory(dir).create(recursive: true);
      final out = '$dir/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(shot.path).copy(out);
      await File(shot.path).delete();
      return out;
    } catch (e) {
      debugPrint('intruder capture failed: $e');
      return null;
    } finally {
      await c?.dispose();
    }
  }
}
