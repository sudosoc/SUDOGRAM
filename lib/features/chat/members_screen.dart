import 'package:flutter/material.dart';
import '../../core/ui/notice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ui/icon_styles.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import 'avatar.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key, required this.chat});
  final ChatSummary chat;

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  late Future<List<MentionCandidate>> _f =
      ref.read(gatewayProvider).members(widget.chat.id);

  void _reload() =>
      setState(() => _f = ref.read(gatewayProvider).members(widget.chat.id));

  Future<void> _run(Future<void> Function() f) async {
    final l = AppLocalizations.of(context);
    try {
      await f();
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, ar: l.localeName == 'ar'))));
    }
  }

  Future<void> _add() async {
    final gw = ref.read(gatewayProvider);
    final contacts = await gw.contacts();
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final picked = await showDialog<ChatSummary>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(l.addMember),
        children: [
          SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView(children: [
              for (final c in contacts)
                ListTile(
                  title: Text(c.title),
                  onTap: () => Navigator.pop(context, c),
                ),
            ]),
          ),
        ],
      ),
    );
    if (picked != null) await _run(() => gw.addMember(widget.chat.id, picked.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gw = ref.read(gatewayProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l.members),
        actions: [
          if (widget.chat.type == ChatType.group)
            IconButton(icon: const SIcon(Icons.person_add_alt), onPressed: _add),
        ],
      ),
      body: FutureBuilder<List<MentionCandidate>>(
        future: _f,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: Text(l.connecting));
          }
          final list = snap.data ?? const <MentionCandidate>[];
          return ListView(children: [
            for (final m in list)
              ListTile(
                leading: AvatarCircle(title: m.name, size: 40),
                title: Text(m.name),
                subtitle: m.username.isEmpty ? null : Text('@${m.username}'),
                trailing: widget.chat.type == ChatType.group
                    ? IconButton(
                        icon: const SIcon(Icons.person_remove_outlined),
                        tooltip: l.removeMember,
                        onPressed: () =>
                            _run(() => gw.removeMember(widget.chat.id, m.id)),
                      )
                    : null,
              ),
          ]);
        },
      ),
    );
  }
}
