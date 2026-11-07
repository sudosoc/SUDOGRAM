import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../domain/models.dart';
import 'avatar.dart';
import 'chat_screen.dart';

class CommonGroupsScreen extends ConsumerStatefulWidget {
  const CommonGroupsScreen({super.key, required this.userId});
  final int userId;

  @override
  ConsumerState<CommonGroupsScreen> createState() => _CommonGroupsScreenState();
}

class _CommonGroupsScreenState extends ConsumerState<CommonGroupsScreen> {
  late final Future<List<ChatSummary>> _f =
      ref.read(gatewayProvider).commonGroups(widget.userId);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(context.t('Groups in common', 'الجروبات المشتركة')),
        ),
        body: FutureBuilder<List<ChatSummary>>(
          future: _f,
          builder: (c, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final l = snap.data!;
            if (l.isEmpty) {
              return Center(
                  child: Text(context.t('No common groups', 'مفيش جروبات مشتركة')));
            }
            return ListView(children: [
              for (final g in l)
                ListTile(
                  leading: AvatarCircle(
                      title: g.title, photo: g.avatar, chatId: g.id, size: 44),
                  title: Text(g.title),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(chat: g))),
                ),
            ]);
          },
        ),
      );
}
