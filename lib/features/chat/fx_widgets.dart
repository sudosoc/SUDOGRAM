import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../core/ui/icon_styles.dart';
import '../../core/voice_fx.dart';

/// Voice-changer choice is remembered per chat (and is off by default).
void setChatFx(WidgetRef ref, int chatId, String id, {bool last = false}) {
  final key = last ? 'voiceFxLast' : 'voiceFxChat';
  final cur = Map<String, dynamic>.of(((ref.read(settingsProvider).x[key]) as Map?)?.cast<String, dynamic>() ?? const {});
  if (id == 'none' && !last) {
    cur.remove('$chatId');
  } else {
    cur['$chatId'] = id;
  }
  ref.read(settingsProvider.notifier).setX(key, cur);
}

/// Soft expanding ring used behind the mic while recording.
class PulseRing extends StatefulWidget {
  const PulseRing({super.key, required this.color, required this.size, required this.child, this.active = true});
  final Color color;
  final double size;
  final bool active;
  final Widget child;
  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.9,
      height: widget.size * 1.9,
      child: Stack(alignment: Alignment.center, children: [
        if (widget.active)
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Container(
              width: widget.size * (1 + .9 * _c.value),
              height: widget.size * (1 + .9 * _c.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: .35 * (1 - _c.value)),
              ),
            ),
          ),
        widget.child,
      ]),
    );
  }
}

/// Blinking dot (recording indicator).
class BlinkDot extends StatefulWidget {
  const BlinkDot({super.key, this.color = GlassTokens.ringDanger, this.size = 12});
  final Color color;
  final double size;
  @override
  State<BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<BlinkDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .25, end: 1.0).animate(_c),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: .7), blurRadius: 8)],
          ),
        ),
      );
}

/// Animated equaliser bars shown while audio plays.
class EqBars extends StatefulWidget {
  const EqBars({super.key, required this.color, this.height = 18});
  final Color color;
  final double height;
  @override
  State<EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 3,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              height: widget.height *
                  (.3 + .7 * (0.5 + 0.5 * math.sin((_c.value * 2 + i * .27) * math.pi * 2))),
              decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
            ),
        ]),
      );
}

/// Glowing voice-changer indicator (stays lit until the note is sent).
class FxGlow extends StatefulWidget {
  const FxGlow({super.key, required this.icon, required this.color, required this.glowing});
  final IconData icon;
  final Color color;
  final bool glowing;
  @override
  State<FxGlow> createState() => _FxGlowState();
}

class _FxGlowState extends State<FxGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.glowing
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: .35 + .45 * _c.value),
                      blurRadius: 8 + 12 * _c.value,
                      spreadRadius: 1 + 2 * _c.value,
                    ),
                  ]
                : null,
          ),
          child: SIcon(widget.icon, color: widget.color),
        ),
      );
}

/// Long-press sheet: pick an effect and preview it (Arabic then English).
class VoiceFxSheet extends ConsumerStatefulWidget {
  const VoiceFxSheet({super.key, required this.chatId});
  final int chatId;
  @override
  ConsumerState<VoiceFxSheet> createState() => _VoiceFxSheetState();
}

class _VoiceFxSheetState extends ConsumerState<VoiceFxSheet> {
  final _player = AudioPlayer();
  VoiceFx? _sel;
  bool _loading = false;
  bool _playing = false;
  String? _err;
  int _run = 0;

  @override
  void dispose() {
    _run++;
    _player.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    _run++;
    await _player.stop();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _preview(VoiceFx fx) async {
    final run = ++_run;
    setState(() {
      _loading = true;
      _playing = false;
      _err = null;
    });
    await _player.stop();
    try {
      final dir = (await getTemporaryDirectory()).path;
      final ar = await FxPreview.sample('ar', fx, dir);
      final en = await FxPreview.sample('en', fx, dir);
      if (!mounted || run != _run) return;
      setState(() {
        _loading = false;
        _playing = true;
      });
      for (final f in [ar, en]) {
        if (!mounted || run != _run) return;
        await _player.play(DeviceFileSource(f));
        await _player.onPlayerComplete.first.timeout(const Duration(seconds: 30));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } catch (e) {
      if (mounted && run == _run) {
        _err = context.t(
            'Could not play the sample. Make sure Google "Speech Services" with Arabic and English voices is installed.',
            'مقدرتش أشغّل العيّنة. اتأكد إن "خدمات الكلام من Google" متثبتة وفيها صوت عربي وإنجليزي.');
      }
    } finally {
      if (mounted && run == _run) {
        setState(() {
          _loading = false;
          _playing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = GlassScope.of(context).accent;
    final s = ref.watch(settingsProvider);
    final cur = voiceFxFrom(s.fxFor(widget.chatId));
    final sel = _sel ?? (cur == VoiceFx.none ? voiceFxFrom(s.fxLastFor(widget.chatId)) : cur);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GlassSurface(
        blur: true,
        radius: 26,
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(context.t('Voice changer', 'مغيّر الصوت'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Switch(
              value: cur != VoiceFx.none,
              onChanged: (on) {
                setChatFx(ref, widget.chatId, on ? sel.id : 'none');
                if (on) setChatFx(ref, widget.chatId, sel.id, last: true);
              },
            ),
          ]),
          Text(
              context.t('Tap the voice-changer button to switch it on/off. Pick an effect here, preview it, then use it.',
                  'اضغط على زرار تغيير الصوت مرة يتفعّل ومرة يتلغي. اختار التأثير من هنا وجرّبه قبل ما تستخدمه.'),
              style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .38),
            child: SingleChildScrollView(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in VoiceFx.values)
                  if (f != VoiceFx.none)
                    ChoiceChip(
                      avatar: SIcon(f.icon, size: 18, color: sel == f ? Colors.white : accent),
                      label: Text(f.label(context.isAr)),
                      selected: sel == f,
                      onSelected: (_) {
                        setState(() => _sel = f);
                        setChatFx(ref, widget.chatId, f.id, last: true);
                        if (cur != VoiceFx.none) setChatFx(ref, widget.chatId, f.id);
                        _preview(f);
                      },
                    ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _loading ? null : (_playing ? _stop : () => _preview(sel)),
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(_playing
                    ? context.t('Stop', 'إيقاف')
                    : context.t('Preview: Arabic then English', 'جرّب: عربي وبعدين إنجليزي')),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () {
                setChatFx(ref, widget.chatId, sel.id);
                setChatFx(ref, widget.chatId, sel.id, last: true);
                Navigator.of(context).pop();
              },
              child: Text(context.t('Use', 'استخدم')),
            ),
          ]),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_err!, style: const TextStyle(fontSize: 12, color: GlassTokens.ringDanger)),
            ),
        ]),
      ),
    );
  }
}



/// Pulsing + progress overlay for a message that is still uploading.
class UploadPulse extends StatefulWidget {
  const UploadPulse({super.key, required this.active, required this.progress, required this.child, this.label});
  final bool active;
  final double progress; // 0..1, 0 = unknown
  final String? label;
  final Widget child;
  @override
  State<UploadPulse> createState() => _UploadPulseState();
}

class _UploadPulseState extends State<UploadPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
        ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    final accent = GlassScope.of(context).accent;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Opacity(opacity: .6 + .4 * _c.value, child: child),
        child: widget.child,
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          minHeight: 4,
          value: widget.progress > 0.01 ? widget.progress : null,
          color: accent,
          backgroundColor: Colors.white12,
        ),
      ),
      if (widget.label != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(widget.label!, style: const TextStyle(fontSize: 11, color: GlassTokens.textSecondary)),
        ),
    ]);
  }
}

/// Heart/emoji burst plus a soft red pulse along the bottom of the screen.
void showReactionBurst(BuildContext context, String emoji) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Burst(emoji: emoji, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Burst extends StatefulWidget {
  const _Burst({required this.emoji, required this.onDone});
  final String emoji;
  final VoidCallback onDone;
  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
        ..forward().whenComplete(widget.onDone);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final red = widget.emoji.contains('❤') || widget.emoji.contains('😍') || widget.emoji.contains('🔥');
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          // two soft beats of the bottom glow
          final beat = math.max(0.0, math.sin(t * math.pi * 2 * 1.5 - .3)) * (1 - t);
          final pop = t < .25 ? Curves.easeOutBack.transform(t / .25) : 1.0;
          final fade = t < .6 ? 1.0 : (1 - (t - .6) / .4);
          return Stack(children: [
            if (red)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 260,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFFFF1744).withValues(alpha: .38 * beat),
                        const Color(0xFFFF1744).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            Center(
              child: Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -80 * t),
                  child: Transform.scale(
                    scale: 0.4 + 1.5 * pop,
                    child: Text(widget.emoji,
                        style: const TextStyle(fontSize: 96, decoration: TextDecoration.none)),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
