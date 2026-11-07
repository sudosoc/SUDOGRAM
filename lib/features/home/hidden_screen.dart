import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/icon_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/i18n/tr.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import 'chat_actions.dart';
import 'hidden_gate.dart';
import 'home_screen.dart';

/// All hidden chats in one place ("Telegram inside Telegram"): sections for
/// people / groups / channels plus the user's own sections.
/// Closes itself whenever the vault locks (app leaves the foreground).
class HiddenChatsScreen extends ConsumerStatefulWidget {
  const HiddenChatsScreen({super.key});

  @override
  ConsumerState<HiddenChatsScreen> createState() => _HiddenChatsScreenState();
}

class _HiddenChatsScreenState extends ConsumerState<HiddenChatsScreen> {
  String _section = 'all';
  bool _searching = false;
  String _q = '';
  late final _area = ref.read(hiddenAreaProvider.notifier);
  late final _vault = ref.read(vaultUnlockProvider.notifier);
  late final bool _lockOnExit = ref.read(settingsProvider).hiddenLockOnExit;

  @override
  void initState() {
    super.initState();
    Future.microtask(_area.enter);
  }

  @override
  void dispose() {
    // Closing the hidden area locks it again (asks for auth next time).
    Future.microtask(() {
      _area.leave();
      if (_lockOnExit) _vault.lock();
    });
    super.dispose();
  }

  bool _inSection(ChatSummary c, AppSettings s) {
    if (_section == 'all') return true;
    if (_section.startsWith('f:')) {
      return s.hiddenFolders[_section.substring(2)]?.contains(c.id) ?? false;
    }
    return switch (_section) {
      'people' => c.type == ChatType.private,
      'groups' => c.type == ChatType.group,
      'channels' => c.type == ChatType.channel,
      'secret' => c.type == ChatType.secret,
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
        c.renameHiddenFolder(name, n.trim());
        if (_section == 'f:$name') setState(() => _section = 'f:${n.trim()}');
      }
    } else {
      if (await confirmDialog(context, l.deleteSectionQ)) {
        c.deleteHiddenFolder(name);
        if (_section == 'f:$name') setState(() => _section = 'all');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final all = ref.watch(chatsProvider).value ?? const <ChatSummary>[];
    final hiddenAll = [
      for (final ch in all)
        if (settings.hiddenChats.contains(ch.id)) ch,
    ];
    final q = _q.trim().toLowerCase();
    final shown =
        [
          for (final ch in hiddenAll)
            if (_inSection(ch, settings) &&
                (q.isEmpty ||
                    (settings.aliases[ch.id] ?? ch.title)
                        .toLowerCase()
                        .contains(q)))
              ch,
        ]..sort((a, b) {
          final pa = settings.pinned.contains(a.id) ? 0 : 1;
          final pb = settings.pinned.contains(b.id) ? 0 : 1;
          return pa.compareTo(pb);
        });

    final chips = <(String, String, int)>[
      ('all', l.sectAll, hiddenAll.length),
      if (settings.hiddenSections) ...[
        (
          'people',
          l.sectPeople,
          hiddenAll.where((x) => x.type == ChatType.private).length,
        ),
        (
          'groups',
          l.sectGroups,
          hiddenAll.where((x) => x.type == ChatType.group).length,
        ),
        (
          'channels',
          l.sectChannels,
          hiddenAll.where((x) => x.type == ChatType.channel).length,
        ),
        if (hiddenAll.any((x) => x.type == ChatType.secret))
          (
            'secret',
            l.sectSecret,
            hiddenAll.where((x) => x.type == ChatType.secret).length,
          ),
      ],
      for (final e in settings.hiddenFolders.entries)
        (
          'f:${e.key}',
          e.key,
          e.value.where(settings.hiddenChats.contains).length,
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(hintText: l.searchHint),
                onChanged: (v) => setState(() => _q = v),
              )
            : Row(
                children: [
                  const SIcon(
                    Icons.lock_outline,
                    size: 18,
                    color: GlassTokens.ghost,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ref.watch(settingsProvider).hiddenTitle.isEmpty
                        ? l.hiddenChatsTitle
                        : ref.watch(settingsProvider).hiddenTitle,
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: SIcon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _q = '';
            }),
          ),
          IconButton(
            tooltip: l.lockNow,
            icon: const SIcon(Icons.lock_clock_outlined),
            onPressed: () => ref.read(vaultUnlockProvider.notifier).lock(),
          ),
          IconButton(
            tooltip: l.hiddenSettings,
            icon: const SIcon(Icons.settings_outlined),
            onPressed: () => openHiddenSettings(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
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
                        label: Text('$label  $n'),
                        selected: _section == id,
                        onSelected: (_) => setState(() => _section = id),
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
                        c.addHiddenFolder(n.trim());
                        setState(() => _section = 'f:${n.trim()}');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _section.startsWith('f:')
                            ? l.sectionEmpty
                            : l.noHiddenChats,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      for (final ch in shown)
                        ChatRow(
                          chat: ch,
                          hidden: true,
                          inHidden: true,
                          pinned: settings.pinned.contains(ch.id),
                          alias: settings.aliases[ch.id],
                          showPreview: settings.hiddenPreview,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Settings of the hidden-chats area.
class HiddenSettingsScreen extends ConsumerWidget {
  const HiddenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final methods = s.hiddenMethods;

    Widget method(String id, IconData icon, String title, {String? sub}) =>
        SwitchListTile(
          secondary: SIcon(icon),
          title: Text(title),
          subtitle: sub == null ? null : Text(sub),
          value: methods.contains(id),
          onChanged: (v) {
            if (!v && methods.length == 1) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l.lastMethodWarn)));
              return;
            }
            if (v && id == 'code' && s.hiddenCode.isEmpty) {
              _askCode(context, ref, enableAfter: true);
              return;
            }
            c.toggleHiddenMethod(id);
          },
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l.hiddenSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          _H(l.hiddenOpenMethods),
          GlassSurface(
            radius: 20,
            child: Column(
              children: [
                method('search', Icons.search, l.mSearch),
                method('title', Icons.touch_app_outlined, l.mTitle),
                method('ghost', Icons.visibility_off_outlined, l.mGhost),
                method('settings', Icons.tune, l.mSettings),
                method('fab', Icons.edit_outlined, l.mFab),
                method('swipe', Icons.swipe, l.mSwipe, sub: l.mSwipeHint),
                method(
                  'code',
                  Icons.password,
                  l.mCode,
                  sub: s.hiddenCode.isEmpty ? null : '•' * s.hiddenCode.length,
                ),
                if (methods.contains('code'))
                  ListTile(
                    leading: const SIcon(Icons.edit_outlined),
                    title: Text(l.hiddenCodeChange),
                    onTap: () => _askCode(context, ref),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _H(l.hiddenSecurity),
          GlassSurface(
            radius: 20,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const SIcon(Icons.fingerprint),
                  title: Text(l.hiddenRequireAuth),
                  value: s.hiddenAuth,
                  onChanged: (v) {
                    if (!v && !s.hasHiddenPin) {
                      // never leave the hidden chats without any protection by accident
                      c.setX('hiddenAuth', false);
                      return;
                    }
                    c.setX('hiddenAuth', v);
                  },
                ),
                ListTile(
                  leading: const SIcon(Icons.pin_outlined),
                  title: Text(l.hiddenPin),
                  subtitle: Text(
                    s.hasHiddenPin
                        ? (s.hiddenPinKind == 'text'
                              ? l.pinKindWord
                              : l.pinKindDigits(s.hiddenPinKind))
                        : l.pinOff,
                  ),
                  trailing: s.hasHiddenPin
                      ? IconButton(
                          icon: const SIcon(Icons.delete_outline),
                          onPressed: () {
                            c.setX('hiddenPinHash', null);
                            c.setX('hiddenPinSalt', null);
                          },
                        )
                      : null,
                  onTap: () => _setPin(context, ref),
                ),
                SwitchListTile(
                  secondary: const SIcon(Icons.lock_clock_outlined),
                  title: Text(l.hiddenLockExit),
                  subtitle: Text(l.hiddenLockExitHint),
                  value: s.hiddenLockOnExit,
                  onChanged: (v) => c.setX('hiddenLockOnExit', v),
                ),
                SwitchListTile(
                  secondary: const SIcon(Icons.subject),
                  title: Text(l.hiddenShowPreview),
                  value: s.hiddenPreview,
                  onChanged: (v) => c.setX('hiddenPreview', v),
                ),
                SwitchListTile(
                  secondary: const SIcon(Icons.dashboard_customize_outlined),
                  title: Text(l.hiddenSectionsT),
                  value: s.hiddenSections,
                  onChanged: (v) => c.setX('hiddenSections', v),
                ),
                SwitchListTile(
                  secondary: const SIcon(Icons.screenshot_monitor),
                  title: Text(
                    context.t(
                      'Block screenshots inside',
                      'منع لقطات الشاشة جوه',
                    ),
                  ),
                  subtitle: Text(
                    context.t(
                      'Also hides the hidden chats from the recent-apps preview.',
                      'وبيخفيها من معاينة التطبيقات الأخيرة كمان.',
                    ),
                  ),
                  value: s.hiddenSecure,
                  onChanged: (v) => c.setX('hiddenSecure', v),
                ),
                ListTile(
                  leading: const SIcon(Icons.badge_outlined),
                  title: Text(context.t('Custom title', 'عنوان مخصص')),
                  subtitle: Text(
                    s.hiddenTitle.isEmpty
                        ? context.t('Default', 'الافتراضي')
                        : s.hiddenTitle,
                  ),
                  onTap: () async {
                    final t = await askText(
                      context,
                      context.t(
                        'Title of the hidden area',
                        'عنوان المنطقة المخفية',
                      ),
                      '',
                      initial: s.hiddenTitle,
                    );
                    if (t != null) {
                      c.setX('hiddenTitle', t.trim().isEmpty ? null : t.trim());
                    }
                  },
                ),
                SwitchListTile(
                  secondary: const SIcon(Icons.visibility_off_outlined),
                  title: Text(l.ghostForceHidden),
                  subtitle: Text(l.ghostForceHint),
                  value: s.ghostForceHidden,
                  onChanged: (v) => c.setX('ghostForceHidden', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _H(l.hiddenNotifyT),
          GlassSurface(
            radius: 20,
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text(l.notifyGeneric)),
                ButtonSegment(value: 1, label: Text(l.notifyNone)),
              ],
              selected: {s.hiddenNotify},
              onSelectionChanged: (v) => c.setX('hiddenNotify', v.first),
            ),
          ),
          const SizedBox(height: 12),
          GlassSurface(
            radius: 20,
            child: ListTile(
              leading: const SIcon(
                Icons.lock_open,
                color: GlassTokens.ringDanger,
              ),
              title: Text(
                l.unhideAll,
                style: const TextStyle(color: GlassTokens.ringDanger),
              ),
              onTap: () async {
                if (s.hiddenChats.isEmpty) return;
                if (await confirmDialog(context, l.unhideAllQ)) {
                  for (final id in s.hiddenChats.toList()) {
                    c.setHidden(id, false);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final c = ref.read(settingsProvider.notifier);
    var kind = ref.read(settingsProvider).hiddenPinKind;
    final a = TextEditingController();
    final b = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setS) {
          final digits = kind != 'text';
          final len = int.tryParse(kind) ?? 0;
          return AlertDialog(
            title: Text(l.hiddenPin),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final k in const ['4', '6', '8', '10', 'text'])
                        ChoiceChip(
                          label: Text(k == 'text' ? l.pinKindWord : k),
                          selected: kind == k,
                          onSelected: (_) => setS(() {
                            kind = k;
                            a.clear();
                            b.clear();
                            err = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: a,
                    obscureText: true,
                    keyboardType: digits
                        ? TextInputType.number
                        : TextInputType.text,
                    inputFormatters: digits
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(len),
                          ]
                        : null,
                    decoration: InputDecoration(hintText: l.gateEnterCode),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: b,
                    obscureText: true,
                    keyboardType: digits
                        ? TextInputType.number
                        : TextInputType.text,
                    inputFormatters: digits
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(len),
                          ]
                        : null,
                    decoration: InputDecoration(hintText: l.pinConfirm),
                  ),
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        err!,
                        style: const TextStyle(color: GlassTokens.ringDanger),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: Text(l.cancelAction),
              ),
              TextButton(
                onPressed: () {
                  final v = a.text;
                  if (digits ? v.length != len : v.length < 4) {
                    setS(
                      () =>
                          err = digits ? l.pinLenErr('$len') : l.hiddenCodeHint,
                    );
                    return;
                  }
                  if (v != b.text) {
                    setS(() => err = l.pinMismatch);
                    return;
                  }
                  Navigator.pop(dctx, true);
                },
                child: Text(l.vaultSave),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) {
      final salt = newSalt();
      c.setX('hiddenPinSalt', salt);
      c.setX('hiddenPinKind', kind);
      c.setX('hiddenPinHash', hashPin(salt, a.text));
    }
  }

  Future<void> _askCode(
    BuildContext context,
    WidgetRef ref, {
    bool enableAfter = false,
  }) async {
    final l = AppLocalizations.of(context);
    final c = ref.read(settingsProvider.notifier);
    final v = await askText(
      context,
      l.mCode,
      l.hiddenCodeHint,
      initial: ref.read(settingsProvider).hiddenCode,
    );
    if (v == null || v.trim().length < 3) return;
    c.setX('hiddenCode', v.trim());
    if (enableAfter &&
        !ref.read(settingsProvider).hiddenMethods.contains('code')) {
      c.toggleHiddenMethod('code');
    }
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
    child: Text(
      text,
      style: const TextStyle(
        color: GlassTokens.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
