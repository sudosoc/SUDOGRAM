import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// Locks the hidden area the instant its screen is left (back button, swipe
/// or any pop), so re-entering always asks for the fingerprint / passcode.
class _HiddenExitObserver extends NavigatorObserver {
  _HiddenExitObserver(this.ref);
  final WidgetRef ref;

  void _check(Route<dynamic>? r) {
    if (r?.settings.name == 'hidden' &&
        ref.read(settingsProvider).hiddenLockOnExit) {
      ref.read(vaultUnlockProvider.notifier).lock();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _check(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _check(route);
}

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
  DateTime? _pausedAt;
  bool _secure = false;

  /// This widget sits above MaterialApp, so it has no localizations yet.
  bool _ar() {
    final code =
        ref.read(settingsProvider).localeCode ??
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
      _pausedAt ??= DateTime.now();
      ref.read(vaultUnlockProvider.notifier).lock();
      if (ref.read(settingsProvider).lockDelay == 0) {
        ref.read(appLockedProvider.notifier).lock();
      }
    } else if (state == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      final d = ref.read(settingsProvider).lockDelay;
      if (at != null && d > 0 && DateTime.now().difference(at).inSeconds >= d) {
        ref.read(appLockedProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final secure =
        s.lockBlockScreenshots ||
        (s.hiddenSecure && ref.watch(hiddenAreaProvider) > 0);
    if (secure != _secure) {
      _secure = secure;
      const MethodChannel('sudogram/window')
          .invokeMethod<void>('secure', {'on': secure})
          .catchError((Object _) {});
    }
    ref.listen(
      settingsProvider.select((x) => x.notifications),
      (_, _) => _keepAlive?.refresh(),
    );
    ref.listen(meProvider, (_, next) {
      final me = next.value;
      if (me == null) return;
      ref
          .read(settingsProvider.notifier)
          .updateAccount(
            ref.read(settingsProvider).activeSlot,
            name: '${me.firstName} ${me.lastName}'.trim(),
            username: me.username,
          );
    });
    ref.listen(chatsProvider, (_, next) {
      final chats = next.value;
      if (chats == null) return;
      final st = ref.read(settingsProvider);
      var unread = 0;
      for (final c in chats) {
        if (!c.muted) unread += c.unread;
      }
      ref
          .read(settingsProvider.notifier)
          .updateAccount(st.activeSlot, unread: unread);
      ref
          .read(notifierProvider)
          .onChats(
            chats,
            enabled: st.notifications,
            privateIds: st.ghostNotifGeneric
                ? {
                    ...st.hiddenChats,
                    for (final c in chats)
                      if (st.blocksRead(c.id)) c.id,
                  }
                : st.hiddenChats,
            silentIds: st.hiddenNotify == 1 ? st.hiddenChats : const {},
            sound: st.notifSound,
            vibrate: st.notifVibrate,
            preview: st.notifPreview,
            content: st.notifContent,
            perChat: st.notifChats,
            locked:
                st.appLock && st.lockHidePreview && ref.read(appLockedProvider),
            countBody: (n) => _ar() ? '$n رسائل جديدة' : '$n new messages',
            hiddenBody: _ar() ? 'رسالة جديدة' : 'New message',
          );
    });
    return MaterialApp(
      navigatorKey: rootNavKey,
      navigatorObservers: [_HiddenExitObserver(ref)],
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
        step == AuthStep.waitPassword ||
        step == AuthStep.waitQr) {
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
    return Stack(
      children: [
        Positioned.fill(child: widget.child ?? const SizedBox.shrink()),
        if (!locked && inHidden && !hiddenOpen)
          Positioned.fill(
            // own Overlay: this sits above the Navigator, text fields need one
            child: Overlay(
              initialEntries: [
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
              ],
            ),
          ),
        if (locked)
          Positioned.fill(
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => Scaffold(
                    backgroundColor: GlassTokens.base,
                    body: HiddenGateView(
                      app: true,
                      onUnlocked: () =>
                          ref.read(appLockedProvider.notifier).unlockNow(),
                      onCancel: () => SystemNavigator.pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
