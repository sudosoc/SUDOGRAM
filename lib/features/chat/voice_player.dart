import 'package:audioplayers/audioplayers.dart';

import '../../core/audio_hub.dart';

import 'package:flutter/material.dart';

import '../../core/ui/icon_styles.dart';

import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import 'file_card.dart';
import 'fx_widgets.dart';

/// Voice notes / audio: play, seek bar, ±10 s skip and playback speed.
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({
    super.key,
    required this.file,
    required this.onDownload,
    this.title = 'Voice message',
  });

  final String title;
  final Attachment file;
  final VoidCallback onDownload;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  static const _speeds = [1.0, 1.5, 2.0, 0.75];
  final _hub = AudioHub.instance;
  double? _drag;

  String get _key => widget.file.localPath ?? 'f${widget.file.fileId}';
  bool get _active => _hub.isActive(_key);
  PlayerState get _state => _active ? _hub.state : PlayerState.stopped;
  Duration get _pos => _active ? _hub.pos : Duration.zero;
  Duration get _dur => _active ? _hub.dur : Duration.zero;
  double get _speed => _hub.speed;

  @override
  void initState() {
    super.initState();
    _hub.addListener(_tick);
  }

  void _tick() {
    if (mounted && _drag == null) setState(() {});
  }

  Future<void> _toggle() async {
    final f = widget.file;
    if (!f.downloaded || f.localPath == null) {
      widget.onDownload();
      return;
    }
    if (_active) {
      await _hub.toggle();
    } else {
      await _hub.play(_key, f.localPath!, widget.title);
    }
  }

  Future<void> _skip(int seconds) async {
    if (!_active) return;
    var t = _pos + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (_dur > Duration.zero && t > _dur) t = _dur;
    await _hub.seek(t);
  }

  Future<void> _cycleSpeed() async {
    final i = _speeds.indexOf(_speed);
    await _hub.setSpeed(_speeds[(i + 1) % _speeds.length]);
  }

  @override
  void dispose() {
    _hub.removeListener(_tick);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: playing
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: .55),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: accent),
                  icon: SIcon(
                    !f.downloaded
                        ? (f.downloading ? Icons.hourglass_top : Icons.download)
                        : playing
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: _toggle,
                ),
              ),
              if (playing)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: EqBars(color: accent),
                ),
              Expanded(
                child: f.downloaded
                    ? SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: value,
                          activeColor: accent,
                          onChanged: totalMs == 0
                              ? null
                              : (v) => setState(() => _drag = v),
                          onChangeEnd: (v) async {
                            final t = Duration(
                              milliseconds: (v * totalMs).round(),
                            );
                            if (_active) await _hub.seek(t);
                            if (mounted) setState(() => _drag = null);
                          },
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: LinearProgressIndicator(
                          value: f.downloading ? f.progress : 0,
                        ),
                      ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 12),
              Text(
                f.downloaded
                    ? '${_fmt(shown)} / ${_fmt(_dur)}'
                    : formatBytes(f.size),
                style: const TextStyle(
                  fontSize: 11,
                  color: GlassTokens.textSecondary,
                ),
              ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white12,
                    ),
                    child: Text(
                      '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
