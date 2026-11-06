import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_screen.dart' show kindLabel;
import '../splitter/smart_splitter.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chat});

  final ChatSummary chat;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _c = TextEditingController();
  int _limit = 4096;
  int _parts = 1;
  late final _gateway = ref.read(gatewayProvider);

  @override
  void initState() {
    super.initState();
    _gateway.openChat(widget.chat.id);
    _gateway.messageTextLimit().then((v) {
      if (mounted) setState(() => _limit = v);
    });
  }

  @override
  void dispose() {
    _gateway.closeChat(widget.chat.id);
    _c.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    // Typing indicator goes through the Ghost guard; in ghost mode it's dropped.
    if (v.isNotEmpty) _gateway.sendTyping(widget.chat.id);
    final n = v.isEmpty ? 1 : SmartSplitter.countParts(v, SplitOptions(maxLength: _limit));
    if (n != _parts) setState(() => _parts = n);
  }

  Future<void> _send() async {
    final text = _c.text;
    if (text.trim().isEmpty) return;
    final parts = SmartSplitter.split(text, SplitOptions(maxLength: _limit));
    _c.clear();
    setState(() => _parts = 1);
    for (final p in parts) {
      await _gateway.sendText(widget.chat.id, p); // strictly in order
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final msgs = ref.watch(messagesProvider(widget.chat.id));
    final ghost = ref.watch(settingsProvider).ghostFor(widget.chat.id);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: GlassSurface(
                blur: true,
                radius: 22,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(children: [
                  IconButton(
                    tooltip: l.back,
                    icon: const BackButtonIcon(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(widget.chat.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 17)),
                  ),
                  Tooltip(
                    message:
                        ghost ? l.ghostOffForChat : l.ghostOnForChat,
                    child: IconButton(
                      icon: Icon(Icons.visibility_off_outlined,
                          color: ghost ? GlassTokens.ghost : Colors.white54),
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .setGhostOverride(widget.chat.id, !ghost),
                    ),
                  ),
                ]),
              ),
            ),
            if (ghost)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l.silentRead,
                    style: const TextStyle(
                        fontSize: 12, color: GlassTokens.ghost)),
              ),
            Expanded(
              child: msgs.when(
                loading: () => Center(child: Text(l.connecting)),
                error: (e, _) => Center(child: Text(l.errorGeneric)),
                data: (list) => list.isEmpty
                    ? Center(child: Text(l.noMessages))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _Bubble(m: list[i]),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Column(children: [
                if (_parts > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(l.splitNotice('$_parts'),
                        style: const TextStyle(
                            fontSize: 12, color: GlassTokens.textSecondary)),
                  ),
                GlassSurface(
                  blur: true,
                  radius: 26,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _c,
                        minLines: 1,
                        maxLines: 6,
                        onChanged: _onChanged,
                        decoration: InputDecoration(
                          hintText: l.typeMessage,
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.send,
                      icon: const Icon(Icons.send_rounded),
                      onPressed: _send,
                    ),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});

  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = GlassScope.of(context).accent;
    final text = m.text.isNotEmpty ? m.text : kindLabel(l, m.kind);
    return Align(
      alignment: m.outgoing
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: m.outgoing
              ? accent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: GlassTokens.fill),
          border: Border.all(
            color: m.deletedByPeer
                ? GlassTokens.ringDanger.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: GlassTokens.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            if (m.edited || m.deletedByPeer)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  [
                    if (m.deletedByPeer) l.deletedByPeer,
                    if (m.edited) l.edited,
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 11, color: GlassTokens.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
