import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/ui/icon_styles.dart';

import '../downloads/keep_alive.dart';
import '../../core/drafts.dart';
import '../chat/avatar.dart';
import 'archive_screen.dart';
import '../tools/tools_hub.dart';
import 'bottom_bar.dart';
import '../chat/contacts_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/device_perms.dart';
import '../../core/media_save.dart';
import '../../domain/media_events.dart';
import '../../core/i18n/tr.dart';
import '../settings/permissions_screen.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../data/archive/archive_db.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_screen.dart';
import 'chat_actions.dart';
import 'hidden_gate.dart';
import '../settings/ghost_screen.dart';
import 'account_switcher.dart';

String kindLabel(AppLocalizations l, MessageKind k) => switch (k) {
  MessageKind.photo => l.kindPhoto,
  MessageKind.video => l.kindVideo,
  MessageKind.voice => l.kindVoice,
  MessageKind.document => l.kindDocument,
  MessageKind.sticker => l.kindSticker,
  _ => l.kindOther,
};

String _fmtTime(DateTime t) {
  final n = DateTime.now();
  if (n.difference(t).inHours < 24 && n.day == t.day) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
  return '${t.day}/${t.month}';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _searching = false;
  String _query = '';
  String _section = 'all'; // all, unread, people, groups, channels, f:<folder>

  bool _inSection(ChatSummary c, AppSettings s) {
    if (_section == 'all') return true;
    if (_section.startsWith('f:')) {
      return s.folders[_section.substring(2)]?.contains(c.id) ?? false;
    }
    return switch (_section) {
      'unread' => c.unread > 0 || c.markedUnread,
      'people' => c.type == ChatType.private || c.type == ChatType.secret,
      'groups' => c.type == ChatType.group,
      'channels' => c.type == ChatType.channel,
      _ => true,
    };
  }

  Future<void> _folderMenu(String name) async {
    final l = AppLocalizations.of(context);
    final c = ref.read(settingsProvider.notifier);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: GlassSurface(
          blur: true,
          radius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const SIcon(Icons.edit_outlined),
                title: Text(l.renameSection),
                onTap: () => Navigator.pop(sctx, 'rename'),
              ),
              ListTile(
                leading: const SIcon(
                  Icons.delete_outline,
                  color: GlassTokens.ringDanger,
                ),
                title: Text(
                  l.deleteSection,
                  style: const TextStyle(color: GlassTokens.ringDanger),
                ),
                onTap: () => Navigator.pop(sctx, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'rename') {
      final n = await askText(
        context,
        l.renameSection,
        l.sectionName,
        initial: name,
      );
      if (n != null && n.trim().isNotEmpty && n.trim() != name) {
        c.renameFolder(name, n.trim());
        if (_section == 'f:$name') setState(() => _section = 'f:${n.trim()}');
      }
    } else if (await confirmDialog(context, l.deleteSectionQ)) {
      c.deleteFolder(name);
      if (_section == 'f:$name') setState(() => _section = 'all');
    }
  }

  int _titleTaps = 0;
  DateTime _lastTap = DateTime(2000);

  void _titleTap(Set<String> methods) {
    if (!methods.contains('title')) return;
    final now = DateTime.now();
    _titleTaps = now.difference(_lastTap).inMilliseconds < 700
        ? _titleTaps + 1
        : 1;
    _lastTap = now;
    if (_titleTaps >= 3) {
      _titleTaps = 0;
      _openVault();
    }
  }

  String _titleText(AppLocalizations l, AppSettings s) {
    switch (s.titleMode) {
      case 1:
        final u = ref.watch(meProvider).value?.username ?? '';
        return u.isEmpty ? l.appTitle : '@$u';
      case 2:
        return '';
      default:
        return l.appTitle;
    }
  }

  @override
  void initState() {
    super.initState();
    MediaEvents.onDownloaded =
        (m) => autoSaveIfWanted(ref.read(settingsProvider), m);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _askBackground();
      await _askDevicePerms();
    });
  }

  /// Every launch: asks for whatever is still missing (one prompt each,
  /// never for permissions Android has locked to "don't ask again").
  Future<void> _askDevicePerms() async {
    if (!mounted) return;
    for (final p in [
      Permission.notification,
      Permission.location,
      Permission.contacts,
    ]) {
      final st = await p.status;
      if (st.isGranted || st.isLimited || st.isPermanentlyDenied) continue;
      if (!mounted) return;
      final it = PermissionsScreenState.items.firstWhere((e) => e.$1 == p);
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(context.t(it.$3, it.$4)),
          content: Text(context.t(it.$5, it.$6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t('Not now', 'مش دلوقتي')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.t('Allow', 'سماح')),
            ),
          ],
        ),
      );
      if (ok != true) continue;
      await p.request();
    }
    if (!mounted) return;
    if (await Permission.contacts.isGranted) {
      try {
        await syncPhoneContacts(ref.read(gatewayProvider));
      } catch (_) {}
    }
  }

  /// Once, explain why background activity is needed, then ask Android.
  Future<void> _askBackground() async {
    if (!ref.read(settingsProvider).notifications) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('asked_background') ?? false) return;
    if (await backgroundAllowed() || !mounted) return;
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.backgroundTitle),
        content: Text(l.backgroundBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.later),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.allow),
          ),
        ],
      ),
    );
    await prefs.setBool('asked_background', true);
    if (ok == true) await requestBackground();
  }

  /// Any of the enabled gestures: auth (biometrics and / or passcode), then
  /// the hidden chats open.
  Future<void> _openVault() => openHiddenChats(context, ref);

  // Rubbing the title left-right-left opens it too (method "swipe").
  double _wiggleDir = 0;
  int _wiggles = 0;
  void _wiggle(double dx, Set<String> methods) {
    if (!methods.contains('swipe') || dx.abs() < 2) return;
    final dir = dx.sign;
    if (_wiggleDir != 0 && dir != _wiggleDir) _wiggles++;
    _wiggleDir = dir;
    if (_wiggles >= 3) {
      _wiggles = 0;
      _wiggleDir = 0;
      _openVault();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final chats = ref.watch(chatsProvider);
    final demo = ref.watch(gatewayProvider).isDemo;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: demo || !settings.homeShowFab
          ? null
          : GestureDetector(
              onLongPress: settings.hiddenMethods.contains('fab')
                  ? _openVault
                  : null,
              child: FloatingActionButton(
                tooltip: l.newChat,
                backgroundColor: GlassScope.of(context).accent,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ContactsScreen(),
                  ),
                ),
                child: const SIcon(Icons.edit_outlined),
              ),
            ),
      bottomNavigationBar: const AppBottomBar(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _searching
                        ? TextField(
                            autofocus: true,
                            decoration: InputDecoration(hintText: l.searchHint),
                            onChanged: (v) {
                              if (settings.hiddenMethods.contains('code') &&
                                  settings.hiddenCode.isNotEmpty &&
                                  v.trim() == settings.hiddenCode) {
                                setState(() {
                                  _searching = false;
                                  _query = '';
                                });
                                _openVault();
                                return;
                              }
                              setState(() => _query = v);
                            },
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (_) {
                              _wiggles = 0;
                              _wiggleDir = 0;
                            },
                            onHorizontalDragUpdate: (d) =>
                                _wiggle(d.delta.dx, settings.hiddenMethods),
                            onTap: () => _titleTap(settings.hiddenMethods),
                            child: SizedBox(
                              height: 40,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  _titleText(l, settings),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (demo)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: GlassSurface(
                        radius: 14,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          l.demoMode,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  const AccountSwitcherButton(),
                  if (settings.homeShowGhost)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GhostScreen(),
                        ),
                      ),
                      onLongPress: () {
                        if (settings.hiddenMethods.contains('ghost')) {
                          _openVault();
                        } else {
                          ref
                              .read(settingsProvider.notifier)
                              .setGhostGlobal(!settings.ghostGlobal);
                        }
                      },
                      child: GlassSurface(
                        radius: 16,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        borderColor: settings.ghostGlobal
                            ? GlassTokens.ghost.withValues(alpha: 0.6)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SIcon(
                              Icons.visibility_off_outlined,
                              size: 16,
                              color: settings.ghostGlobal
                                  ? GlassTokens.ghost
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              settings.ghostGlobal
                                  ? l.ghostOnShort
                                  : l.ghostOffShort,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (settings.homeShowTools) ...[
                    const SizedBox(width: 8),
                    GlassIconButton(
                      icon: Icons.handyman_outlined,
                      tooltip: 'Tools',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ToolsHubScreen(),
                        ),
                      ),
                    ),
                  ],
                  if (settings.homeShowSettings) ...[
                    const SizedBox(width: 8),
                    GlassIconButton(
                      icon: Icons.tune,
                      tooltip: l.settings,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      onLongPress: settings.hiddenMethods.contains('settings')
                          ? _openVault
                          : null,
                    ),
                  ],
                  const SizedBox(width: 8),
                  if (settings.homeShowSearch || _searching)
                    GlassIconButton(
                      icon: _searching ? Icons.close : Icons.search,
                      tooltip: l.search,
                      onPressed: () => setState(() {
                        _searching = !_searching;
                        if (!_searching) _query = '';
                      }),
                      onLongPress: settings.hiddenMethods.contains('search')
                          ? _openVault
                          : null,
                    ),
                ],
              ),
            ),
            if (settings.homeSections || settings.folders.isNotEmpty)
              Builder(
                builder: (context) {
                  final all = chats.value ?? const <ChatSummary>[];
                  final visible = [
                    for (final c in all)
                      if (!settings.hiddenChats.contains(c.id)) c,
                  ];
                  int unread(bool Function(ChatSummary) f) => visible
                      .where((c) => f(c) && !c.muted && c.unread > 0)
                      .length;
                  final chips = <(String, String, int)>[
                    ('all', l.sectAll, unread((_) => true)),
                    if (settings.homeSections) ...[
                      ('unread', l.sectUnread, 0),
                      (
                        'people',
                        l.sectPeople,
                        unread(
                          (c) =>
                              c.type == ChatType.private ||
                              c.type == ChatType.secret,
                        ),
                      ),
                      (
                        'groups',
                        l.sectGroups,
                        unread((c) => c.type == ChatType.group),
                      ),
                      (
                        'channels',
                        l.sectChannels,
                        unread((c) => c.type == ChatType.channel),
                      ),
                    ],
                    for (final e in settings.folders.entries)
                      (
                        'f:${e.key}',
                        e.key,
                        unread((c) => e.value.contains(c.id)),
                      ),
                  ];
                  return SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final (id, label, n) in chips)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: GestureDetector(
                              onLongPress: id.startsWith('f:')
                                  ? () => _folderMenu(id.substring(2))
                                  : null,
                              child: ChoiceChip(
                                label: Text(n > 0 ? '$label  $n' : label),
                                selected: _section == id,
                                onSelected: (_) =>
                                    setState(() => _section = id),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: ActionChip(
                            avatar: const SIcon(Icons.add, size: 16),
                            label: Text(l.newSection),
                            onPressed: () async {
                              final n = await askText(
                                context,
                                l.newSection,
                                l.sectionName,
                              );
                              if (n != null && n.trim().isNotEmpty) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .addFolder(n.trim());
                                setState(() => _section = 'f:${n.trim()}');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            Expanded(
              child: chats.when(
                loading: () => Center(child: Text(l.connecting)),
                error: (e, _) => Center(child: Text(l.errorGeneric)),
                data: (all) {
                  final q = _query.trim().toLowerCase();
                  final shown =
                      all.where((c) {
                          final hidden = settings.hiddenChats.contains(c.id);
                          if (hidden) return false; // hidden chats live on their own screen
                          if (!_inSection(c, settings)) return false;
                          final name = (settings.aliases[c.id] ?? c.title)
                              .toLowerCase();
                          return q.isEmpty || name.contains(q);
                        }).toList()
                        // Pinned chats first; the rest keep Telegram's order.
                        ..sort((a, b) {
                          final pa = settings.pinned.contains(a.id) ? 0 : 1;
                          final pb = settings.pinned.contains(b.id) ? 0 : 1;
                          return pa.compareTo(pb);
                        });
                  final hits = q.isEmpty
                      ? const <SearchHit>[]
                      : ref
                            .read(archiveProvider)
                            .search(q)
                            .where(
                              (h) => !settings.hiddenChats.contains(
                                h.message.chatId,
                              ),
                            )
                            .toList();
                  if (shown.isEmpty && hits.isEmpty && q.isEmpty) {
                    return Center(child: Text(l.noChats));
                  }
                  final byId = {for (final c in all) c.id: c};
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      if (q.isEmpty && _section == 'all')
                        ref
                            .watch(archivedProvider)
                            .maybeWhen(
                              data: (a) => a.isEmpty
                                  ? const SizedBox.shrink()
                                  : ListTile(
                                      leading: const SIcon(
                                        Icons.archive_outlined,
                                      ),
                                      title: Text(l.archive),
                                      trailing: Text('${a.length}'),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const ArchiveScreen(),
                                        ),
                                      ),
                                    ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                      for (final c in shown)
                        ChatRow(
                          chat: c,
                          hidden: settings.hiddenChats.contains(c.id),
                          pinned: settings.pinned.contains(c.id),
                          alias: settings.aliases[c.id],
                        ),
                      if (q.length >= 2)
                        _GlobalHits(
                          query: q,
                          chats: {for (final c in all) c.id: c},
                        ),
                      if (hits.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                          child: Text(
                            l.archiveResults,
                            style: const TextStyle(
                              color: GlassTokens.textSecondary,
                            ),
                          ),
                        ),
                        for (final h in hits)
                          if (byId[h.message.chatId] != null)
                            _HitRow(hit: h, chat: byId[h.message.chatId]!),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatRow extends ConsumerWidget {
  const ChatRow({
    super.key,
    required this.chat,
    required this.hidden,
    required this.pinned,
    this.alias,
    this.showPreview = true,
    this.inHidden = false,
  });

  final bool showPreview;
  final bool inHidden;
  final ChatSummary chat;
  final bool hidden;
  final bool pinned;
  final String? alias;

  Color? get _ring => switch (chat.risk) {
    RiskLevel.safe => GlassTokens.ringSafe,
    RiskLevel.caution => GlassTokens.ringCaution,
    RiskLevel.danger => GlassTokens.ringDanger,
    RiskLevel.none => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<int>(
      valueListenable: DraftStore.changes,
      builder: (context, _, _) => _build(context, ref),
    );
  }

  IconData _swipeIcon(String a) => switch (a) {
    'pin' => pinned ? Icons.push_pin_outlined : Icons.push_pin,
    'archive' => Icons.archive_outlined,
    'mute' => chat.muted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
    'read' => Icons.mark_chat_read_outlined,
    'hide' => Icons.lock_outline,
    _ => Icons.block,
  };

  Widget _build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final st = ref.watch(settingsProvider);
    final mode = st.rowMode;
    final draft = DraftStore.get(chat.id);
    final preview = !showPreview
        ? '•••'
        : draft.isNotEmpty
        ? '${l.draft}: $draft'
        : (chat.lastText.isNotEmpty
              ? chat.lastText
              : kindLabel(l, chat.lastKind));
    final accent = GlassScope.of(context).accent;
    Widget swipeBg(IconData i, AlignmentGeometry al, Color c) => Container(
      alignment: al,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SIcon(i),
    );
    return Dismissible(
      key: ValueKey('row_${chat.id}_$inHidden'),
      background: st.homeSwipeRight == 'none'
          ? null
          : swipeBg(
              _swipeIcon(st.homeSwipeRight),
              AlignmentDirectional.centerStart,
              accent,
            ),
      secondaryBackground: st.homeSwipeLeft == 'none'
          ? null
          : swipeBg(
              _swipeIcon(st.homeSwipeLeft),
              AlignmentDirectional.centerEnd,
              GlassTokens.ringCaution,
            ),
      direction: st.homeSwipeRight == 'none' && st.homeSwipeLeft == 'none'
          ? DismissDirection.none
          : st.homeSwipeRight == 'none'
          ? DismissDirection.endToStart
          : st.homeSwipeLeft == 'none'
          ? DismissDirection.startToEnd
          : DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        final act = dir == DismissDirection.startToEnd
            ? st.homeSwipeRight
            : st.homeSwipeLeft;
        final gw = ref.read(gatewayProvider);
        final cfg = ref.read(settingsProvider.notifier);
        switch (act) {
          case 'pin':
            cfg.togglePin(chat.id);
          case 'archive':
            if (!inHidden) gw.setArchived(chat.id, true);
          case 'mute':
            gw.setMuted(chat.id, !chat.muted);
          case 'read':
            gw.markUnread(chat.id, chat.unread == 0 && !chat.markedUnread);
          case 'hide':
            cfg.setHidden(chat.id, !hidden);
          default:
        }
        return false; // the list rebuilds itself from state
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: chat)),
          ),
          onLongPress: () =>
              showChatActions(context, ref, chat, inHidden: inHidden),
          child: GlassSurface(
            radius: 20,
            padding: EdgeInsets.all(mode == 'compact' ? 8 : 12),
            child: Row(
              children: [
                if (st.avatarShape != 'hidden') ...[
                  AvatarCircle(
                    title: chat.title,
                    photo: chat.avatar,
                    chatId: chat.id,
                    ring: _ring,
                    shape: st.avatarShape,
                    size: mode == 'compact'
                        ? st.avatarSize * .8
                        : st.avatarSize,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              alias ?? chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (chat.type == ChatType.secret)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: SIcon(
                                Icons.lock,
                                size: 13,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                          if (chat.type == ChatType.group)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: SIcon(
                                Icons.group_outlined,
                                size: 14,
                                color: GlassTokens.textSecondary,
                              ),
                            ),
                          if (chat.type == ChatType.channel)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: SIcon(
                                Icons.campaign_outlined,
                                size: 14,
                                color: GlassTokens.textSecondary,
                              ),
                            ),
                          if (chat.muted)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: SIcon(
                                Icons.volume_off,
                                size: 13,
                                color: GlassTokens.textSecondary,
                              ),
                            ),
                          if (pinned)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: SIcon(
                                Icons.push_pin,
                                size: 13,
                                color: GlassTokens.textSecondary,
                              ),
                            ),
                          if (hidden)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: SIcon(
                                Icons.lock_outline,
                                size: 14,
                                color: GlassTokens.ghost,
                              ),
                            ),
                        ],
                      ),
                      if (mode != 'nameOnly') const SizedBox(height: 2),
                      if (mode != 'nameOnly')
                        Text(
                          preview,
                          maxLines: mode == 'compact' ? 1 : st.homeLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: draft.isNotEmpty
                                ? GlassTokens.ringDanger
                                : GlassTokens.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (chat.lastTime != null && st.homeShowTime)
                      Text(
                        _fmtTime(chat.lastTime!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: GlassTokens.textTertiary,
                        ),
                      ),
                    if (chat.unread == 0 && chat.markedUnread)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: GlassScope.of(context).accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (chat.unread > 0 && st.homeShowUnreadBadge)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: GlassScope.of(context).accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${chat.unread}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit, required this.chat});

  final SearchHit hit;
  final ChatSummary chat;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: chat))),
        child: GlassSurface(
          radius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chat.title,
                style: const TextStyle(
                  fontSize: 13,
                  color: GlassTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hit.message.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (hit.deleted)
                Text(
                  l.deletedBadge,
                  style: const TextStyle(
                    fontSize: 11,
                    color: GlassTokens.ringDanger,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Server-side search results ("Telegram results") for the home search box.
class _GlobalHits extends ConsumerStatefulWidget {
  const _GlobalHits({required this.query, required this.chats});
  final String query;
  final Map<int, ChatSummary> chats;

  @override
  ConsumerState<_GlobalHits> createState() => _GlobalHitsState();
}

class _GlobalHitsState extends ConsumerState<_GlobalHits> {
  Future<List<ChatMessage>>? _f;
  String _for = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hidden = ref.watch(settingsProvider).hiddenChats;
    if (_for != widget.query) {
      _for = widget.query;
      _f = Future<void>.delayed(const Duration(milliseconds: 500)).then(
        (_) => _for == widget.query
            ? ref.read(gatewayProvider).searchGlobal(widget.query)
            : <ChatMessage>[],
      );
    }
    return FutureBuilder<List<ChatMessage>>(
      future: _f,
      builder: (_, snap) {
        final list = [
          for (final m in snap.data ?? const <ChatMessage>[])
            if (!hidden.contains(m.chatId) && widget.chats[m.chatId] != null) m,
        ];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
              child: Text(
                l.telegramResults,
                style: const TextStyle(color: GlassTokens.textSecondary),
              ),
            ),
            for (final m in list)
              ListTile(
                dense: true,
                title: Text(widget.chats[m.chatId]!.title),
                subtitle: Text(
                  m.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(chat: widget.chats[m.chatId]!),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
