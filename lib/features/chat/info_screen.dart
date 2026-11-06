import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import 'avatar.dart';

/// Profile (private chats) or group / channel details.
class ChatInfoScreen extends ConsumerWidget {
  const ChatInfoScreen({super.key, required this.chat});

  final ChatSummary chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    Widget row(IconData i, String label, String v) => ListTile(
          leading: Icon(i),
          title: SelectableText(v),
          subtitle: Text(label,
              style: const TextStyle(color: GlassTokens.textSecondary)),
        );
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(l.info)),
      body: FutureBuilder<ChatInfo?>(
        future: ref.read(gatewayProvider).chatInfo(chat.id),
        builder: (_, snap) {
          final i = snap.data;
          return ListView(children: [
            const SizedBox(height: 12),
            Center(
                child:
                    AvatarCircle(title: chat.title, photo: chat.avatar, size: 96)),
            const SizedBox(height: 12),
            Center(
                child: Text(chat.title,
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 16),
            if (i != null) ...[
              if (i.members > 0)
                row(Icons.group_outlined, '', l.membersCount('${i.members}')),
              if (i.username.isNotEmpty)
                row(Icons.alternate_email, l.username, '@${i.username}'),
              if (i.phone.isNotEmpty) row(Icons.phone_outlined, l.phone, '+${i.phone}'),
              if (i.about.isNotEmpty) row(Icons.info_outline, l.about, i.about),
            ],
          ]);
        },
      ),
    );
  }
}
