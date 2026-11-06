import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/app_settings.dart';
import '../core/theme/glass.dart';
import '../domain/models.dart';
import '../features/home/home_screen.dart';
import '../features/login/login_screen.dart';
import '../l10n/app_localizations.dart';
import '../features/downloads/keep_alive.dart';
import '../features/rules/rules_controller.dart';
import 'providers.dart';

class SudogramApp extends ConsumerStatefulWidget {
  const SudogramApp({super.key});

  @override
  ConsumerState<SudogramApp> createState() => _SudogramAppState();
}

class _SudogramAppState extends ConsumerState<SudogramApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keepAlive = DownloadKeepAlive(
        ref.read(pendingDownloadsProvider),
        title: 'SUDOGRAM',
        text: (n) => '↓ $n',
      )..init();
    });
  }

  DownloadKeepAlive? _keepAlive;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAlive?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hidden chats re-lock whenever the app leaves the foreground.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(vaultUnlockProvider.notifier).lock();
      ref.read(appLockedProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildGlassTheme(Brightness.dark),
      locale: s.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => GlassScope(
        performanceMode: s.performanceMode,
        accent: s.accentColor,
        child: GlassBackdrop(child: _LockGate(child: child)),
      ),
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(rulesRunnerProvider);
    final boot = ref.watch(bootProvider);
    final auth = ref.watch(authProvider);
    final l = AppLocalizations.of(context);
    if (boot.hasError) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('${boot.error}')),
      );
    }
    final step = auth.value?.step ?? AuthStep.initializing;
    if (step == AuthStep.ready) return const HomeScreen();
    if (step == AuthStep.waitPhone ||
        step == AuthStep.waitCode ||
        step == AuthStep.waitPassword) {
      return const LoginScreen();
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(child: Text(l.connecting)),
    );
  }
}

/// Covers the whole app with a lock screen while [appLockedProvider] is set.
class _LockGate extends ConsumerStatefulWidget {
  const _LockGate({required this.child});
  final Widget? child;

  @override
  ConsumerState<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<_LockGate> {
  bool _prompted = false;

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockedProvider);
    if (!locked) {
      _prompted = false;
      return widget.child ?? const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    if (!_prompted) {
      _prompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(appLockedProvider.notifier).unlock(l.appLockReason);
      });
    }
    return Scaffold(
      backgroundColor: GlassTokens.base,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  ref.read(appLockedProvider.notifier).unlock(l.appLockReason),
              child: Text(l.unlock),
            ),
          ],
        ),
      ),
    );
  }
}
