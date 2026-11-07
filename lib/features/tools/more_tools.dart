import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/drafts.dart';
import '../../core/i18n/tr.dart';
import '../../core/theme/glass.dart';
import '../../core/ui/icon_styles.dart';
import '../../core/ui/notice.dart';
import '../chat/avatar.dart';
import '../chat/chat_screen.dart';
import '../settings/widgets.dart';

int _n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

Widget _scaffold(BuildContext c, String title, Widget body) => Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(title)),
      body: body,
    );

/// Extra tools listed at the bottom of the Power hub.
List<Widget> moreToolsTiles(BuildContext context) {
  Widget t(IconData i, String en, String ar, String hen, String har, Widget w) =>
      ListTile(
        leading: SIcon(i),
        title: Text(context.t(en, ar)),
        subtitle: SHint(context.t(hen, har)),
        trailing: const SIcon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => w)),
      );
  return [
    t(Icons.block, 'Blocked users', 'المحظورين',
        'See everyone you blocked and unblock in one tap.',
        'شوف كل اللي حظرتهم وفك الحظر بضغطة.', const _Blocked()),
    t(Icons.auto_delete_outlined, 'Account self-destruct', 'حذف الحساب التلقائي',
        'How long of inactivity before the account is deleted.',
        'مدة عدم النشاط قبل ما الحساب يتحذف.', const _Ttl()),
    t(Icons.alternate_email, 'Username & bio', 'اليوزر والنبذة',
        'Edit your public @username and about text.',
        'عدّل اليوزر والنبذة التعريفية.', const _Profile()),
    t(Icons.people_alt_outlined, 'Frequent contacts', 'أكتر ناس بتكلمهم',
        'The people you talk to the most, ranked by Telegram.',
        'أكتر الناس اللي بتتواصل معاهم حسب تليجرام.', const _Frequent()),
    t(Icons.drafts_outlined, 'All drafts', 'كل المسودات',
        'Unsent messages across every chat, tap to continue.',
        'الرسايل اللي ما اتبعتتش في كل الشاتات، اضغط وكمّل.', const _Drafts()),
  ];
}

class _Blocked extends ConsumerStatefulWidget {
  const _Blocked();
  @override
  ConsumerState<_Blocked> createState() => _BlockedState();
}

class _BlockedState extends ConsumerState<_Blocked> {
  List<(int, String)>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = ref.read(gatewayProvider);
    try {
      final r = await g.tdRaw({
        '@type': 'getBlockedMessageSenders',
        'block_list': {'@type': 'blockListMain'},
        'offset': 0,
        'limit': 100,
      });
      final out = <(int, String)>[];
      for (final s in (r['senders'] as List? ?? const []).whereType<Map>()) {
        final id = _n((s['sender_id'] as Map?)?['user_id']);
        if (id == 0) continue;
        try {
          final u = await g.tdRaw({'@type': 'getUser', 'user_id': id});
          out.add((id, '${u['first_name']} ${u['last_name']}'.trim()));
        } catch (_) {
          out.add((id, '$id'));
        }
      }
      if (mounted) setState(() => _list = out);
    } catch (e) {
      if (mounted) {
        notice(context, friendlyError(e, ar: context.isAr), kind: NoticeKind.error);
        setState(() => _list = []);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _scaffold(
        context,
        context.t('Blocked users', 'المحظورين'),
        _list == null
            ? const Center(child: CircularProgressIndicator())
            : _list!.isEmpty
                ? Center(child: Text(context.t('Nobody is blocked', 'مفيش حد محظور')))
                : ListView(children: [
                    for (final (id, name) in _list!)
                      ListTile(
                        leading: AvatarCircle(title: name, size: 40),
                        title: Text(name),
                        trailing: TextButton(
                          child: Text(context.t('Unblock', 'فك الحظر')),
                          onPressed: () async {
                            await ref.read(gatewayProvider).tdRaw({
                              '@type': 'setMessageSenderBlockList',
                              'sender_id': {'@type': 'messageSenderUser', 'user_id': id},
                              'block_list': null,
                            });
                            _load();
                          },
                        ),
                      ),
                  ]),
      );
}

class _Ttl extends ConsumerStatefulWidget {
  const _Ttl();
  @override
  ConsumerState<_Ttl> createState() => _TtlState();
}

class _TtlState extends ConsumerState<_Ttl> {
  int? _days;

  @override
  void initState() {
    super.initState();
    ref
        .read(gatewayProvider)
        .tdRaw({'@type': 'getAccountTtl'})
        .then((r) {
      if (mounted) setState(() => _days = _n(r['days']));
    }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) => _scaffold(
        context,
        context.t('Account self-destruct', 'حذف الحساب التلقائي'),
        ListView(children: [
          SHint(context.t('If you do not log in for this long, the account is deleted.',
              'لو ما دخلتش الحساب المدة دي، الحساب هيتحذف.')),
          for (final d in const [30, 90, 180, 365])
            ListTile(
              title: Text(context.t('$d days', '$d يوم')),
              trailing: _days == d ? const SIcon(Icons.check_circle) : null,
              onTap: () async {
                final ctx = context;
                try {
                  await ref.read(gatewayProvider).tdRaw({
                    '@type': 'setAccountTtl',
                    'ttl': {'@type': 'accountTtl', 'days': d},
                  });
                  if (mounted) setState(() => _days = d);
                } catch (e) {
                  if (mounted && ctx.mounted) {
                    notice(ctx, friendlyError(e, ar: ctx.isAr), kind: NoticeKind.error);
                  }
                }
              },
            ),
        ]),
      );
}

class _Profile extends ConsumerStatefulWidget {
  const _Profile();
  @override
  ConsumerState<_Profile> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<_Profile> {
  final _user = TextEditingController();
  final _bio = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = ref.read(gatewayProvider);
    try {
      final me = await g.tdRaw({'@type': 'getMe'});
      _user.text = '${(me['usernames'] as Map?)?['editable_username'] ?? ''}';
      final f = await g.tdRaw({'@type': 'getUserFullInfo', 'user_id': me['id']});
      _bio.text = '${(f['bio'] as Map?)?['text'] ?? ''}';
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final g = ref.read(gatewayProvider);
    try {
      await g.tdRaw({'@type': 'setUsername', 'username': _user.text.trim()});
      await g.tdRaw({'@type': 'setBio', 'bio': _bio.text.trim()});
      if (mounted) {
        notice(context, context.t('Saved', 'تم الحفظ'), kind: NoticeKind.success);
      }
    } catch (e) {
      if (mounted) {
        notice(context, friendlyError(e, ar: context.isAr), kind: NoticeKind.error);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => _scaffold(
        context,
        context.t('Username & bio', 'اليوزر والنبذة'),
        ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
            controller: _user,
            decoration: InputDecoration(
                labelText: context.t('Username', 'اليوزر'), prefixText: '@'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLength: 70,
            decoration: InputDecoration(labelText: context.t('Bio', 'النبذة')),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(context.t('Save', 'حفظ')),
          ),
        ]),
      );
}

class _Frequent extends ConsumerStatefulWidget {
  const _Frequent();
  @override
  ConsumerState<_Frequent> createState() => _FrequentState();
}

class _FrequentState extends ConsumerState<_Frequent> {
  List<(int, String)>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = ref.read(gatewayProvider);
    try {
      final r = await g.tdRaw({
        '@type': 'getTopChats',
        'category': {'@type': 'topChatCategoryUsers'},
        'limit': 30,
      });
      final out = <(int, String)>[];
      for (final id in (r['chat_ids'] as List? ?? const [])) {
        try {
          final c = await g.tdRaw({'@type': 'getChat', 'chat_id': id});
          out.add((_n(id), '${c['title']}'));
        } catch (_) {}
      }
      if (mounted) setState(() => _list = out);
    } catch (_) {
      if (mounted) setState(() => _list = []);
    }
  }

  @override
  Widget build(BuildContext context) => _scaffold(
        context,
        context.t('Frequent contacts', 'أكتر ناس بتكلمهم'),
        _list == null
            ? const Center(child: CircularProgressIndicator())
            : _list!.isEmpty
                ? Center(child: Text(context.t('Nothing yet', 'لسه مفيش')))
                : ListView(children: [
                    for (final (id, name) in _list!)
                      ListTile(
                        leading: AvatarCircle(title: name, size: 40),
                        title: Text(name),
                        onTap: () async {
                          final nav = Navigator.of(context);
                          final c = await ref.read(gatewayProvider).openPrivateChat(id);
                          if (c != null) {
                            nav.push(MaterialPageRoute<void>(
                                builder: (_) => ChatScreen(chat: c)));
                          }
                        },
                      ),
                  ]),
      );
}

class _Drafts extends ConsumerWidget {
  const _Drafts();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatsProvider).value ?? const [];
    final rows = [
      for (final c in chats)
        if (DraftStore.get(c.id).isNotEmpty) c,
    ];
    return _scaffold(
      context,
      context.t('All drafts', 'كل المسودات'),
      rows.isEmpty
          ? Center(child: Text(context.t('No drafts', 'مفيش مسودات')))
          : ListView(children: [
              for (final c in rows)
                ListTile(
                  leading: AvatarCircle(title: c.title, size: 40),
                  title: Text(c.title),
                  subtitle: Text(DraftStore.get(c.id),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const SIcon(Icons.edit_outlined, size: 18,
                      color: GlassTokens.textSecondary),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(chat: c))),
                ),
            ]),
    );
  }
}
