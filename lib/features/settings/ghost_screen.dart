import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../chat/avatar.dart';

/// Everything about Ghost Mode in one place.
class GhostScreen extends ConsumerWidget {
  const GhostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final chats = ref.watch(chatsProvider).value ?? const <ChatSummary>[];
    final overridden = [
      for (final ch in chats)
        if (s.ghostOverrides.containsKey(ch.id) ||
            s.chatHidesRead(ch.id) != null ||
            s.chatHidesTyping(ch.id) != null)
          ch
    ];
    final on = s.ghostGlobal;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
          backgroundColor: Colors.transparent, title: Text(l.ghostSettings)),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 32), children: [
        GlassSurface(
          radius: 24,
          borderColor: on ? GlassTokens.ghost.withValues(alpha: 0.6) : null,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(on ? Icons.visibility_off : Icons.visibility,
                size: 40, color: on ? GlassTokens.ghost : Colors.white54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(on ? l.ghostStatusOn : l.ghostStatusOff,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(l.ghostHint,
                    style: const TextStyle(
                        fontSize: 12, color: GlassTokens.textSecondary)),
              ]),
            ),
            Switch(value: on, onChanged: c.setGhostGlobal),
          ]),
        ),
        const SizedBox(height: 12),
        _Header(l.ghostPauseTitle),
        GlassSurface(
          radius: 20,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                s.ghostPaused
                    ? l.ghostPausedUntil(
                        '${s.ghostPausedUntil!.hour.toString().padLeft(2, '0')}:${s.ghostPausedUntil!.minute.toString().padLeft(2, '0')}')
                    : l.ghostPauseHint,
                style: const TextStyle(color: GlassTokens.textSecondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final (label, mins) in [
                ('5', 5),
                ('15', 15),
                ('30', 30),
                ('60', 60),
              ])
                ActionChip(
                  label: Text(l.ghostPauseMin(label)),
                  onPressed: () => c.setX(
                      'ghostPauseUntil',
                      DateTime.now()
                          .add(Duration(minutes: mins))
                          .millisecondsSinceEpoch),
                ),
              if (s.ghostPaused)
                ActionChip(
                  avatar: const Icon(Icons.play_arrow, size: 16),
                  label: Text(l.ghostResume),
                  onPressed: () => c.setX('ghostPauseUntil', null),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        _Header(l.ghostWhatToHide),
        GlassSurface(
          radius: 20,
          child: Column(children: [
            SwitchListTile(
              secondary: const Icon(Icons.done_all),
              title: Text(l.ghostReadReceipts),
              subtitle: Text(l.ghostReadHint),
              value: s.ghostRead,
              onChanged: (v) => c.setX('ghostRead', v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.keyboard_outlined),
              title: Text(l.ghostTypingT),
              subtitle: Text(l.ghostTypingHint),
              value: s.ghostTyping,
              onChanged: (v) => c.setX('ghostTyping', v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.circle_outlined),
              title: Text(l.ghostOnlineStatus),
              subtitle: Text(l.ghostOnlineHint),
              value: s.ghostOnline,
              onChanged: (v) => c.setX('ghostOnline', v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: Text(l.ghostForceHidden),
              subtitle: Text(l.ghostForceHint),
              value: s.ghostForceHidden,
              onChanged: (v) => c.setX('ghostForceHidden', v),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Text(l.ghostManualRead,
              style: const TextStyle(
                  fontSize: 12, color: GlassTokens.textSecondary)),
        ),
        const SizedBox(height: 12),
        _Header(l.ghostPerChat),
        if (overridden.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.ghostNoOverrides,
                style: const TextStyle(color: GlassTokens.textSecondary)),
          )
        else
          GlassSurface(
            radius: 20,
            child: Column(children: [
              for (final ch in overridden)
                ListTile(
                  leading: AvatarCircle(title: ch.title, photo: ch.avatar, size: 36),
                  title: Text(s.aliases[ch.id] ?? ch.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text([
                    if (s.ghostOverrides.containsKey(ch.id))
                      s.ghostOverrides[ch.id]! ? l.ghostOnShort : l.ghostOffShort,
                    if (s.chatHidesRead(ch.id) != null)
                      '${l.ghostReadReceipts}: ${s.chatHidesRead(ch.id)! ? '✓' : '✗'}',
                    if (s.chatHidesTyping(ch.id) != null)
                      '${l.ghostTypingT}: ${s.chatHidesTyping(ch.id)! ? '✓' : '✗'}',
                  ].join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.restart_alt),
                    tooltip: l.ghostResetChat,
                    onPressed: () {
                      c.setGhostOverride(ch.id, null);
                      c.setChatGhostPart(ch.id, 'read', null);
                      c.setChatGhostPart(ch.id, 'typing', null);
                    },
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Text(text,
            style: const TextStyle(
                color: GlassTokens.textSecondary, fontWeight: FontWeight.w600)),
      );
}
