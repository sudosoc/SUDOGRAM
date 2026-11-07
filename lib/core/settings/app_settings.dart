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

  /// Ghost can be paused for a while ("peek mode").
  DateTime? get ghostPausedUntil {
    final ms = x['ghostPauseUntil'] as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  bool get ghostPaused => ghostPausedUntil?.isAfter(DateTime.now()) ?? false;

  // Scheduled ghost ("night mode"): ghost is forced on inside the window.
  bool get ghostSchedule => x['ghostSchedule'] as bool? ?? false;
  int get ghostFrom => x['ghostFrom'] as int? ?? 22 * 60;
  int get ghostTo => x['ghostTo'] as int? ?? 7 * 60;
  bool get scheduleActive {
    if (!ghostSchedule) return false;
    final n = DateTime.now();
    final m = n.hour * 60 + n.minute;
    return ghostFrom <= ghostTo
        ? (m >= ghostFrom && m < ghostTo)
        : (m >= ghostFrom || m < ghostTo);
  }

  /// Send read receipts for a ghosted chat once you reply in it.
  bool get ghostReadOnReply => x['ghostReadOnReply'] as bool? ?? false;

  /// Notifications from ghosted chats never show names or text.
  bool get ghostNotifGeneric => x['ghostNotifGeneric'] as bool? ?? false;

  bool _ghostOn(int id) =>
      !ghostPaused &&
      (scheduleActive ||
          ghostFor(id) ||
          (ghostForceHidden && hiddenChats.contains(id)));

  /// True when we must NOT send read receipts for this chat.
  bool blocksRead(int id) => _ghostOn(id) && (chatHidesRead(id) ?? ghostRead);
  bool blocksTyping(int id) =>
      _ghostOn(id) && (chatHidesTyping(id) ?? ghostTyping);

  /// True when we must not appear online.
  bool get hidesOnline =>
      (ghostGlobal || scheduleActive) && ghostOnline && !ghostPaused;

  // ---- Message gestures
  /// Actions: reply, forward, copy, react, heart, pin, select, delete,
  /// share, save, menu, none.
  String get swipeRight => x['swipeRight'] as String? ?? 'reply';
  String get swipeLeft => x['swipeLeft'] as String? ?? 'forward';
  String get doubleTap => x['doubleTap'] as String? ?? 'heart';

  // ---- Notifications
  bool get notifSound => x['notifSound'] as bool? ?? true;
  bool get notifVibrate => x['notifVibrate'] as bool? ?? true;
  bool get notifPreview => x['notifPreview'] as bool? ?? true;

  // ---- Chat look
  double get bubbleRadius => (x['bubbleRadius'] as num?)?.toDouble() ?? 18;

  bool get homeSections => x['homeSections'] as bool? ?? true;

  // ---- Home gestures (chat list rows)
  String get homeSwipeRight => x['homeSwipeRight'] as String? ?? 'pin';
  String get homeSwipeLeft => x['homeSwipeLeft'] as String? ?? 'archive';

  // ---- Hidden chats (extra)
  /// Block screenshots / recents preview while inside hidden chats.
  bool get hiddenSecure => x['hiddenSecure'] as bool? ?? true;

  /// Custom title for the hidden area (empty = default).
  String get hiddenTitle => x['hiddenTitle'] as String? ?? '';

  // ---- Accounts
  /// Saved accounts: [{slot, name, username, unread}] (slot 0 = the first).
  List<Map<String, dynamic>> get accounts => [
    for (final e in (x['accounts'] as List? ?? const []))
      Map<String, dynamic>.from(e as Map),
  ];
  int get activeSlot => x['activeSlot'] as int? ?? 0;
  bool get showAccountSwitcher => x['showAccountSwitcher'] as bool? ?? true;

  // ---- Customization: home
  /// circle | squircle | square | hidden
  String get avatarShape => x['avatarShape'] as String? ?? 'circle';

  /// full | nameOnly | compact (name + time) | bubbles
  String get rowMode => x['rowMode'] as String? ?? 'full';
  double get avatarSize => (x['avatarSize'] as num?)?.toDouble() ?? 52;
  bool get homeShowGhost => x['homeShowGhost'] as bool? ?? true;
  bool get homeShowSearch => x['homeShowSearch'] as bool? ?? true;
  bool get homeShowUnreadBadge => x['homeShowUnreadBadge'] as bool? ?? true;
  bool get homeShowTime => x['homeShowTime'] as bool? ?? true;
  bool get homeShowTicks => x['homeShowTicks'] as bool? ?? true;
  bool get homeDividers => x['homeDividers'] as bool? ?? false;
  int get homeLines => ((x['homeLines'] as num?)?.round() ?? 1).clamp(1, 3);

  // ---- Customization: chat ("Pro")
  String get chatAvatarShape => x['chatAvatarShape'] as String? ?? 'circle';
  bool get chatShowAvatars => x['chatShowAvatars'] as bool? ?? true;
  bool get chatShowTicks => x['chatShowTicks'] as bool? ?? true;
  bool get chatShowTime => x['chatShowTime'] as bool? ?? true;
  bool get chatShowNames => x['chatShowNames'] as bool? ?? true;
  bool get chatDateChips => x['chatDateChips'] as bool? ?? true;
  bool get chatTail => x['chatTail'] as bool? ?? true;
  double get chatSpacing => (x['chatSpacing'] as num?)?.toDouble() ?? 4;
  double get chatFontScale => (x['chatFontScale'] as num?)?.toDouble() ?? 1.0;

  /// glass | solid | gradient | outline
  String get bubbleStyle => x['bubbleStyle'] as String? ?? 'glass';

  // ---- Notifications (extended)
  /// full (name + text) | nameOnly | generic ("you got a message") | senderCount
  String get notifContent => x['notifContent'] as String? ?? 'full';

  /// chatId -> {sound, vib, mute}
  Map<String, Map<String, dynamic>> get notifChats => {
    for (final e in (x['notifChats'] as Map? ?? const {}).entries)
      e.key as String: Map<String, dynamic>.from(e.value as Map),
  };
  bool get notifGroupByChat => x['notifGroupByChat'] as bool? ?? true;
  bool get notifInApp => x['notifInApp'] as bool? ?? true;

  // ---- App lock (extended)
  /// biometric | pin | word | pattern(not yet) — methods that unlock the app.
  Set<String> get lockMethods => {
    for (final e in (x['lockMethods'] as List? ?? const ['biometric']))
      e as String,
  };
  String get lockPinHash => x['lockPinHash'] as String? ?? '';
  String get lockPinSalt => x['lockPinSalt'] as String? ?? '';
  String get lockPinKind => x['lockPinKind'] as String? ?? '4';

  /// Seconds the app may stay in background before it locks (0 = at once).
  int get lockDelay => x['lockDelay'] as int? ?? 0;
  bool get lockHidePreview => x['lockHidePreview'] as bool? ?? true;
  bool get lockBlockScreenshots => x['lockBlockScreenshots'] as bool? ?? false;
  int get lockMaxFails => x['lockMaxFails'] as int? ?? 5;
  bool get lockPhotoIntruder => x['lockPhotoIntruder'] as bool? ?? false;

  /// Text size multiplier for the whole app.
  double get textScale => (x['textScale'] as num?)?.toDouble() ?? 1.0;

  // ---- Home title ------------------------------------------------------
  /// 0 = app name, 1 = my @username, 2 = nothing.
  int get titleMode => x['titleMode'] as int? ?? 0;

  // ---- Hidden chats ----------------------------------------------------
  /// Ways to open the hidden chats: search (long-press search), title
  /// (3 taps on the title), ghost (long-press ghost chip), code (type the
  /// secret word in search), settings (long-press the settings button).
  Set<String> get hiddenMethods => {
    for (final e in (x['hiddenMethods'] as List? ?? const ['search']))
      e as String,
  };
  String get hiddenCode => x['hiddenCode'] as String? ?? '';
  bool get hiddenAuth => x['hiddenAuth'] as bool? ?? true;
  bool get hiddenPreview => x['hiddenPreview'] as bool? ?? true;

  /// Own passcode for hidden chats (salted hash; kind = 4/6/8/10/text).
  String get hiddenPinHash => x['hiddenPinHash'] as String? ?? '';
  String get hiddenPinSalt => x['hiddenPinSalt'] as String? ?? '';
  String get hiddenPinKind => x['hiddenPinKind'] as String? ?? '4';
  bool get hasHiddenPin => hiddenPinHash.isNotEmpty;

  /// Lock again as soon as the hidden area is closed.
  bool get hiddenLockOnExit => x['hiddenLockOnExit'] as bool? ?? true;
  bool get hiddenSections => x['hiddenSections'] as bool? ?? true;

  /// 0 = generic "New message", 1 = no notification at all.
  int get hiddenNotify => x['hiddenNotify'] as int? ?? 0;
  Map<String, Set<int>> get hiddenFolders => {
    for (final e in (x['hiddenFolders'] as Map? ?? const {}).entries)
      e.key as String: {for (final i in e.value as List) i as int},
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
      out['pinned'] = {
        for (final e in (j['pinned'] as List? ?? const [])) e as int,
      };
      out['aliases'] = {
        for (final e in (j['aliases'] as Map? ?? const {}).entries)
          int.parse(e.key as String): e.value as String,
      };
      out['folders'] = {
        for (final e in (j['folders'] as Map? ?? const {}).entries)
          e.key as String: {for (final i in e.value as List) i as int},
      };
      out['profiles'] = {
        for (final e in (j['profiles'] as Map? ?? const {}).entries)
          e.key as String: {
            for (final k in (e.value as Map).entries)
              k.key as String: k.value as bool,
          },
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
    await p.setStringList(_kOverrides, [
      for (final e in ghostOverrides.entries) '${e.key}:${e.value ? 1 : 0}',
    ]);
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

  // ---- accounts
  List<Map<String, dynamic>> _accs() {
    final l = state.accounts;
    if (l.isEmpty) l.add({'slot': 0, 'name': '', 'username': '', 'unread': 0});
    return l;
  }

  /// Registers a new empty slot and makes it the active one.
  int addAccount() {
    final l = _accs();
    final slot =
        l.map((e) => e['slot'] as int).fold<int>(0, (a, b) => a > b ? a : b) +
        1;
    l.add({'slot': slot, 'name': '', 'username': '', 'unread': 0});
    final m = Map<String, dynamic>.of(state.x)
      ..['accounts'] = l
      ..['activeSlot'] = slot;
    _set(state.copyWith(x: m));
    return slot;
  }

  void switchAccount(int slot) => setX('activeSlot', slot);

  void removeAccount(int slot) {
    final l = _accs()..removeWhere((e) => e['slot'] == slot);
    final m = Map<String, dynamic>.of(state.x)..['accounts'] = l;
    if (state.activeSlot == slot) {
      m['activeSlot'] = l.isEmpty ? 0 : l.first['slot'];
    }
    _set(state.copyWith(x: m));
  }

  void updateAccount(int slot, {String? name, String? username, int? unread}) {
    final l = _accs();
    final i = l.indexWhere((e) => e['slot'] == slot);
    if (i < 0) return;
    final e = l[i];
    if ((name == null || e['name'] == name) &&
        (username == null || e['username'] == username) &&
        (unread == null || e['unread'] == unread)) {
      if (state.accounts.isNotEmpty) return;
    }
    if (name != null) e['name'] = name;
    if (username != null) e['username'] = username;
    if (unread != null) e['unread'] = unread;
    setX('accounts', l);
  }

  void setChatGhostPart(int chatId, String part, bool? value) {
    final m = Map<String, dynamic>.of(
      (state.x['ghostParts'] as Map?)?.cast<String, dynamic>() ?? {},
    );
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
      for (final e in state.hiddenFolders.entries) e.key: Set<int>.of(e.value),
    };
    final set = map.putIfAbsent(name, () => <int>{});
    set.contains(chatId) ? set.remove(chatId) : set.add(chatId);
    setX('hiddenFolders', {
      for (final e in map.entries) e.key: e.value.toList(),
    });
  }

  void addHiddenFolder(String name) {
    final map = {
      for (final e in state.hiddenFolders.entries) e.key: e.value.toList(),
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
        if (e.key != name) e.key: e.value.toList(),
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
    final map = {
      for (final e in state.folders.entries) e.key: Set<int>.of(e.value),
    };
    final set = map.putIfAbsent(name, () => <int>{});
    set.contains(chatId) ? set.remove(chatId) : set.add(chatId);
    _set(state.copyWith(folders: map));
  }

  void addFolder(String name) {
    final map = {
      for (final e in state.folders.entries) e.key: Set<int>.of(e.value),
    };
    map.putIfAbsent(name, () => <int>{});
    _set(state.copyWith(folders: map));
  }

  void renameFolder(String from, String to) {
    final map = <String, Set<int>>{};
    for (final e in state.folders.entries) {
      map[e.key == from ? to : e.key] = Set<int>.of(e.value);
    }
    _set(state.copyWith(folders: map));
  }

  void deleteFolder(String name) {
    final map = {
      for (final e in state.folders.entries)
        if (e.key != name) e.key: Set<int>.of(e.value),
    };
    _set(state.copyWith(folders: map));
  }

  void saveProfile(String name) {
    final map = {
      for (final e in state.profiles.entries)
        e.key: Map<String, bool>.of(e.value),
    };
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
    _set(
      state.copyWith(
        ghostGlobal: p['ghost'],
        appLock: p['appLock'],
        performanceMode: p['performance'],
      ),
    );
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

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
