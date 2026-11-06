import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import 'file_card.dart';

/// Play/pause for voice notes and audio files; downloads on first tap.
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, required this.file, required this.onDownload});

  final Attachment file;
  final VoidCallback onDownload;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  AudioPlayer? _p;
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  Future<void> _toggle() async {
    final f = widget.file;
    if (!f.downloaded || f.localPath == null) {
      widget.onDownload();
      return;
    }
    final p = _p ??= AudioPlayer()
      ..onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _state = s);
      })
      ..onPositionChanged.listen((d) {
        if (mounted) setState(() => _pos = d);
      })
      ..onDurationChanged.listen((d) {
        if (mounted) setState(() => _dur = d);
      });
    if (_state == PlayerState.playing) {
      await p.pause();
    } else {
      await p.play(DeviceFileSource(f.localPath!));
    }
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
    return SizedBox(
      width: 220,
      child: Row(children: [
        IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: accent),
          icon: Icon(!f.downloaded
              ? (f.downloading ? Icons.hourglass_top : Icons.download)
              : playing
                  ? Icons.pause
                  : Icons.play_arrow),
          onPressed: _toggle,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: f.downloaded
                    ? (_dur.inMilliseconds == 0
                        ? 0
                        : _pos.inMilliseconds / _dur.inMilliseconds)
                    : (f.downloading ? f.progress : 0),
              ),
              const SizedBox(height: 4),
              Text(
                  f.downloaded
                      ? '${_fmt(_pos)} / ${_fmt(_dur)}'
                      : formatBytes(f.size),
                  style: const TextStyle(
                      fontSize: 11, color: GlassTokens.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }
}
