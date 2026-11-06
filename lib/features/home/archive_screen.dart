import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../chat/avatar.dart';
import '../chat/chat_screen.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(archivedProvider).value ?? const [];
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(l.archive)),
      body: ListView(children: [
        for (final c in list)
          ListTile(
            leading: AvatarCircle(title: c.title, photo: c.avatar, size: 42),
            title: Text(c.title),
            subtitle: Text(c.lastText, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: c))),
            onLongPress: () =>
                ref.read(gatewayProvider).setArchived(c.id, false),
          ),
      ]),
    );
  }
}
