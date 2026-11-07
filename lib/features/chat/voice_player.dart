import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../core/ui/icon_styles.dart';

import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import 'file_card.dart';

/// Voice notes / audio: play, seek bar, ±10 s skip and playback speed.
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, required this.file, required this.onDownload});

  final Attachment file;
  final VoidCallback onDownload;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  static const _speeds = [1.0, 1.5, 2.0, 0.75];
  static double _lastSpeed = 1.0; // remembered across messages

  AudioPlayer? _p;
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  double _speed = _lastSpeed;
  double? _drag;

  AudioPlayer _player() => _p ??= AudioPlayer()
    ..onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    })
    ..onPositionChanged.listen((d) {
      if (mounted && _drag == null) setState(() => _pos = d);
    })
    ..onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    })
    ..onPlayerComplete.listen((_) {
      if (mounted) setState(() => _pos = Duration.zero);
    });

  Future<void> _toggle() async {
    final f = widget.file;
    if (!f.downloaded || f.localPath == null) {
      widget.onDownload();
      return;
    }
    final p = _player();
    if (_state == PlayerState.playing) {
      await p.pause();
    } else if (_state == PlayerState.paused) {
      await p.resume();
    } else {
      await p.setPlaybackRate(_speed);
      await p.play(DeviceFileSource(f.localPath!));
    }
  }

  Future<void> _skip(int seconds) async {
    final p = _p;
    if (p == null) return;
    var t = _pos + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (_dur > Duration.zero && t > _dur) t = _dur;
    await p.seek(t);
    if (mounted) setState(() => _pos = t);
  }

  Future<void> _cycleSpeed() async {
    final i = _speeds.indexOf(_speed);
    _speed = _speeds[(i + 1) % _speeds.length];
    _lastSpeed = _speed;
    await _p?.setPlaybackRate(_speed);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _p?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final accent = GlassScope.of(context).accent;
    final playing = _state == PlayerState.playing;
    final totalMs = _dur.inMilliseconds;
    final value = f.downloaded
        ? (_drag ??
              (totalMs == 0
                  ? 0.0
                  : (_pos.inMilliseconds / totalMs).clamp(0.0, 1.0)))
        : 0.0;
    final shown = _drag != null
        ? Duration(milliseconds: (_drag! * totalMs).round())
        : _pos;
    return SizedBox(
      width: 250,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: accent),
            icon: SIcon(!f.downloaded
                ? (f.downloading ? Icons.hourglass_top : Icons.download)
                : playing
                    ? Icons.pause
                    : Icons.play_arrow),
            onPressed: _toggle,
          ),
          Expanded(
            child: f.downloaded
                ? SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: value,
                      activeColor: accent,
                      onChanged: totalMs == 0
                          ? null
                          : (v) => setState(() => _drag = v),
                      onChangeEnd: (v) async {
                        final t = Duration(milliseconds: (v * totalMs).round());
                        await _player().seek(t);
                        if (mounted) {
                          setState(() {
                            _pos = t;
                            _drag = null;
                          });
                        }
                      },
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: LinearProgressIndicator(
                        value: f.downloading ? f.progress : 0),
                  ),
          ),
        ]),
        Row(children: [
          const SizedBox(width: 12),
          Text(
              f.downloaded
                  ? '${_fmt(shown)} / ${_fmt(_dur)}'
                  : formatBytes(f.size),
              style: const TextStyle(
                  fontSize: 11, color: GlassTokens.textSecondary)),
          const Spacer(),
          if (f.downloaded) ...[
            InkWell(
              onTap: () => _skip(-10),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: SIcon(Icons.replay_10, size: 22),
              ),
            ),
            InkWell(
              onTap: () => _skip(10),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: SIcon(Icons.forward_10, size: 22),
              ),
            ),
            InkWell(
              onTap: _cycleSpeed,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white12,
                ),
                child: Text(
                    '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}
