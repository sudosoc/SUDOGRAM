import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/ui/icon_styles.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../core/ui/notice.dart';
import '../../domain/models.dart';
import '../chat/chat_screen.dart';
import '../settings/widgets.dart';
import 'more_tools.dart';

/// Premium-style Telegram features that work on a normal account.
class PremiumHubScreen extends StatelessWidget {
  const PremiumHubScreen({super.key});

  Widget _t(BuildContext c, IconData i, String en, String ar, String hen,
          String har, Widget Function() w) =>
      ListTile(
        leading: SIcon(i),
        title: Text(c.t(en, ar)),
        subtitle: SHint(c.t(hen, har)),
        trailing: const SIcon(Icons.chevron_right, size: 20),
        onTap: () =>
            Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => w())),
      );

  @override
  Widget build(BuildContext context) => SPage(
        title: context.t('Power features', 'مزايا متقدمة'),
        children: [
          SGroup(title: context.t('Privacy & account', 'الخصوصية والحساب'), children: [
            _t(context, Icons.done_all, 'Read-time privacy', 'خصوصية وقت القراءة',
                'Hide when you read messages (and others\' read times).',
                'اخفي وقت قراءتك للرسايل (ووقت قراءة غيرك ليك).',
                () => const _ReadDate()),
            _t(context, Icons.mark_chat_read_outlined, 'Who can message me', 'مين يقدر يراسلني',
                'Block first messages from people who are not your contacts.',
                'امنع الرسايل الأولى من ناس مش في جهات اتصالك.',
                () => const _NewChat()),
            _t(context, Icons.public, 'Connected websites', 'المواقع المربوطة',
                'Sites where you signed in with Telegram — disconnect any.',
                'مواقع دخلت عليها بتليجرام — افصل أي واحد.',
                () => const _Websites()),
            _t(context, Icons.cake_outlined, 'My birthday', 'عيد ميلادي',
                'Add it to your profile so contacts can see it.',
                'ضيفه لبروفايلك عشان جهات اتصالك تشوفه.',
                () => const _Birthday()),
          ]),
          SGroup(title: context.t('Data & connection', 'البيانات والاتصال'), children: [
            _t(context, Icons.storage_outlined, 'Storage manager', 'مدير التخزين',
                'See what Telegram stores on this phone and clear it.',
                'شوف تليجرام مخزّن إيه على الموبايل وامسحه.',
                () => const _Storage()),
            _t(context, Icons.download_for_offline_outlined, 'Auto-download', 'التحميل التلقائي',
                'Pick Low / Medium / High per network (Wi-Fi, mobile, roaming).',
                'اختار منخفض / متوسط / عالي لكل شبكة (واي فاي، موبايل، رومينج).',
                () => const _AutoDl()),
            _t(context, Icons.vpn_key_outlined, 'Proxy manager', 'مدير البروكسي',
                'SOCKS5 / HTTP / MTProto proxies to reach Telegram when blocked.',
                'بروكسي SOCKS5 / HTTP / MTProto للوصول لتليجرام لو محجوب.',
                () => const _Proxies()),
          ]),
          SGroup(title: context.t('Chats', 'الشاتات'), children: [
            _t(context, Icons.favorite_border, 'Quick reaction', 'التفاعل السريع',
                'The emoji used when you double-tap a message.',
                'الإيموجي اللي بيتبعت لما تدوس مرتين على رسالة.',
                () => const _QuickReaction()),
            _t(context, Icons.search, 'Search all media', 'بحث في كل الوسائط',
                'Find photos, files, links and voice notes across every chat.',
                'دوّر على صور وملفات ولينكات ورسايل صوتية في كل الشاتات.',
                () => const _MediaSearch()),
            _t(context, Icons.file_download_outlined, 'Export chat to text', 'تصدير شات لنص',
                'Save a chat history as a .txt file you can open or share.',
                'احفظ تاريخ شات كملف txt تفتحه أو تشاركه.',
                () => const _Export()),
            _t(context, Icons.cleaning_services_outlined, 'Bulk clean-up', 'تنظيف جماعي',
                'Mute every group, archive read chats, unmute all.',
                'كتم كل الجروبات، أرشفة الشاتات المقروءة، إلغاء الكتم.',
                () => const _Bulk()),
            _t(context, Icons.insights_outlined, 'Chat insights', 'إحصائيات الشاتات',
                'Counts by type, unread, muted and biggest backlogs.',
                'أعداد حسب النوع وغير المقروء والمكتوم وأكبر تراكم.',
                () => const _Insights()),
            _t(context, Icons.link, 'Open / join a t.me link', 'فتح / انضمام لينك t.me',
                'Paste a username link or invite link and jump straight in.',
                'الصق لينك يوزر أو دعوة وادخل على طول.',
                () => const _OpenLink()),
            _t(context, Icons.cake, 'Contacts\' birthdays', 'أعياد ميلاد جهات الاتصال',
                'Upcoming birthdays of people who share theirs.',
                'أعياد الميلاد القادمة للي مفعّلين عرضها.',
                () => const _Birthdays()),
            _t(context, Icons.emoji_emotions_outlined, 'Sticker sets', 'حزم الستيكرز',
                'Remove or archive installed sticker packs.',
                'احذف أو أرشف حزم الستيكرز المثبّتة.',
                () => const _Stickers()),
          ]),
          SGroup(
              title: context.t('More', 'المزيد'),
              children: moreToolsTiles(context)),
          SGroup(title: context.t('Personal', 'شخصي'), children: [
            _t(context, Icons.bedtime_outlined, 'Do not disturb schedule', 'جدول عدم الإزعاج',
                'Silence notifications between two times every day.',
                'اكتم الإشعارات بين وقتين كل يوم.',
                () => const _Dnd()),
            _t(context, Icons.quickreply_outlined, 'Quick replies', 'ردود جاهزة',
                'Saved snippets you can copy in one tap.',
                'نصوص محفوظة تنسخها بضغطة.', () => const _Replies()),
            _t(context, Icons.sticky_note_2_outlined, 'Private notes', 'ملاحظات خاصة',
                'A notepad that lives only on this phone.',
                'مفكرة موجودة على الموبايل ده بس.', () => const _Notes()),
          ]),
        ],
      );
}

// ---------------------------------------------------------------- helpers

Widget _page(BuildContext c, String title, List<Widget> kids, {List<Widget>? actions}) =>
    Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
          backgroundColor: Colors.transparent, title: Text(title), actions: actions),
      body: ListView(padding: const EdgeInsets.all(12), children: kids),
    );

void _toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

String _size(num b) {
  if (b < 1024) return '${b.toInt()} B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1048576).toStringAsFixed(1)} MB';
  return '${(b / 1073741824).toStringAsFixed(2)} GB';
}

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Loads a value once from TDLib, shows a spinner / error while waiting.
class _Td<T> extends ConsumerStatefulWidget {
  const _Td({required this.title, required this.load, required this.builder});
  final String title;
  final Future<T> Function(WidgetRef ref) load;
  final Widget Function(BuildContext, T data, VoidCallback reload) builder;

  @override
  ConsumerState<_Td<T>> createState() => _TdState<T>();
}

class _TdState<T> extends ConsumerState<_Td<T>> {
  late Future<T> _f = widget.load(ref);

  void _reload() => setState(() => _f = widget.load(ref));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.title)),
        body: FutureBuilder<T>(
          future: _f,
          builder: (c, s) {
            if (s.hasError) {
              return Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${s.error}'.replaceFirst('Bad state: ', ''),
                    textAlign: TextAlign.center),
              ));
            }
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            return widget.builder(c, s.data as T, _reload);
          },
        ),
      );
}

// ---------------------------------------------------------------- privacy

class _ReadDate extends ConsumerWidget {
  const _ReadDate();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Td<bool>(
        title: context.t('Read-time privacy', 'خصوصية وقت القراءة'),
        load: (r) async =>
            (await r.read(gatewayProvider).tdRaw({'@type': 'getReadDatePrivacySettings'}))['show_read_date'] == true,
        builder: (c, on, reload) => StatefulBuilder(
          builder: (c, set) {
            var v = on;
            return StatefulBuilder(builder: (c, set2) => ListView(padding: const EdgeInsets.all(12), children: [
              SGroup(children: [
                SwitchListTile(
                  secondary: const SIcon(Icons.done_all),
                  title: Text(c.t('Show when I read messages', 'إظهار وقت قراءتي للرسايل')),
                  subtitle: SHint(c.t(
                      'Off = nobody sees your read time, and you will not see theirs.',
                      'مقفول = محدش يشوف وقت قراءتك، وإنت كمان مش هتشوف وقتهم.')),
                  value: v,
                  onChanged: (n) async {
                    try {
                      await ref.read(gatewayProvider).tdRaw({
                        '@type': 'setReadDatePrivacySettings',
                        'settings': {'@type': 'readDatePrivacySettings', 'show_read_date': n},
                      });
                      set2(() => v = n);
                    } catch (e) {
                      if (c.mounted) _toast(c, '$e');
                    }
                  },
                ),
              ]),
            ]));
          },
        ),
      );
}

class _NewChat extends ConsumerWidget {
  const _NewChat();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Td<bool>(
        title: context.t('Who can message me', 'مين يقدر يراسلني'),
        load: (r) async => (await r.read(gatewayProvider).tdRaw(
                {'@type': 'getNewChatPrivacySettings'}))['allow_new_chats_from_unknown_users'] !=
            false,
        builder: (c, on, reload) {
          var v = on;
          return StatefulBuilder(builder: (c, set) => ListView(padding: const EdgeInsets.all(12), children: [
            SGroup(children: [
              SwitchListTile(
                secondary: const SIcon(Icons.mark_chat_read_outlined),
                title: Text(c.t('Allow non-contacts to start chats', 'السماح لغير جهات الاتصال ببدء شات')),
                subtitle: SHint(c.t(
                    'Off = only your contacts can write to you first. (Telegram may require Premium to turn this off.)',
                    'مقفول = جهات اتصالك بس يقدروا يبعتولك الأول. (ممكن تليجرام يطلب Premium لقفله.)')),
                value: v,
                onChanged: (n) async {
                  try {
                    await ref.read(gatewayProvider).tdRaw({
                      '@type': 'setNewChatPrivacySettings',
                      'settings': {
                        '@type': 'newChatPrivacySettings',
                        'allow_new_chats_from_unknown_users': n,
                        'incoming_paid_message_star_count': 0,
                      },
                    });
                    set(() => v = n);
                  } catch (e) {
                    if (c.mounted) _toast(c, '$e');
                  }
                },
              ),
            ]),
          ]));
        },
      );
}

class _Websites extends ConsumerWidget {
  const _Websites();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Td<List<Map>>(
        title: context.t('Connected websites', 'المواقع المربوطة'),
        load: (r) async => [
          for (final w in ((await r.read(gatewayProvider).tdRaw({'@type': 'getConnectedWebsites'}))['websites'] as List? ?? const []))
            Map.from(w as Map),
        ],
        builder: (c, list, reload) => ListView(children: [
          if (list.isEmpty)
            Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(c.t('No connected websites', 'مفيش مواقع مربوطة')))),
          for (final w in list)
            ListTile(
              leading: const SIcon(Icons.language),
              title: Text('${w['domain_name']}'),
              subtitle: Text('${w['browser']} · ${w['platform']}\n${w['location']} ${w['ip_address']}'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const SIcon(Icons.link_off, color: GlassTokens.ringDanger),
                onPressed: () async {
                  await ref.read(gatewayProvider).tdRaw({'@type': 'disconnectWebsite', 'website_id': '${w['id']}'});
                  reload();
                },
              ),
            ),
          if (list.isNotEmpty)
            TextButton(
              onPressed: () async {
                await ref.read(gatewayProvider).tdRaw({'@type': 'disconnectAllWebsites'});
                reload();
              },
              child: Text(c.t('Disconnect all', 'افصل الكل'),
                  style: const TextStyle(color: GlassTokens.ringDanger)),
            ),
        ]),
      );
}

class _Birthday extends ConsumerWidget {
  const _Birthday();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _page(
        context,
        context.t('My birthday', 'عيد ميلادي'),
        [
          FilledButton.icon(
            icon: const SIcon(Icons.cake_outlined),
            label: Text(context.t('Choose date', 'اختار التاريخ')),
            onPressed: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000, 1, 1),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now());
              if (d == null || !context.mounted) return;
              try {
                await ref.read(gatewayProvider).tdRaw({
                  '@type': 'setBirthdate',
                  'birthdate': {'@type': 'birthdate', 'day': d.day, 'month': d.month, 'year': d.year},
                });
                if (context.mounted) _toast(context, context.t('Saved', 'اتحفظ'));
              } catch (e) {
                if (context.mounted) _toast(context, '$e');
              }
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              try {
                await ref.read(gatewayProvider).tdRaw({'@type': 'setBirthdate'});
                if (context.mounted) _toast(context, context.t('Removed', 'اتشال'));
              } catch (e) {
                if (context.mounted) _toast(context, '$e');
              }
            },
            child: Text(context.t('Remove birthday', 'شيل عيد الميلاد')),
          ),
        ],
      );
}

// ----------------------------------------------------------------- data

class _Storage extends ConsumerWidget {
  const _Storage();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Td<Map<String, dynamic>>(
        title: context.t('Storage manager', 'مدير التخزين'),
        load: (r) => r.read(gatewayProvider).tdRaw({'@type': 'getStorageStatisticsFast'}),
        builder: (c, m, reload) => ListView(padding: const EdgeInsets.all(12), children: [
          SGroup(children: [
            ListTile(
                leading: const SIcon(Icons.folder_outlined),
                title: Text(c.t('Cached files', 'الملفات المخزّنة')),
                trailing: Text('${_size(_i(m['files_size']))} · ${_i(m['file_count'])}')),
            ListTile(
                leading: const SIcon(Icons.storage),
                title: Text(c.t('Database', 'قاعدة البيانات')),
                trailing: Text(_size(_i(m['database_size'])))),
            ListTile(
                leading: const SIcon(Icons.description_outlined),
                title: Text(c.t('Logs', 'السجلات')),
                trailing: Text(_size(_i(m['log_size'])))),
          ]),
          SGroup(title: c.t('Clear cached files', 'مسح الملفات المخزّنة'), children: [
            for (final (en, ar, days) in [
              ('Older than 7 days', 'أقدم من 7 أيام', 7 * 86400),
              ('Older than 1 day', 'أقدم من يوم', 86400),
              ('Everything', 'كل حاجة', 0),
            ])
              ListTile(
                leading: const SIcon(Icons.delete_sweep_outlined),
                title: Text(c.t(en, ar)),
                onTap: () async {
                  try {
                    await ref.read(gatewayProvider).tdRaw({
                      '@type': 'optimizeStorage',
                      'size': -1,
                      'ttl': days == 0 ? -1 : days,
                      'count': -1,
                      'immunity_delay': 0,
                      'file_types': [],
                      'chat_ids': [],
                      'exclude_chat_ids': [],
                      'return_deleted_file_statistics': false,
                      'chat_limit': 0,
                    });
                    reload();
                  } catch (e) {
                    if (c.mounted) _toast(c, '$e');
                  }
                },
              ),
          ]),
        ]),
      );
}

class _AutoDl extends ConsumerStatefulWidget {
  const _AutoDl();
  @override
  ConsumerState<_AutoDl> createState() => _AutoDlState();
}

class _AutoDlState extends ConsumerState<_AutoDl> {
  Map<String, dynamic>? _presets;
  final _choice = <String, String>{};

  @override
  void initState() {
    super.initState();
    ref.read(gatewayProvider).tdRaw({'@type': 'getAutoDownloadSettingsPresets'}).then((m) {
      if (mounted) setState(() => _presets = m);
    });
  }

  Future<void> _apply(String net, String preset, String type) async {
    final p = _presets?[preset];
    if (p == null) return;
    try {
      await ref.read(gatewayProvider).tdRaw({
        '@type': 'setAutoDownloadSettings',
        'settings': p,
        'type': {'@type': type},
      });
      setState(() => _choice[net] = preset);
    } catch (e) {
      if (mounted) _toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => _page(context, context.t('Auto-download', 'التحميل التلقائي'), [
        if (_presets == null) const Center(child: CircularProgressIndicator()),
        if (_presets != null)
          for (final (net, en, ar, type) in [
            ('wifi', 'Wi-Fi', 'واي فاي', 'networkTypeWiFi'),
            ('mobile', 'Mobile data', 'بيانات الموبايل', 'networkTypeMobile'),
            ('roam', 'Roaming', 'رومينج', 'networkTypeMobileRoaming'),
          ])
            SGroup(title: context.t(en, ar), children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(spacing: 8, children: [
                  for (final (k, len, lar) in [
                    ('low', 'Low', 'منخفض'),
                    ('medium', 'Medium', 'متوسط'),
                    ('high', 'High', 'عالي'),
                  ])
                    ChoiceChip(
                      label: Text(context.t(len, lar)),
                      selected: _choice[net] == k,
                      onSelected: (_) => _apply(net, k, type),
                    ),
                ]),
              ),
            ]),
        SHint(context.t('Low saves data; High downloads bigger files automatically.',
            'المنخفض بيوفّر بيانات؛ العالي بينزّل ملفات أكبر تلقائيًا.')),
      ]);
}

class _Proxies extends ConsumerStatefulWidget {
  const _Proxies();
  @override
  ConsumerState<_Proxies> createState() => _ProxiesState();
}

class _ProxiesState extends ConsumerState<_Proxies> {
  List<Map> _list = const [];
  bool _loading = true;
  final _pings = <int, String>{};

  Future<Map<String, dynamic>> _raw(Map<String, dynamic> r) =>
      ref.read(gatewayProvider).tdRaw(r);

  Future<void> _load() async {
    try {
      final m = await _raw({'@type': 'getProxies'});
      if (mounted) {
        setState(() {
          _list = [for (final e in (m['proxies'] as List? ?? const [])) Map.from(e as Map)];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _add() async {
    final host = TextEditingController();
    final port = TextEditingController();
    final secret = TextEditingController();
    final user = TextEditingController();
    final pass = TextEditingController();
    var type = 'mtproto';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, set) => AlertDialog(
          title: Text(context.t('Add proxy', 'إضافة بروكسي')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'mtproto', label: Text('MTProto')),
                  ButtonSegment(value: 'socks5', label: Text('SOCKS5')),
                  ButtonSegment(value: 'http', label: Text('HTTP')),
                ],
                selected: {type},
                onSelectionChanged: (v) => set(() => type = v.first),
              ),
              TextField(controller: host, decoration: const InputDecoration(labelText: 'Server')),
              TextField(
                  controller: port,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Port')),
              if (type == 'mtproto')
                TextField(controller: secret, decoration: const InputDecoration(labelText: 'Secret')),
              if (type != 'mtproto') ...[
                TextField(controller: user, decoration: const InputDecoration(labelText: 'Username')),
                TextField(
                    controller: pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password')),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(context.t('Cancel', 'إلغاء'))),
            TextButton(onPressed: () => Navigator.pop(dc, true), child: Text(context.t('Add', 'إضافة'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _raw({
        '@type': 'addProxy',
        'proxy': {
          '@type': 'proxy',
          'server': host.text.trim(),
          'port': int.tryParse(port.text.trim()) ?? 0,
          'type': switch (type) {
            'mtproto' => {'@type': 'proxyTypeMtproto', 'secret': secret.text.trim()},
            'socks5' => {'@type': 'proxyTypeSocks5', 'username': user.text, 'password': pass.text},
            _ => {'@type': 'proxyTypeHttp', 'username': user.text, 'password': pass.text, 'http_only': false},
          },
        },
        'enable': true,
        'comment': '',
      });
      await _load();
    } catch (e) {
      if (mounted) _toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(context.t('Proxy manager', 'مدير البروكسي')),
          actions: [
            if (_list.any((p) => p['is_enabled'] == true))
              TextButton(
                onPressed: () async {
                  await _raw({'@type': 'disableProxy'});
                  await _load();
                },
                child: Text(context.t('Turn off', 'إيقاف')),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(onPressed: _add, child: const SIcon(Icons.add)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(children: [
                if (_list.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(context.t('No proxies yet', 'مفيش بروكسي لسه')))),
                for (final p in _list)
                  ListTile(
                    leading: SIcon(p['is_enabled'] == true ? Icons.check_circle : Icons.vpn_key_outlined),
                    title: Text('${(p['proxy'] as Map)['server']}:${(p['proxy'] as Map)['port']}'),
                    subtitle: Text(
                        '${((p['proxy'] as Map)['type'] as Map)['@type'].toString().replaceFirst('proxyType', '')}'
                        '${_pings[_i(p['id'])] == null ? '' : ' · ${_pings[_i(p['id'])]}'}'),
                    onTap: () async {
                      await _raw({'@type': 'enableProxy', 'proxy_id': _i(p['id'])});
                      await _load();
                    },
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const SIcon(Icons.speed),
                        onPressed: () async {
                          final id = _i(p['id']);
                          setState(() => _pings[id] = '…');
                          try {
                            final r = await _raw({'@type': 'pingProxy', 'proxy': p['proxy']});
                            final s = (r['seconds'] as num?)?.toDouble() ?? 0;
                            setState(() => _pings[id] = '${(s * 1000).round()} ms');
                          } catch (e) {
                            setState(() => _pings[id] = context.t('failed', 'فشل'));
                          }
                        },
                      ),
                      IconButton(
                        icon: const SIcon(Icons.delete_outline, color: GlassTokens.ringDanger),
                        onPressed: () async {
                          await _raw({'@type': 'removeProxy', 'proxy_id': _i(p['id'])});
                          await _load();
                        },
                      ),
                    ]),
                  ),
              ]),
      );
}

// ----------------------------------------------------------------- chats

class _QuickReaction extends ConsumerWidget {
  const _QuickReaction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(settingsProvider).quickReaction;
    return _page(context, context.t('Quick reaction', 'التفاعل السريع'), [
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final e in ['👍', '❤️', '🔥', '😂', '😮', '😢', '🎉', '👎', '🙏', '💯', '🤝', '👀'])
          GestureDetector(
            onTap: () async {
              ref.read(settingsProvider.notifier).setX('quickReaction', e);
              try {
                await ref.read(gatewayProvider).tdRaw({
                  '@type': 'setDefaultReactionType',
                  'reaction_type': {'@type': 'reactionTypeEmoji', 'emoji': e},
                });
              } catch (_) {}
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(width: cur == e ? 2.5 : 1, color: cur == e ? Colors.white : Colors.white24),
              ),
              child: Text(e, style: const TextStyle(fontSize: 28)),
            ),
          ),
      ]),
    ]);
  }
}

class _MediaSearch extends ConsumerStatefulWidget {
  const _MediaSearch();
  @override
  ConsumerState<_MediaSearch> createState() => _MediaSearchState();
}

class _MediaSearchState extends ConsumerState<_MediaSearch> {
  String _f = 'Photo';
  final _q = TextEditingController();
  List<Map> _res = const [];
  bool _busy = false;

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(gatewayProvider).tdRaw({
        '@type': 'searchMessages',
        'chat_list': {'@type': 'chatListMain'},
        'query': _q.text.trim(),
        'offset': '',
        'limit': 50,
        'filter': {'@type': 'searchMessagesFilter$_f'},
        'min_date': 0,
        'max_date': 0,
      });
      _res = [for (final m in (r['messages'] as List? ?? const [])) Map.from(m as Map)];
    } catch (e) {
      if (mounted) _toast(context, '$e'.replaceFirst('Bad state: ', ''));
    }
    if (mounted) setState(() => _busy = false);
  }

  String _title(Map m) {
    final id = _i(m['chat_id']);
    final chats = ref.read(chatsProvider).value ?? const <ChatSummary>[];
    return chats.where((c) => c.id == id).firstOrNull?.title ?? '$id';
  }

  String _desc(Map m) {
    final c = (m['content'] as Map?) ?? const {};
    final cap = ((c['caption'] ?? c['text']) as Map?)?['text'] ?? '';
    final t = '${c['@type']}'.replaceFirst('message', '');
    return cap.toString().isEmpty ? t : '$t · $cap';
  }

  @override
  Widget build(BuildContext context) => _page(context, context.t('Search all media', 'بحث في كل الوسائط'), [
        Wrap(spacing: 8, children: [
          for (final (k, en, ar) in [
            ('Photo', 'Photos', 'صور'),
            ('Video', 'Videos', 'فيديو'),
            ('Document', 'Files', 'ملفات'),
            ('Url', 'Links', 'لينكات'),
            ('Audio', 'Audio', 'صوت'),
            ('VoiceNote', 'Voice', 'رسايل صوتية'),
          ])
            ChoiceChip(
              label: Text(context.t(en, ar)),
              selected: _f == k,
              onSelected: (_) => setState(() => _f = k),
            ),
        ]),
        TextField(
          controller: _q,
          decoration: InputDecoration(hintText: context.t('Optional text', 'نص اختياري')),
          onSubmitted: (_) => _go(),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _go, child: Text(context.t('Search', 'بحث'))),
        if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        for (final m in _res)
          ListTile(
            leading: const SIcon(Icons.perm_media_outlined),
            title: Text(_title(m), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_desc(m), maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () {
              final id = _i(m['chat_id']);
              final chat = (ref.read(chatsProvider).value ?? const <ChatSummary>[])
                  .where((c) => c.id == id)
                  .firstOrNull;
              if (chat != null) {
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: chat)));
              }
            },
          ),
      ]);
}

class _Export extends ConsumerStatefulWidget {
  const _Export();
  @override
  ConsumerState<_Export> createState() => _ExportState();
}

class _ExportState extends ConsumerState<_Export> {
  bool _busy = false;
  double _limit = 500;

  String _text(Map m) {
    final c = (m['content'] as Map?) ?? const {};
    final t = (c['text'] as Map?)?['text'] ?? (c['caption'] as Map?)?['text'];
    final kind = '${c['@type']}'.replaceFirst('message', '');
    if (t != null && '$t'.isNotEmpty) return c['@type'] == 'messageText' ? '$t' : '[$kind] $t';
    return '[$kind]';
  }

  Future<void> _export(ChatSummary chat) async {
    setState(() => _busy = true);
    try {
      final g = ref.read(gatewayProvider);
      final out = <Map>[];
      var from = 0;
      while (out.length < _limit) {
        final r = await g.tdRaw({
          '@type': 'getChatHistory',
          'chat_id': chat.id,
          'from_message_id': from,
          'offset': 0,
          'limit': 100,
          'only_local': false,
        });
        final msgs = [for (final m in (r['messages'] as List? ?? const [])) Map.from(m as Map)];
        if (msgs.isEmpty) break;
        out.addAll(msgs);
        from = _i(msgs.last['id']);
      }
      final buf = StringBuffer('# ${chat.title}\n\n');
      for (final m in out.reversed) {
        final d = DateTime.fromMillisecondsSinceEpoch(_i(m['date']) * 1000);
        final who = m['is_outgoing'] == true ? 'Me' : chat.title;
        buf.writeln('[${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}] $who: ${_text(m)}');
      }
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/chat_${chat.id.abs()}.txt');
      await f.writeAsString(buf.toString());
      await OpenFilex.open(f.path);
    } catch (e) {
      if (mounted) _toast(context, '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatsProvider).value ?? const <ChatSummary>[];
    return _page(context, context.t('Export chat to text', 'تصدير شات لنص'), [
      Text(context.t('Messages to export: ${_limit.round()}', 'عدد الرسايل: ${_limit.round()}')),
      Slider(value: _limit, min: 100, max: 5000, divisions: 49, onChanged: (v) => setState(() => _limit = v)),
      if (_busy) const LinearProgressIndicator(),
      for (final c in chats)
        ListTile(
          title: Text(c.title),
          leading: const SIcon(Icons.file_download_outlined),
          onTap: _busy ? null : () => _export(c),
        ),
    ]);
  }
}

class _Bulk extends ConsumerWidget {
  const _Bulk();

  Future<void> _each(BuildContext c, WidgetRef ref, bool Function(ChatSummary) test,
      Future<void> Function(ChatSummary) act) async {
    final list = [for (final x in ref.read(chatsProvider).value ?? const <ChatSummary>[]) if (test(x)) x];
    final ok = await showDialog<bool>(
      context: c,
      builder: (dc) => AlertDialog(
        title: Text(c.t('Apply to ${list.length} chats?', 'تطبيق على ${list.length} شات؟')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(c.t('Cancel', 'إلغاء'))),
          TextButton(onPressed: () => Navigator.pop(dc, true), child: Text(c.t('Apply', 'تطبيق'))),
        ],
      ),
    );
    if (ok != true) return;
    for (final x in list) {
      await act(x);
    }
    if (c.mounted) _toast(c, c.t('Done', 'تم'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.read(gatewayProvider);
    return _page(context, context.t('Bulk clean-up', 'تنظيف جماعي'), [
      SGroup(children: [
        ListTile(
          leading: const SIcon(Icons.volume_off_outlined),
          title: Text(context.t('Mute all groups & channels', 'كتم كل الجروبات والقنوات')),
          onTap: () => _each(context, ref, (x) => (x.type == ChatType.group || x.type == ChatType.channel) && !x.muted,
              (x) => g.setMuted(x.id, true)),
        ),
        ListTile(
          leading: const SIcon(Icons.volume_up_outlined),
          title: Text(context.t('Unmute everything', 'إلغاء كتم الكل')),
          onTap: () => _each(context, ref, (x) => x.muted, (x) => g.setMuted(x.id, false)),
        ),
        ListTile(
          leading: const SIcon(Icons.archive_outlined),
          title: Text(context.t('Archive all read chats', 'أرشفة كل الشاتات المقروءة')),
          subtitle: SHint(context.t('Chats with no unread messages.', 'الشاتات اللي مفيهاش رسايل غير مقروءة.')),
          onTap: () => _each(context, ref, (x) => x.unread == 0 && !x.markedUnread, (x) => g.setArchived(x.id, true)),
        ),
      ]),
    ]);
  }
}

class _Insights extends ConsumerWidget {
  const _Insights();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(chatsProvider).value ?? const <ChatSummary>[];
    int n(bool Function(ChatSummary) f) => all.where(f).length;
    final top = [...all]..sort((a, b) => b.unread.compareTo(a.unread));
    Widget row(IconData i, String t, Object v) =>
        ListTile(leading: SIcon(i), title: Text(t), trailing: Text('$v', style: const TextStyle(fontSize: 18)));
    return _page(context, context.t('Chat insights', 'إحصائيات الشاتات'), [
      SGroup(children: [
        row(Icons.chat_bubble_outline, context.t('All chats', 'كل الشاتات'), all.length),
        row(Icons.person_outline, context.t('Private', 'خاص'),
            n((c) => c.type == ChatType.private || c.type == ChatType.secret)),
        row(Icons.groups_outlined, context.t('Groups', 'جروبات'), n((c) => c.type == ChatType.group)),
        row(Icons.campaign_outlined, context.t('Channels', 'قنوات'), n((c) => c.type == ChatType.channel)),
        row(Icons.volume_off_outlined, context.t('Muted', 'مكتومة'), n((c) => c.muted)),
        row(Icons.mark_chat_unread_outlined, context.t('With unread', 'فيها غير مقروء'), n((c) => c.unread > 0)),
        row(Icons.markunread_outlined, context.t('Unread messages', 'رسايل غير مقروءة'),
            all.fold<int>(0, (a, c) => a + c.unread)),
      ]),
      SGroup(title: context.t('Biggest backlogs', 'أكبر تراكم'), children: [
        for (final c in top.take(8))
          if (c.unread > 0) ListTile(title: Text(c.title), trailing: Text('${c.unread}')),
      ]),
    ]);
  }
}

class _OpenLink extends ConsumerStatefulWidget {
  const _OpenLink();
  @override
  ConsumerState<_OpenLink> createState() => _OpenLinkState();
}

class _OpenLinkState extends ConsumerState<_OpenLink> {
  final _c = TextEditingController();
  String? _msg;

  Future<void> _go() async {
    final t = _c.text.trim();
    final g = ref.read(gatewayProvider);
    try {
      final invite = RegExp(r't\.me/(?:\+|joinchat/)([\w-]+)').firstMatch(t);
      if (invite != null) {
        await g.tdRaw({'@type': 'joinChatByInviteLink', 'invite_link': t});
        setState(() => _msg = context.t('Joined', 'تم الانضمام'));
        return;
      }
      final u = RegExp(r'(?:t\.me/|@)([A-Za-z0-9_]{4,})').firstMatch(t)?.group(1) ?? t;
      final chat = await g.resolveUsername(u);
      if (chat == null) {
        setState(() => _msg = context.t('Not found', 'مش موجود'));
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: chat)));
    } catch (e) {
      setState(() => _msg = '$e'.replaceFirst('Bad state: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => _page(context, context.t('Open / join a link', 'فتح / انضمام لينك'), [
        TextField(controller: _c, decoration: const InputDecoration(hintText: 'https://t.me/username  or  t.me/+invite')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FilledButton(onPressed: _go, child: Text(context.t('Go', 'افتح')))),
          IconButton(
              icon: const SIcon(Icons.paste),
              onPressed: () async => _c.text = (await Clipboard.getData('text/plain'))?.text ?? ''),
        ]),
        if (_msg != null) Padding(padding: const EdgeInsets.all(8), child: Text(_msg!)),
      ]);
}

class _Birthdays extends ConsumerStatefulWidget {
  const _Birthdays();
  @override
  ConsumerState<_Birthdays> createState() => _BirthdaysState();
}

class _BirthdaysState extends ConsumerState<_Birthdays> {
  final List<(String, int, int)> _out = [];
  int _done = 0, _total = 0;
  bool _running = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _run();
  }

  int _days((String, int, int) e) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var d = DateTime(now.year, e.$2, e.$3);
    if (d.isBefore(today)) d = DateTime(now.year + 1, e.$2, e.$3);
    return d.difference(today).inDays;
  }

  Future<void> _run() async {
    final g = ref.read(gatewayProvider);
    try {
      final r = await g
          .tdRaw({'@type': 'getContacts'})
          .timeout(const Duration(seconds: 15));
      final ids = (r['user_ids'] as List? ?? const []).take(300).toList();
      if (!mounted) return;
      setState(() => _total = ids.length);
      for (var i = 0; i < ids.length && mounted; i += 8) {
        await Future.wait(ids.skip(i).take(8).map((id) async {
          try {
            final f = await g
                .tdRaw({'@type': 'getUserFullInfo', 'user_id': id})
                .timeout(const Duration(seconds: 6));
            final b = f['birthdate'] as Map?;
            if (b == null) return;
            final u = await g
                .tdRaw({'@type': 'getUser', 'user_id': id})
                .timeout(const Duration(seconds: 6));
            final name = '${u['first_name']} ${u['last_name']}'.trim();
            _out.add((name, _i(b['month']), _i(b['day'])));
          } catch (_) {}
        }));
        if (!mounted) return;
        setState(() {
          _done = (i + 8).clamp(0, ids.length);
          _out.sort((a, b) => _days(a).compareTo(_days(b)));
        });
      }
    } catch (e) {
      if (mounted) _err = friendlyError(e, ar: context.isAr);
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(context.t('Contacts\' birthdays', 'أعياد ميلاد جهات الاتصال')),
        bottom: _running && _total > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _done / _total),
              )
            : null,
      ),
      body: _err != null
          ? Center(child: Text(_err!))
          : ListView(children: [
              if (_out.isEmpty && !_running)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(context.t('No birthdays shared', 'محدش مشارك عيد ميلاده')),
                  ),
                ),
              if (_out.isEmpty && _running)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              for (final e in _out)
                ListTile(
                  leading: SIcon(_days(e) == 0 ? Icons.cake : Icons.cake_outlined),
                  title: Text(e.$1),
                  subtitle: Text(_days(e) == 0
                      ? context.t('Today!', 'النهارده!')
                      : context.t('in ${_days(e)} days', 'بعد ${_days(e)} يوم')),
                  trailing: Text('${e.$3}/${e.$2}'),
                ),
            ]),
    );
  }
}

class _Stickers extends ConsumerWidget {
  const _Stickers();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Td<List<Map>>(
        title: context.t('Sticker sets', 'حزم الستيكرز'),
        load: (r) async => [
          for (final s in ((await r.read(gatewayProvider).tdRaw({
                '@type': 'getInstalledStickerSets',
                'sticker_type': {'@type': 'stickerTypeRegular'},
              }))['sets'] as List? ??
              const []))
            Map.from(s as Map),
        ],
        builder: (c, list, reload) => ListView(children: [
          for (final s in list)
            ListTile(
              leading: const SIcon(Icons.emoji_emotions_outlined),
              title: Text('${s['title']}'),
              subtitle: Text('${s['size'] ?? ''}'),
              trailing: IconButton(
                icon: const SIcon(Icons.delete_outline, color: GlassTokens.ringDanger),
                onPressed: () async {
                  await ref.read(gatewayProvider).tdRaw({
                    '@type': 'changeStickerSet',
                    'set_id': '${s['id']}',
                    'is_installed': false,
                    'is_archived': false,
                  });
                  reload();
                },
              ),
            ),
        ]),
      );
}

// --------------------------------------------------------------- personal

class _Dnd extends ConsumerWidget {
  const _Dnd();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    Future<void> pick(String key, int cur) async {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
      if (t != null) c.setX(key, t.hour * 60 + t.minute);
    }

    return _page(context, context.t('Do not disturb schedule', 'جدول عدم الإزعاج'), [
      SGroup(children: [
        SwitchRow(
          icon: Icons.bedtime_outlined,
          title: context.t('Enable', 'تفعيل'),
          hint: context.t('No notifications are shown inside the window.', 'مفيش إشعارات بتظهر جوه الفترة دي.'),
          keyName: 'dndOn',
          value: s.dndOn,
        ),
        ListTile(
          leading: const SIcon(Icons.schedule),
          title: Text(context.t('From', 'من')),
          trailing: Text(hm(s.dndFrom)),
          onTap: () => pick('dndFrom', s.dndFrom),
        ),
        ListTile(
          leading: const SIcon(Icons.schedule),
          title: Text(context.t('To', 'إلى')),
          trailing: Text(hm(s.dndTo)),
          onTap: () => pick('dndTo', s.dndTo),
        ),
      ]),
    ]);
  }
}

class _Replies extends ConsumerWidget {
  const _Replies();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(context.t('Quick replies', 'ردود جاهزة'))),
      floatingActionButton: FloatingActionButton(
        child: const SIcon(Icons.add),
        onPressed: () async {
          final t = TextEditingController();
          final v = await showDialog<String>(
            context: context,
            builder: (dc) => AlertDialog(
              content: TextField(controller: t, autofocus: true, maxLines: 4),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dc), child: Text(context.t('Cancel', 'إلغاء'))),
                TextButton(onPressed: () => Navigator.pop(dc, t.text), child: Text(context.t('Save', 'حفظ'))),
              ],
            ),
          );
          if (v != null && v.trim().isNotEmpty) c.setX('quickReplies', [...s.quickReplies, v.trim()]);
        },
      ),
      body: ListView(children: [
        if (s.quickReplies.isEmpty)
          Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(context.t('Tap + to add a reply', 'دوس + عشان تضيف رد')))),
        for (final (i, r) in s.quickReplies.indexed)
          ListTile(
            title: Text(r, maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const SIcon(Icons.delete_outline),
              onPressed: () => c.setX('quickReplies', [for (final (j, e) in s.quickReplies.indexed) if (j != i) e]),
            ),
            onTap: () {
              Clipboard.setData(ClipboardData(text: r));
              _toast(context, context.t('Copied', 'اتنسخ'));
            },
          ),
      ]),
    );
  }
}

class _Notes extends ConsumerStatefulWidget {
  const _Notes();
  @override
  ConsumerState<_Notes> createState() => _NotesState();
}

class _NotesState extends ConsumerState<_Notes> {
  late final _c = TextEditingController(text: ref.read(settingsProvider).notes);

  @override
  Widget build(BuildContext context) => _page(context, context.t('Private notes', 'ملاحظات خاصة'), [
        TextField(
          controller: _c,
          minLines: 12,
          maxLines: 30,
          decoration: InputDecoration(hintText: context.t('Write here…', 'اكتب هنا…')),
          onChanged: (v) => ref.read(settingsProvider.notifier).setX('notes', v),
        ),
      ]);
}
