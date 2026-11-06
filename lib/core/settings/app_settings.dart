import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/glass.dart';

/// Overridden in `main()` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

class AppSettings {
  const AppSettings({
    this.ghostGlobal = true,
    this.ghostOverrides = const {},
    this.hiddenChats = const {},
    this.performanceMode = false,
    this.appLock = false,
    this.accent = 0xFF4F46E5,
    this.localeCode,
  });

  /// Ghost Mode is on by default: this client exists to avoid leaking presence.
  final bool ghostGlobal;

  /// Per-chat override. Absent = follow [ghostGlobal].
  final Map<int, bool> ghostOverrides;
  final Set<int> hiddenChats;
  final bool performanceMode;
  final bool appLock;
  final int accent;

  /// `ar`, `en`, or null to follow the system language.
  final String? localeCode;

  Color get accentColor => Color(accent);
  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  bool ghostFor(int chatId) => ghostOverrides[chatId] ?? ghostGlobal;

  AppSettings copyWith({
    bool? ghostGlobal,
    Map<int, bool>? ghostOverrides,
    Set<int>? hiddenChats,
    bool? performanceMode,
    bool? appLock,
    int? accent,
    String? localeCode,
    bool clearLocale = false,
  }) {
    return AppSettings(
      ghostGlobal: ghostGlobal ?? this.ghostGlobal,
      ghostOverrides: ghostOverrides ?? this.ghostOverrides,
      hiddenChats: hiddenChats ?? this.hiddenChats,
      performanceMode: performanceMode ?? this.performanceMode,
      appLock: appLock ?? this.appLock,
      accent: accent ?? this.accent,
      localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
    );
  }

  static const _kGhost = 'ghost_global';
  static const _kOverrides = 'ghost_overrides';
  static const _kHidden = 'hidden_chats';
  static const _kPerf = 'performance_mode';
  static const _kLock = 'app_lock';
  static const _kAccent = 'accent';
  static const _kLocale = 'locale';

  factory AppSettings.load(SharedPreferences p) {
    final overrides = <int, bool>{};
    for (final entry in p.getStringList(_kOverrides) ?? const <String>[]) {
      final parts = entry.split(':');
      final id = parts.length == 2 ? int.tryParse(parts[0]) : null;
      if (id != null) overrides[id] = parts[1] == '1';
    }
    final hidden = <int>{
      for (final s in p.getStringList(_kHidden) ?? const <String>[])
        if (int.tryParse(s) != null) int.parse(s),
    };
    return AppSettings(
      ghostGlobal: p.getBool(_kGhost) ?? true,
      ghostOverrides: overrides,
      hiddenChats: hidden,
      performanceMode: p.getBool(_kPerf) ?? false,
      appLock: p.getBool(_kLock) ?? false,
      accent: p.getInt(_kAccent) ?? GlassTokens.accentDefault.toARGB32(),
      localeCode: p.getString(_kLocale),
    );
  }

  Future<void> save(SharedPreferences p) async {
    await p.setBool(_kGhost, ghostGlobal);
    await p.setStringList(
      _kOverrides,
      [for (final e in ghostOverrides.entries) '${e.key}:${e.value ? 1 : 0}'],
    );
    await p.setStringList(_kHidden, [for (final id in hiddenChats) '$id']);
    await p.setBool(_kPerf, performanceMode);
    await p.setBool(_kLock, appLock);
    await p.setInt(_kAccent, accent);
    if (localeCode == null) {
      await p.remove(_kLocale);
    } else {
      await p.setString(_kLocale, localeCode!);
    }
  }
}

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.load(ref.watch(sharedPreferencesProvider));

  void _set(AppSettings next) {
    state = next;
    next.save(ref.read(sharedPreferencesProvider));
  }

  void setGhostGlobal(bool value) => _set(state.copyWith(ghostGlobal: value));

  /// `value == null` removes the override (follow the global switch).
  void setGhostOverride(int chatId, bool? value) {
    final map = Map<int, bool>.of(state.ghostOverrides);
    if (value == null) {
      map.remove(chatId);
    } else {
      map[chatId] = value;
    }
    _set(state.copyWith(ghostOverrides: map));
  }

  void setHidden(int chatId, bool hidden) {
    final set = Set<int>.of(state.hiddenChats);
    hidden ? set.add(chatId) : set.remove(chatId);
    _set(state.copyWith(hiddenChats: set));
  }

  void setPerformanceMode(bool value) =>
      _set(state.copyWith(performanceMode: value));

  void setAppLock(bool v) => _set(state.copyWith(appLock: v));

  void setAccent(Color color) => _set(state.copyWith(accent: color.toARGB32()));

  void setLocale(String? code) => _set(
        code == null
            ? state.copyWith(clearLocale: true)
            : state.copyWith(localeCode: code),
      );
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
