import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import 'avatar.dart';
import 'chat_screen.dart';

/// The contact of a shared-contact message (live data, or parsed from the
/// archived text when the message was restored from disk).
ContactCard? contactOf(ChatMessage m) =>
    m.contact ?? (m.kind == MessageKind.other ? ContactCard.parse(m.text) : null);

/// A tidy card for a shared contact: avatar, name, number and quick actions.
class ContactCardView extends ConsumerWidget {
  const ContactCardView({super.key, required this.card});

  final ContactCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final accent = GlassScope.of(context).accent;
    final phone = card.phone.isEmpty ? '' : '+${card.phone}';
    void copy(String v) {
      Clipboard.setData(ClipboardData(text: v));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.copied)));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      width: 240,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AvatarCircle(title: card.name.isEmpty ? '?' : card.name, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(card.name.isEmpty ? phone : card.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (phone.isNotEmpty)
                GestureDetector(
                  onTap: () => copy(phone),
                  onLongPress: () => copy(phone),
                  child: Text(phone,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: accent, fontSize: 14)),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Wrap(spacing: 4, children: [
          if (card.userId != 0)
            TextButton.icon(
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: Text(l.contactMessage),
              onPressed: () async {
                final nav = Navigator.of(context);
                final c = await ref.read(gatewayProvider).openPrivateChat(card.userId);
                if (c != null) {
                  nav.push(MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: c)));
                }
              },
            ),
          if (phone.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l.contactCopyPhone),
              onPressed: () => copy(phone),
            ),
          if (card.name.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.person_outline, size: 16),
              label: Text(l.contactCopyName),
              onPressed: () => copy(card.name),
            ),
          if (phone.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.call_outlined, size: 16),
              label: Text(l.contactCall),
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
            ),
        ]),
      ]),
    );
  }
}
