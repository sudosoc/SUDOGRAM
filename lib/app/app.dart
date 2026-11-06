import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/app_settings.dart';
import '../core/theme/glass.dart';
import '../domain/models.dart';
import '../features/home/home_screen.dart';
import '../features/login/login_screen.dart';
import '../l10n/app_localizations.dart';
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hidden chats re-lock whenever the app leaves the foreground.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(vaultUnlockProvider.notifier).lock();
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
        child: GlassBackdrop(child: child),
      ),
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
