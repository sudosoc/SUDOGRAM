import 'dart:convert';
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
    this.notifications = true,
    this.wallpaper = 0,
    this.appLock = false,
    this.pinned = const {},
    this.aliases = const {},
    this.folders = const {},
    this.profiles = const {},
    this.accent = 0xFF4F46E5,
    this.localeCode,
    this.x = const {},
  });

  /// Extra options kept as one JSON blob (see the typed getters below).
  final Map<String, dynamic> x;

  /// Ghost Mode is on by default: this client exists to avoid leaking presence.
  final bool ghostGlobal;

  /// Per-chat override. Absent = follow [ghostGlobal].
  final Map<int, bool> ghostOverrides;
  final Set<int> hiddenChats;
  final bool performanceMode;
  final bool notifications;
  final int wallpaper;
  final bool appLock;

  /// Local-only organisation (nothing is sent to Telegram).
  final Set<int> pinned;
  final Map<int, String> aliases;

  /// Folder name → chat ids.
  final Map<String, Set<int>> folders;

  /// Saved setting presets: name → {ghost, appLock, performance}.
  final Map<String, Map<String, bool>> profiles;
  final int accent;

  /// `ar`, `en`, or null to follow the system language.
  final String? localeCode;

  Color get accentColor => Color(accent);
  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  bool ghostFor(int chatId) => ghostOverrides[chatId] ?? ghostGlobal;

  // ---- Ghost details -------------------------------------------------
  bool get ghostRead => x['ghostRead'] as bool? ?? true;
  bool get ghostTyping => x['ghostTyping'] as bool? ?? true;
  bool get ghostOnline => x['ghostOnline'] as bool? ?? true;

  /// Hidden chats are always ghosted, whatever the other switches say.
  bool get ghostForceHidden => x['ghostForceHidden'] as bool? ?? true;

  Map<String, dynamic> get _parts =>
      (x['ghostParts'] as Map?)?.cast<String, dynamic>() ?? const {};

  /// Per-chat override of the read/typing switches (null = follow global).
  bool? chatHidesRead(int id) => _parts['$id:read'] as bool?;
  bool? chatHidesTyping(int id) => _parts['$id:typing'] as bool?;

  bool _ghostOn(int id) =>
      ghostFor(id) || (ghostForceHidden && hiddenChats.contains(id));

  /// True when we must NOT send read receipts for this chat.
  bool blocksRead(int id) =>
      _ghostOn(id) && (chatHidesRead(id) ?? ghostRead);
  bool blocksTyping(int id) =>
      _ghostOn(id) && (chatHidesTyping(id) ?? ghostTyping);

  /// True when we must not appear online.
  bool get hidesOnline => ghostGlobal && ghostOnline;

  // ---- Home title ------------------------------------------------------
  /// 0 = app name, 1 = my @username, 2 = nothing.
  int get titleMode => x['titleMode'] as int? ?? 0;

  // ---- Hidden chats ----------------------------------------------------
  /// Ways to open the hidden chats: search (long-press search), title
  /// (3 taps on the title), ghost (long-press ghost chip), code (type the
  /// secret word in search), settings (long-press the settings button).
  Set<String> get hiddenMethods =>
      {for (final e in (x['hiddenMethods'] as List? ?? const ['search'])) e as String};
  String get hiddenCode => x['hiddenCode'] as String? ?? '';
  bool get hiddenAuth => x['hiddenAuth'] as bool? ?? true;
  bool get hiddenPreview => x['hiddenPreview'] as bool? ?? true;
  bool get hiddenSections => x['hiddenSections'] as bool? ?? true;

  /// 0 = generic "New message", 1 = no notification at all.
  int get hiddenNotify => x['hiddenNotify'] as int? ?? 0;
  Map<String, Set<int>> get hiddenFolders => {
        for (final e in (x['hiddenFolders'] as Map? ?? const {}).entries)
          e.key as String: {for (final i in e.value as List) i as int}
      };

  AppSettings copyWith({
    bool? ghostGlobal,
    Map<int, bool>? ghostOverrides,
    Set<int>? hiddenChats,
    bool? performanceMode,
    bool? notifications,
    int? wallpaper,
    bool? appLock,
    Set<int>? pinned,
    Map<int, String>? aliases,
    Map<String, Set<int>>? folders,
    Map<String, Map<String, bool>>? profiles,
    int? accent,
    String? localeCode,
    bool clearLocale = false,
    Map<String, dynamic>? x,
  }) {
    return AppSettings(
      ghostGlobal: ghostGlobal ?? this.ghostGlobal,
      ghostOverrides: ghostOverrides ?? this.ghostOverrides,
      hiddenChats: hiddenChats ?? this.hiddenChats,
      performanceMode: performanceMode ?? this.performanceMode,
      notifications: notifications ?? this.notifications,
      wallpaper: wallpaper ?? this.wallpaper,
      appLock: appLock ?? this.appLock,
      pinned: pinned ?? this.pinned,
      aliases: aliases ?? this.aliases,
      folders: folders ?? this.folders,
      profiles: profiles ?? this.profiles,
      accent: accent ?? this.accent,
      localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
      x: x ?? this.x,
    );
  }

  static const _kGhost = 'ghost_global';
  static const _kOverrides = 'ghost_overrides';
  static const _kHidden = 'hidden_chats';
  static const _kPerf = 'performance_mode';
  static const _kNotif = 'notifications';
  static const _kWall = 'wallpaper';
  static const _kLock = 'app_lock';
  static const _kLocal = 'local_org';
  static const _kAccent = 'accent';
  static const _kLocale = 'locale';
  static const _kX = 'extra_json';

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
      notifications: p.getBool(_kNotif) ?? true,
      wallpaper: p.getInt(_kWall) ?? 0,
      appLock: p.getBool(_kLock) ?? false,
      pinned: _loadLocal(p)['pinned'] as Set<int>,
      aliases: _loadLocal(p)['aliases'] as Map<int, String>,
      folders: _loadLocal(p)['folders'] as Map<String, Set<int>>,
      profiles: _loadLocal(p)['profiles'] as Map<String, Map<String, bool>>,
      accent: p.getInt(_kAccent) ?? GlassTokens.accentDefault.toARGB32(),
      localeCode: p.getString(_kLocale),
      x: _loadX(p),
    );
  }

  static Map<String, dynamic> _loadX(SharedPreferences p) {
    final raw = p.getString(_kX);
    if (raw == null) return const {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return const {};
    }
  }

  static Map<String, Object> _loadLocal(SharedPreferences p) {
    final out = <String, Object>{
      'pinned': <int>{},
      'aliases': <int, String>{},
      'folders': <String, Set<int>>{},
      'profiles': <String, Map<String, bool>>{},
    };
    final raw = p.getString(_kLocal);
    if (raw == null) return out;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      out['pinned'] = {for (final e in (j['pinned'] as List? ?? const [])) e as int};
      out['aliases'] = {
        for (final e in (j['aliases'] as Map? ?? const {}).entries)
          int.parse(e.key as String): e.value as String
      };
      out['folders'] = {
        for (final e in (j['folders'] as Map? ?? const {}).entries)
          e.key as String: {for (final i in e.value as List) i as int}
      };
      out['profiles'] = {
        for (final e in (j['profiles'] as Map? ?? const {}).entries)
          e.key as String: {
            for (final k in (e.value as Map).entries) k.key as String: k.value as bool
          }
      };
    } catch (_) {}
    return out;
  }

  Future<void> save(SharedPreferences p) async {
    await p.setString(
      _kLocal,
      jsonEncode({
        'pinned': pinned.toList(),
        'aliases': {for (final e in aliases.entries) '${e.key}': e.value},
        'folders': {for (final e in folders.entries) e.key: e.value.toList()},
        'profiles': profiles,
      }),
    );
    await p.setBool(_kGhost, ghostGlobal);
    await p.setStringList(
      _kOverrides,
      [for (final e in ghostOverrides.entries) '${e.key}:${e.value ? 1 : 0}'],
    );
    await p.setStringList(_kHidden, [for (final id in hiddenChats) '$id']);
    await p.setBool(_kPerf, performanceMode);
    await p.setBool(_kNotif, notifications);
    await p.setInt(_kWall, wallpaper);
    await p.setBool(_kLock, appLock);
    await p.setInt(_kAccent, accent);
    await p.setString(_kX, jsonEncode(x));
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

  void setX(String key, Object? value) {
    final m = Map<String, dynamic>.of(state.x);
    if (value == null) {
      m.remove(key);
    } else {
      m[key] = value;
    }
    _set(state.copyWith(x: m));
  }

  void setChatGhostPart(int chatId, String part, bool? value) {
    final m = Map<String, dynamic>.of(
        (state.x['ghostParts'] as Map?)?.cast<String, dynamic>() ?? {});
    if (value == null) {
      m.remove('$chatId:$part');
    } else {
      m['$chatId:$part'] = value;
    }
    setX('ghostParts', m);
  }

  void toggleHiddenMethod(String id) {
    final cur = state.hiddenMethods;
    cur.contains(id) ? cur.remove(id) : cur.add(id);
    if (cur.isEmpty) return; // never lock yourself out
    setX('hiddenMethods', cur.toList());
  }

  void toggleInHiddenFolder(String name, int chatId) {
    final map = {
      for (final e in state.hiddenFolders.entries) e.key: Set<int>.of(e.value)
    };
    final set = map.putIfAbsent(name, () => <int>{});
    set.contains(chatId) ? set.remove(chatId) : set.add(chatId);
    setX('hiddenFolders', {for (final e in map.entries) e.key: e.value.toList()});
  }

  void addHiddenFolder(String name) {
    final map = {
      for (final e in state.hiddenFolders.entries) e.key: e.value.toList()
    };
    map.putIfAbsent(name, () => <int>[]);
    setX('hiddenFolders', map);
  }

  void renameHiddenFolder(String from, String to) {
    final map = <String, List<int>>{};
    for (final e in state.hiddenFolders.entries) {
      map[e.key == from ? to : e.key] = e.value.toList();
    }
    setX('hiddenFolders', map);
  }

  void deleteHiddenFolder(String name) {
    final map = {
      for (final e in state.hiddenFolders.entries)
        if (e.key != name) e.key: e.value.toList()
    };
    setX('hiddenFolders', map);
  }

  void setHidden(int chatId, bool hidden) {
    final set = Set<int>.of(state.hiddenChats);
    hidden ? set.add(chatId) : set.remove(chatId);
    _set(state.copyWith(hiddenChats: set));
  }

  void setWallpaper(int v) => _set(state.copyWith(wallpaper: v));

  void setNotifications(bool value) =>
      _set(state.copyWith(notifications: value));

  void setPerformanceMode(bool value) =>
      _set(state.copyWith(performanceMode: value));

  void togglePin(int chatId) {
    final set = Set<int>.of(state.pinned);
    set.contains(chatId) ? set.remove(chatId) : set.add(chatId);
    _set(state.copyWith(pinned: set));
  }

  void setAlias(int chatId, String? alias) {
    final map = Map<int, String>.of(state.aliases);
    if (alias == null || alias.trim().isEmpty) {
      map.remove(chatId);
    } else {
      map[chatId] = alias.trim();
    }
    _set(state.copyWith(aliases: map));
  }

  /// Adds or removes [chatId] from folder [name]; empty folders disappear.
  void toggleInFolder(String name, int chatId) {
    final map = {for (final e in state.folders.entries) e.key: Set<int>.of(e.value)};
    final set = map.putIfAbsent(name, () => <int>{});
    set.contains(chatId) ? set.remove(chatId) : set.add(chatId);
    if (set.isEmpty) map.remove(name);
    _set(state.copyWith(folders: map));
  }

  void saveProfile(String name) {
    final map = {for (final e in state.profiles.entries) e.key: Map<String, bool>.of(e.value)};
    map[name] = {
      'ghost': state.ghostGlobal,
      'appLock': state.appLock,
      'performance': state.performanceMode,
    };
    _set(state.copyWith(profiles: map));
  }

  void applyProfile(String name) {
    final p = state.profiles[name];
    if (p == null) return;
    _set(state.copyWith(
      ghostGlobal: p['ghost'],
      appLock: p['appLock'],
      performanceMode: p['performance'],
    ));
  }

  void deleteProfile(String name) {
    final map = Map.of(state.profiles)..remove(name);
    _set(state.copyWith(profiles: map));
  }

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
