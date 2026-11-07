import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// One app-wide audio player so voice notes keep playing when the user
/// leaves the chat or the app, with a mini-player and notification controls.
class AudioHub extends ChangeNotifier {
  AudioHub._() {
    player.setAudioContext(AudioContextConfig(stayAwake: true).build());
    player.onPlayerStateChanged.listen((s) {
      state = s;
      _sync();
    });
    player.onPositionChanged.listen((d) {
      pos = d;
      notifyListeners();
    });
    player.onDurationChanged.listen((d) {
      dur = d;
      notifyListeners();
    });
    player.onPlayerComplete.listen((_) {
      pos = Duration.zero;
      final next = _next;
      key = null;
      state = PlayerState.completed;
      _sync();
      if (next != null) next();
    });
  }

  static final AudioHub instance = AudioHub._();

  final AudioPlayer player = AudioPlayer();
  String? key;
  String title = '';
  PlayerState state = PlayerState.stopped;
  Duration pos = Duration.zero;
  Duration dur = Duration.zero;
  double speed = 1.0;

  /// Shows / updates / clears the notification (set by the app).
  void Function(String title, bool playing)? onNotify;
  VoidCallback? onClearNotify;

  /// Called when a track finishes, to continue with the next voice note.
  VoidCallback? _next;
  void setNext(VoidCallback? f) => _next = f;

  bool isActive(String k) => key == k;
  bool get playing => state == PlayerState.playing;

  Future<void> play(String k, String path, String label, {VoidCallback? next}) async {
    if (key == k && state == PlayerState.paused) return resume();
    key = k;
    title = label;
    _next = next;
    pos = Duration.zero;
    dur = Duration.zero;
    await player.setPlaybackRate(speed);
    await player.play(DeviceFileSource(path));
  }

  Future<void> pause() => player.pause();
  Future<void> resume() => player.resume();

  Future<void> toggle() => playing ? pause() : resume();

  Future<void> stop() async {
    key = null;
    _next = null;
    await player.stop();
    pos = Duration.zero;
    state = PlayerState.stopped;
    _sync();
  }

  Future<void> seek(Duration d) async {
    await player.seek(d);
    pos = d;
    notifyListeners();
  }

  Future<void> setSpeed(double v) async {
    speed = v;
    await player.setPlaybackRate(v);
    notifyListeners();
  }

  void handleAction(String id) {
    switch (id) {
      case 'audio_toggle':
        toggle();
      case 'audio_stop':
        stop();
    }
  }

  void _sync() {
    if (key != null && state != PlayerState.stopped && state != PlayerState.completed) {
      onNotify?.call(title, playing);
    } else {
      onClearNotify?.call();
    }
    notifyListeners();
  }
}
