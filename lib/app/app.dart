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
import '../features/home/hidden_gate.dart';

/// Lets the lock overlay pop everything back to the home screen.
final rootNavKey = GlobalKey<NavigatorState>();

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
        keepConnected: () => ref.read(settingsProvider).notifications,
        idleText: _ar() ? 'متصل' : 'Connected',
      )..init();
      ref.read(notifierProvider).init();
    });
  }

  DownloadKeepAlive? _keepAlive;

  /// This widget sits above MaterialApp, so it has no localizations yet.
  bool _ar() {
    final code = ref.read(settingsProvider).localeCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == 'ar';
  }

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
    ref.listen(settingsProvider.select((x) => x.notifications),
        (_, _) => _keepAlive?.refresh());
    ref.listen(chatsProvider, (_, next) {
      final chats = next.value;
      if (chats == null) return;
      final st = ref.read(settingsProvider);
      ref.read(notifierProvider).onChats(chats,
          enabled: st.notifications,
          privateIds: st.hiddenChats,
          silentIds: st.hiddenNotify == 1 ? st.hiddenChats : const {},
          sound: st.notifSound,
          vibrate: st.notifVibrate,
          preview: st.notifPreview,
          hiddenBody: _ar() ? 'رسالة جديدة' : 'New message');
    });
    return MaterialApp(
      navigatorKey: rootNavKey,
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(s.textScale)),
        child: GlassScope(
          performanceMode: s.performanceMode,
          accent: s.accentColor,
          child: GlassBackdrop(child: _LockGate(child: child)),
        ),
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

/// Covers the app with a lock screen while it is locked, WITHOUT removing
/// the navigator: after unlocking you are exactly where you left off.
/// Two layers: the App Lock, and the hidden-chats gate (shown only while a
/// hidden-area screen is open and the vault is locked).
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
    final hiddenOpen = ref.watch(vaultUnlockProvider);
    final inHidden = ref.watch(hiddenAreaProvider) > 0;
    final l = AppLocalizations.of(context);
    if (!locked) {
      _prompted = false;
    } else if (!_prompted) {
      _prompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(appLockedProvider.notifier).unlock(l.appLockReason);
      });
    }
    return Stack(children: [
      Positioned.fill(child: widget.child ?? const SizedBox.shrink()),
      if (!locked && inHidden && !hiddenOpen)
        Positioned.fill(
          // own Overlay: this sits above the Navigator, text fields need one
          child: Overlay(initialEntries: [
            OverlayEntry(
              builder: (_) => Scaffold(
                backgroundColor: GlassTokens.base,
                body: HiddenGateView(
                  onUnlocked: () =>
                      ref.read(vaultUnlockProvider.notifier).open(),
                  onCancel: () =>
                      rootNavKey.currentState?.popUntil((r) => r.isFirst),
                ),
              ),
            ),
          ]),
        ),
      if (locked)
        Positioned.fill(
          child: Scaffold(
            backgroundColor: GlassTokens.base,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref
                        .read(appLockedProvider.notifier)
                        .unlock(l.appLockReason),
                    child: Text(l.unlock),
                  ),
                ],
              ),
            ),
          ),
        ),
    ]);
  }
}
