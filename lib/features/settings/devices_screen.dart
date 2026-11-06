import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  late Future<List<DeviceSession>> _f = ref.read(gatewayProvider).sessions();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(l.devices)),
      body: FutureBuilder<List<DeviceSession>>(
        future: _f,
        builder: (_, snap) {
          final list = snap.data ?? const <DeviceSession>[];
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: Text(l.connecting));
          }
          return ListView(children: [
            for (final d in list)
              ListTile(
                leading: Icon(d.current ? Icons.smartphone : Icons.devices_other),
                title: Text(d.app.isEmpty ? d.device : d.app),
                subtitle: Text(
                    '${d.device}\n${d.location} · ${d.lastActive.day}/${d.lastActive.month}/${d.lastActive.year}',
                    style: const TextStyle(color: GlassTokens.textSecondary)),
                isThreeLine: true,
                trailing: d.current
                    ? Text(l.thisDevice)
                    : TextButton(
                        child: Text(l.terminate),
                        onPressed: () async {
                          await ref.read(gatewayProvider).terminateSession(d.id);
                          if (!mounted) return;
                          setState(() => _f = ref.read(gatewayProvider).sessions());
                        },
                      ),
              ),
          ]);
        },
      ),
    );
  }
}
