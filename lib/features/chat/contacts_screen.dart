import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import 'avatar.dart';
import 'chat_screen.dart';

/// Contacts list + "Saved Messages"; tapping opens the private chat.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  late final _future = ref.read(gatewayProvider).contacts();
  String _q = '';

  Future<void> _open(Future<ChatSummary?> chat) async {
    final c = await chat;
    if (c == null || !mounted) return;
    await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: c)));
  }

  Future<void> _newGroup() async {
    final l = AppLocalizations.of(context);
    final all = await _future;
    if (!mounted) return;
    final name = TextEditingController();
    final picked = <int>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(l.newGroup),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: InputDecoration(hintText: l.groupName)),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final c in all)
                    CheckboxListTile(
                      value: picked.contains(c.id),
                      title: Text(c.title),
                      onChanged: (v) => set(() =>
                          v == true ? picked.add(c.id) : picked.remove(c.id)),
                    ),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.create)),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || picked.isEmpty) return;
    await _open(ref.read(gatewayProvider).createGroup(name.text.trim(), picked.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gw = ref.read(gatewayProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: GlassSurface(
              blur: true,
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(children: [
                IconButton(
                    icon: const BackButtonIcon(),
                    onPressed: () => Navigator.of(context).pop()),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v.toLowerCase()),
                    decoration: InputDecoration(
                        hintText: l.contacts,
                        border: InputBorder.none,
                        filled: false),
                  ),
                ),
              ]),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.group_add_outlined)),
            title: Text(l.newGroup),
            onTap: _newGroup,
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.bookmark_outline)),
            title: Text(l.savedMessages),
            onTap: () => _open(gw.savedMessages()),
          ),
          Expanded(
            child: FutureBuilder<List<ChatSummary>>(
              future: _future,
              builder: (_, snap) {
                final list = [
                  for (final c in snap.data ?? const <ChatSummary>[])
                    if (_q.isEmpty || c.title.toLowerCase().contains(_q)) c
                ];
                if (snap.connectionState != ConnectionState.done) {
                  return Center(child: Text(l.connecting));
                }
                if (list.isEmpty) return Center(child: Text(l.noResults));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: AvatarCircle(title: list[i].title, size: 42),
                    title: Text(list[i].title),
                    subtitle: list[i].lastText.isEmpty
                        ? null
                        : Text('@${list[i].lastText}'),
                    onTap: () => _open(gw.openPrivateChat(list[i].id)),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
