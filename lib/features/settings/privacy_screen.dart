import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = {
      'phone': l.privPhone,
      'seen': l.privSeen,
      'photo': l.privPhoto,
      'calls': l.privCalls,
      'invites': l.privInvites,
      'forwards': l.privForwards,
    };
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(l.privacy)),
      body: ListView(children: [
        for (final e in items.entries) _Row(k: e.key, label: e.value),
      ]),
    );
  }
}

class _Row extends ConsumerStatefulWidget {
  const _Row({required this.k, required this.label});
  final String k;
  final String label;

  @override
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row> {
  String? _value;

  @override
  void initState() {
    super.initState();
    ref.read(gatewayProvider).getPrivacy(widget.k).then((v) {
      if (mounted) setState(() => _value = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      title: Text(widget.label),
      trailing: _value == null
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : DropdownButton<String>(
              value: _value,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: 'everybody', child: Text(l.everybody)),
                DropdownMenuItem(value: 'contacts', child: Text(l.myContacts)),
                DropdownMenuItem(value: 'nobody', child: Text(l.nobody)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _value = v);
                ref.read(gatewayProvider).setPrivacy(widget.k, v);
              },
            ),
    );
  }
}
