import 'package:flutter/material.dart';
import '../home/hidden_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ui/icon_styles.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import 'account_screens.dart';
import 'applock_screen.dart';
import 'devices_screen.dart';
import 'ghost_screen.dart';
import 'widgets.dart';

class PrivacyItem {
  const PrivacyItem(this.key, this.icon, this.en, this.ar, this.hintEn, this.hintAr);
  final String key;
  final IconData icon;
  final String en;
  final String ar;
  final String hintEn;
  final String hintAr;
}

const _see = <PrivacyItem>[
  PrivacyItem('phone', Icons.phone_outlined, 'Phone number', 'رقم الهاتف',
      'Who sees your number on your profile.', 'مين يشوف رقمك في بروفايلك.'),
  PrivacyItem('find', Icons.person_search_outlined, 'Who can find me by number',
      'مين يلاقيني بالرقم', 'People who have your number saved can find you.',
      'الناس اللي معاهم رقمك يقدروا يلاقوك.'),
  PrivacyItem('seen', Icons.access_time, 'Last seen & online', 'آخر ظهور والاتصال',
      'If you hide it, you will not see others\' last seen either.',
      'لو خبّيته مش هتشوف آخر ظهور حد.'),
  PrivacyItem('photo', Icons.account_circle_outlined, 'Profile photos', 'صور البروفايل',
      'Who can see your profile photo.', 'مين يشوف صورة بروفايلك.'),
  PrivacyItem('bio', Icons.info_outline, 'Bio', 'النبذة', 'Who can read your bio.',
      'مين يقرا النبذة بتاعتك.'),
  PrivacyItem('birthday', Icons.cake_outlined, 'Birthday', 'تاريخ الميلاد',
      'Who can see your birthday.', 'مين يشوف تاريخ ميلادك.'),
  PrivacyItem('forwards', Icons.forward_outlined, 'Forwarded messages',
      'الرسائل المحوّلة', 'Whether a link to your account shows on forwards.',
      'هل يظهر لينك حسابك لما رسائلك تتحول.'),
];

const _can = <PrivacyItem>[
  PrivacyItem('calls', Icons.call_outlined, 'Calls', 'المكالمات',
      'Who can call you.', 'مين يقدر يكلمك.'),
  PrivacyItem('p2p', Icons.swap_calls, 'Peer-to-peer in calls', 'اتصال مباشر في المكالمات',
      'Direct connection is faster but can reveal your IP.',
      'الاتصال المباشر أسرع بس ممكن يكشف الـ IP.'),
  PrivacyItem('invites', Icons.group_add_outlined, 'Groups & channels', 'الجروبات والقنوات',
      'Who can add you to groups and channels.', 'مين يضيفك للجروبات والقنوات.'),
  PrivacyItem('voice', Icons.mic_none, 'Voice & video messages', 'الرسائل الصوتية والمرئية',
      'Who can send you voice and round-video messages (Premium feature on Telegram).',
      'مين يبعتلك رسائل صوتية/فيديو (ميزة Premium في تليجرام).'),
];

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  void _go(BuildContext c, Widget w) =>
      Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => w));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return SPage(title: context.t('Privacy & Security', 'الخصوصية والأمان'), children: [
      SGroup(title: context.t('Who can see my…', 'مين يشوف…'), children: [
        for (final i in _see) _RuleTile(item: i),
      ]),
      SGroup(title: context.t('Who can…', 'مين يقدر…'), children: [
        for (final i in _can) _RuleTile(item: i),
      ]),
      SGroup(title: context.t('Security', 'الأمان'), children: [
        ListTile(
          leading: const SIcon(Icons.lock_outline),
          title: Text(context.t('App passcode & lock', 'باسكود وقفل التطبيق')),
          subtitle: Text(context.t('Fingerprint, passcode, auto-lock.',
              'بصمة، باسكود، قفل تلقائي.')),
          trailing: Text(s.appLock ? context.t('On', 'شغال') : context.t('Off', 'مقفول')),
          onTap: () => _go(context, const AppLockScreen()),
        ),
        ListTile(
          leading: const SIcon(Icons.password),
          title: Text(context.t('Two-step verification', 'التحقق بخطوتين')),
          subtitle: Text(context.t('An extra password when signing in on a new device.',
              'باسورد إضافي لما تسجل دخول من جهاز جديد.')),
          onTap: () => _go(context, const TwoStepScreen()),
        ),
        ListTile(
          leading: const SIcon(Icons.devices_other),
          title: Text(context.t('Active sessions', 'الجلسات النشطة')),
          subtitle: Text(context.t('See and end sessions on other devices.',
              'شوف وأنهي الجلسات على الأجهزة التانية.')),
          onTap: () => _go(context, const DevicesScreen()),
        ),
        ListTile(
          leading: const SIcon(Icons.block),
          title: Text(context.t('Blocked users', 'المحظورين')),
          subtitle: Text(context.t('People who cannot message or call you.',
              'ناس مايقدروش يراسلوك أو يكلموك.')),
          onTap: () => _go(context, const BlockedScreen()),
        ),
      ]),
      SGroup(title: context.t('Messages & account', 'الرسائل والحساب'), children: const [
        _AutoDeleteTile(),
        _TtlTile(),
        _ArchiveTile(),
      ]),
      SGroup(title: context.t('On this phone', 'على هذا الهاتف'), children: [
        SwitchRow(
          icon: Icons.screenshot_monitor,
          title: context.t('Block screenshots everywhere', 'منع لقطات الشاشة في كل التطبيق'),
          subtitle: context.t('Also hides the app in the recent-apps screen.',
              'وبيخفي التطبيق من شاشة التطبيقات الأخيرة.'),
          keyName: 'lockBlockScreenshots',
          value: s.lockBlockScreenshots,
        ),
        SwitchListTile(
          secondary: const SIcon(Icons.notifications_off_outlined),
          title: Text(context.t('Hide message text in notifications', 'إخفاء نص الرسائل في الإشعارات')),
          subtitle: Text(context.t('Notifications only say you got a message.',
              'الإشعارات بتقول جاتلك رسالة بس.')),
          value: s.notifContent == 'generic',
          onChanged: (v) => ref
              .read(settingsProvider.notifier)
              .setX('notifContent', v ? 'generic' : 'full'),
        ),
        ListTile(
          leading: const SIcon(Icons.visibility_off_outlined),
          title: const Text('Ghost'),
          subtitle: Text(context.t('Hide read receipts, typing and online status.',
              'إخفاء القراءة والكتابة والاتصال.')),
          onTap: () => _go(context, const GhostScreen()),
        ),
        if (showHiddenSettingsEntry(ref))
          ListTile(
            leading: const SIcon(Icons.lock_person_outlined),
            title: Text(context.t('Hidden chats', 'الشاتات المخفية')),
            subtitle: Text(context.t('Open methods, sections, lock options.',
                'طرق الفتح، الأقسام، خيارات القفل.')),
            onTap: () => openHiddenSettings(context, ref),
          ),
      ]),
    ]);
  }
}

String _baseLabel(BuildContext c, String b) => switch (b) {
      'contacts' => c.t('My contacts', 'جهات اتصالي'),
      'nobody' => c.t('Nobody', 'محدش'),
      _ => c.t('Everybody', 'الكل'),
    };

String _summary(BuildContext c, PrivacyRule r) {
  final x = <String>[];
  if (r.allow.isNotEmpty) x.add('+${r.allow.length}');
  if (r.deny.isNotEmpty) x.add('−${r.deny.length}');
  return '${_baseLabel(c, r.base)}${x.isEmpty ? '' : ' (${x.join(' ')})'}';
}

class _RuleTile extends ConsumerStatefulWidget {
  const _RuleTile({required this.item});
  final PrivacyItem item;

  @override
  ConsumerState<_RuleTile> createState() => _RuleTileState();
}

class _RuleTileState extends ConsumerState<_RuleTile> {
  PrivacyRule? _rule;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(gatewayProvider).getPrivacyRule(widget.item.key);
      if (mounted) setState(() => _rule = r);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return ListTile(
      leading: SIcon(i.icon),
      title: Text(context.t(i.en, i.ar)),
      subtitle: Text(context.t(i.hintEn, i.hintAr),
          style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary)),
      trailing: _failed
          ? const SIcon(Icons.error_outline, color: GlassTokens.ringCaution)
          : _rule == null
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_summary(context, _rule!),
                  style: TextStyle(color: GlassScope.of(context).accent)),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => PrivacyRuleScreen(item: i, initial: _rule)));
        _load();
      },
    );
  }
}

class PrivacyRuleScreen extends ConsumerStatefulWidget {
  const PrivacyRuleScreen({super.key, required this.item, this.initial});
  final PrivacyItem item;
  final PrivacyRule? initial;

  @override
  ConsumerState<PrivacyRuleScreen> createState() => _PrivacyRuleScreenState();
}

class _PrivacyRuleScreenState extends ConsumerState<PrivacyRuleScreen> {
  late PrivacyRule _orig = widget.initial ?? const PrivacyRule('everybody');
  late String _base = _orig.base;
  late List<int> _allow = [..._orig.allow];
  late List<int> _deny = [..._orig.deny];
  List<ChatSummary> _contacts = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(gatewayProvider).contacts().then((c) {
      if (mounted) setState(() => _contacts = c);
    });
    if (widget.initial == null) {
      ref.read(gatewayProvider).getPrivacyRule(widget.item.key).then((r) {
        if (!mounted) return;
        setState(() {
          _orig = r;
          _base = r.base;
          _allow = [...r.allow];
          _deny = [...r.deny];
        });
      }).catchError((Object _) {});
    }
  }

  bool get _dirty =>
      _base != _orig.base ||
      !_same(_allow, _orig.allow) ||
      !_same(_deny, _orig.deny);

  bool _same(List<int> a, List<int> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  String _name(int id) {
    for (final c in _contacts) {
      if (c.id == id) return c.title;
    }
    return '$id';
  }

  Future<void> _pick(bool allow) async {
    final cur = (allow ? _allow : _deny).toSet();
    final other = (allow ? _deny : _allow).toSet();
    final res = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (sc) {
        final sel = {...cur};
        var q = '';
        return StatefulBuilder(builder: (sc, setS) {
          final shown = [
            for (final c in _contacts)
              if (c.id > 0 &&
                  (q.isEmpty || c.title.toLowerCase().contains(q.toLowerCase())))
                c
          ];
          return SizedBox(
            height: MediaQuery.of(sc).size.height * .8,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                          prefixIcon: const SIcon(Icons.search),
                          hintText: sc.t('Search contacts', 'ابحث في جهات الاتصال')),
                      onChanged: (v) => setS(() => q = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                      onPressed: () => Navigator.pop(sc, sel),
                      child: Text(sc.t('Done', 'تم'))),
                ]),
              ),
              Expanded(
                child: ListView(children: [
                  for (final c in shown)
                    CheckboxListTile(
                      value: sel.contains(c.id),
                      title: Text(c.title),
                      subtitle: other.contains(c.id)
                          ? Text(
                              allow
                                  ? sc.t('Currently in "never" — will move',
                                      'حاليًا في "أبدًا" — هيتنقل')
                                  : sc.t('Currently in "always" — will move',
                                      'حاليًا في "دايمًا" — هيتنقل'),
                              style: const TextStyle(fontSize: 11))
                          : null,
                      onChanged: (v) =>
                          setS(() => v == true ? sel.add(c.id) : sel.remove(c.id)),
                    ),
                ]),
              ),
            ]),
          );
        });
      },
    );
    if (res == null) return;
    setState(() {
      if (allow) {
        _allow = res.toList();
        _deny.removeWhere(res.contains);
      } else {
        _deny = res.toList();
        _allow.removeWhere(res.contains);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = context.t('Saved', 'اتحفظ');
    final fail = context.t('Telegram refused this change', 'تليجرام رفض التعديل');
    try {
      await ref
          .read(gatewayProvider)
          .setPrivacyRule(widget.item.key, PrivacyRule(_base, allow: _allow, deny: _deny));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$fail: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
          backgroundColor: Colors.transparent, title: Text(context.t(i.en, i.ar))),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 32), children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(context.t(i.hintEn, i.hintAr),
              style: const TextStyle(color: GlassTokens.textSecondary)),
        ),
        SGroup(children: [
          RadioGroup<String>(
            groupValue: _base,
            onChanged: (v) => setState(() => _base = v ?? _base),
            child: Column(children: [
              for (final b in const ['everybody', 'contacts', 'nobody'])
                RadioListTile<String>(
                    value: b, title: Text(_baseLabel(context, b))),
            ]),
          ),
        ]),
        SGroup(title: context.t('Exceptions', 'استثناءات'), children: [
          if (_base != 'everybody')
            ListTile(
              leading: const SIcon(Icons.person_add_alt),
              title: Text(context.t('Always allow', 'اسمح دايمًا')),
              subtitle: Text(_allow.isEmpty
                  ? context.t('Add users', 'أضف أشخاص')
                  : _allow.map(_name).join('، ')),
              trailing: Text('${_allow.length}'),
              onTap: () => _pick(true),
            ),
          if (_base != 'nobody')
            ListTile(
              leading: const SIcon(Icons.person_off_outlined),
              title: Text(context.t('Never allow', 'ماتسمحش أبدًا')),
              subtitle: Text(_deny.isEmpty
                  ? context.t('Add users', 'أضف أشخاص')
                  : _deny.map(_name).join('، ')),
              trailing: Text('${_deny.length}'),
              onTap: () => _pick(false),
            ),
        ]),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _dirty
              ? FilledButton(
                  key: const ValueKey('s'),
                  onPressed: _busy ? null : _save,
                  child: Text(context.t('Save changes', 'حفظ التغييرات')))
              : const SizedBox.shrink(key: ValueKey('n')),
        ),
      ]),
    );
  }
}

class _AutoDeleteTile extends ConsumerStatefulWidget {
  const _AutoDeleteTile();
  @override
  ConsumerState<_AutoDeleteTile> createState() => _AutoDeleteTileState();
}

class _AutoDeleteTileState extends ConsumerState<_AutoDeleteTile> {
  int? _v;

  @override
  void initState() {
    super.initState();
    ref
        .read(gatewayProvider)
        .autoDeleteSeconds()
        .then((v) => mounted ? setState(() => _v = v) : null)
        .catchError((Object _) {});
  }

  String _label(BuildContext c, int s) => switch (s) {
        0 => c.t('Off', 'مقفول'),
        86400 => c.t('1 day', 'يوم'),
        604800 => c.t('1 week', 'أسبوع'),
        2678400 => c.t('1 month', 'شهر'),
        _ => c.t('$s s', '$s ث'),
      };

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const SIcon(Icons.auto_delete_outlined),
        title: Text(context.t('Auto-delete messages', 'حذف الرسائل تلقائيًا')),
        subtitle: Text(context.t(
            'Default timer for new chats. Messages vanish after this time.',
            'مؤقت افتراضي للشاتات الجديدة. الرسائل بتختفي بعد المدة دي.'),
            style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary)),
        trailing: Text(_v == null ? '…' : _label(context, _v!)),
        onTap: () async {
          final opts = const [0, 86400, 604800, 2678400];
          final v = await showDialog<int>(
            context: context,
            builder: (dc) => SimpleDialog(
              title: Text(context.t('Auto-delete', 'الحذف التلقائي')),
              children: [
                for (final o in opts)
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(dc, o),
                      child: Text(_label(context, o))),
              ],
            ),
          );
          if (v == null || !context.mounted) return;
          try {
            await ref.read(gatewayProvider).setAutoDeleteSeconds(v);
            setState(() => _v = v);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        },
      );
}

class _TtlTile extends ConsumerStatefulWidget {
  const _TtlTile();
  @override
  ConsumerState<_TtlTile> createState() => _TtlTileState();
}

class _TtlTileState extends ConsumerState<_TtlTile> {
  int? _v;

  @override
  void initState() {
    super.initState();
    ref
        .read(gatewayProvider)
        .accountTtlDays()
        .then((v) => mounted ? setState(() => _v = v) : null)
        .catchError((Object _) {});
  }

  String _label(BuildContext c, int d) => switch (d) {
        30 => c.t('1 month', 'شهر'),
        90 => c.t('3 months', '3 شهور'),
        180 => c.t('6 months', '6 شهور'),
        365 => c.t('1 year', 'سنة'),
        _ => c.t('$d days', '$d يوم'),
      };

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const SIcon(Icons.timer_off_outlined),
        title: Text(context.t('Delete my account if away for', 'احذف حسابي لو غبت')),
        subtitle: Text(context.t(
            'If you never open Telegram for this long, the account is deleted.',
            'لو ماتفتحش تليجرام المدة دي، الحساب بيتحذف.'),
            style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary)),
        trailing: Text(_v == null ? '…' : _label(context, _v!)),
        onTap: () async {
          final v = await showDialog<int>(
            context: context,
            builder: (dc) => SimpleDialog(
              title: Text(context.t('Account self-destruct', 'حذف الحساب تلقائيًا')),
              children: [
                for (final o in const [30, 90, 180, 365])
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(dc, o),
                      child: Text(_label(context, o))),
              ],
            ),
          );
          if (v == null || !context.mounted) return;
          try {
            await ref.read(gatewayProvider).setAccountTtlDays(v);
            setState(() => _v = v);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        },
      );
}

class _ArchiveTile extends ConsumerStatefulWidget {
  const _ArchiveTile();
  @override
  ConsumerState<_ArchiveTile> createState() => _ArchiveTileState();
}

class _ArchiveTileState extends ConsumerState<_ArchiveTile> {
  bool? _v;

  @override
  void initState() {
    super.initState();
    ref
        .read(gatewayProvider)
        .archiveNewFromUnknown()
        .then((v) => mounted ? setState(() => _v = v) : null)
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: const SIcon(Icons.archive_outlined),
        title: Text(context.t('Archive & mute new chats from strangers',
            'أرشفة وكتم الشاتات الجديدة من الغرباء')),
        subtitle: Text(context.t(
            'New chats from people not in your contacts go straight to the archive, muted.',
            'الشاتات الجديدة من ناس مش في جهات اتصالك بتروح للأرشيف مكتومة.')),
        value: _v ?? false,
        onChanged: _v == null
            ? null
            : (v) async {
                final m = ScaffoldMessenger.of(context);
                setState(() => _v = v);
                try {
                  await ref.read(gatewayProvider).setArchiveNewFromUnknown(v);
                } catch (e) {
                  if (mounted) setState(() => _v = !v);
                  m.showSnackBar(SnackBar(content: Text('$e')));
                }
              },
      );
}
