import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import 'widgets.dart';

/// The e-mail Telegram sends sign-in codes to (shown masked, changeable).
class LoginEmailScreen extends ConsumerStatefulWidget {
  const LoginEmailScreen({super.key});

  @override
  ConsumerState<LoginEmailScreen> createState() => _LoginEmailScreenState();
}

class _LoginEmailScreenState extends ConsumerState<LoginEmailScreen> {
  String? _pattern;
  bool _loaded = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(gatewayProvider).tdRaw({'@type': 'getPasswordState'});
      _pattern = (r['login_email_address_pattern'] ?? '').toString();
    } catch (e) {
      _msg = '$e'.replaceFirst('Bad state: ', '');
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<String?> _ask(String title, {TextInputType? type}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, keyboardType: type),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc), child: Text(context.t('Cancel', 'إلغاء'))),
          TextButton(onPressed: () => Navigator.pop(dc, c.text.trim()), child: Text(context.t('OK', 'تمام'))),
        ],
      ),
    );
  }

  Future<void> _change() async {
    final g = ref.read(gatewayProvider);
    final mail = await _ask(context.t('New login e-mail', 'إيميل الدخول الجديد'),
        type: TextInputType.emailAddress);
    if (mail == null || mail.isEmpty || !mounted) return;
    try {
      await g.tdRaw({'@type': 'setLoginEmailAddress', 'new_login_email_address': mail});
      if (!mounted) return;
      final code = await _ask(context.t('Code sent to $mail', 'الكود اتبعت على $mail'),
          type: TextInputType.number);
      if (code == null || code.isEmpty) return;
      await g.tdRaw({
        '@type': 'checkLoginEmailAddressCode',
        'code': {'@type': 'emailAddressAuthenticationCode', 'code': code},
      });
      setState(() => _msg = context.t('Login e-mail updated', 'اتحدّث إيميل الدخول'));
      await _load();
    } catch (e) {
      if (mounted) setState(() => _msg = '$e'.replaceFirst('Bad state: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => SPage(
        title: context.t('Login e-mail', 'إيميل الدخول'),
        children: [
          SGroup(children: [
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: Text(!_loaded
                  ? '…'
                  : (_pattern == null || _pattern!.isEmpty)
                      ? context.t('No login e-mail set', 'مفيش إيميل دخول')
                      : _pattern!),
              subtitle: SHint(context.t(
                  'Telegram can send your sign-in code to this e-mail instead of another device or SMS.',
                  'تليجرام ممكن يبعت كود الدخول على الإيميل ده بدل جهاز تاني أو SMS.')),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.t('Change e-mail', 'تغيير الإيميل')),
              onTap: _change,
            ),
          ]),
          if (_msg != null) Padding(padding: const EdgeInsets.all(12), child: Text(_msg!)),
        ],
      );
}
