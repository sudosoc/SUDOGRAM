import 'notifier.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

import '../core/settings/app_settings.dart';
import '../data/archive/archive_db.dart';
import '../data/archive/archiving_gateway.dart';
import '../data/key_store.dart';
import '../data/mock_gateway.dart';
import '../data/vault/vault_store.dart';
import '../data/tdlib/net_log.dart';
import '../data/tdlib/td_gateway.dart';
import '../data/tdlib/td_native.dart';
import '../domain/ghost_gateway.dart';
import '../domain/models.dart';
import '../domain/telegram_gateway.dart';

const _apiId = int.fromEnvironment('TG_API_ID');
const _apiHash = String.fromEnvironment('TG_API_HASH');

/// Real TDLib only when credentials are compiled in and the native library
/// loads. Otherwise the demo gateway is used (and the UI says so).
TelegramGateway _buildRaw(int slot) {
  final real = _apiId != 0 && _apiHash.isNotEmpty && TdBindings.isAvailable;
  if (!real) return MockGateway();
  return TdlibGateway(
    transportFactory: () async =>
        LoggingTransport(await NativeTdTransport.start(), netLog),
    apiId: _apiId,
    apiHash: _apiHash,
    databaseDirectory: slotDir(slot, 'td_db'),
    filesDirectory: slotDir(slot, 'td_files'),
    encryptionKey: _tdKeys[slot] ?? '',
    newEncryptionKey: _tdKeys[slot] == null ? _keys.generate() : null,
    onEncryptionKeyApplied: (k) async {
      _tdKeys[slot] = k;
      await _keys.write(_keyName(slot), k);
    },
  );
}

late Directory _dir;
final _tdKeys = <int, String?>{};
String _keyName(int slot) => slot == 0 ? 'td_db_key' : 'td_db_key_$slot';

/// Slot 0 keeps the original folders so existing logins survive.
String slotDir(int slot, String base) =>
    slot == 0 ? '${_dir.path}/$base' : '${_dir.path}/${base}_$slot';

/// Wipes a removed account's local TDLib data.
Future<void> wipeSlot(int slot) async {
  if (slot == 0) return;
  for (final b in ['td_db', 'td_files']) {
    try {
      await Directory(slotDir(slot, b)).delete(recursive: true);
    } catch (_) {}
  }
  await _keys.write(_keyName(slot), '');
  _tdKeys.remove(slot);
}

final netLog = NetLog();
ArchivingGateway? _archiving;
late ArchiveDb _archive;
final _keys = KeyStore();

Future<void> initAppDirs() async {
  _dir = await getApplicationSupportDirectory();
  for (var i = 0; i < 10; i++) {
    final k = await _keys.read(_keyName(i));
    _tdKeys[i] = (k == null || k.isEmpty) ? null : k;
  }
  final archiveKey = await _keys.getOrCreate('archive_key');
  _archive = ArchiveDb.open('${_dir.path}/archive.db', key: archiveKey);
  _vault = VaultService(
    '${_dir.path}/vault',
    await _keys.getOrCreate('vault_salt'),
  );
}

late VaultService _vault;

final vaultServiceProvider = Provider<VaultService>((ref) => _vault);

final intruderDirProvider = Provider<String>((ref) => '${_dir.path}/intruders');

final archiveProvider = Provider<ArchiveDb>((ref) => _archive);

/// The gateway the UI uses: raw gateway wrapped in the Ghost guard.
final gatewayProvider = Provider<TelegramGateway>((ref) {
  final slot = ref.watch(settingsProvider.select((s) => s.activeSlot));
  final arch = ArchivingGateway(_buildRaw(slot), _archive);
  _archiving = arch;
  final g = GhostGateway(
    arch,
    isGhost: (id) => ref.read(settingsProvider).ghostFor(id),
    globalGhost: () => ref.read(settingsProvider).ghostGlobal,
    blocksRead: (id) => ref.read(settingsProvider).blocksRead(id),
    blocksTyping: (id) => ref.read(settingsProvider).blocksTyping(id),
    blocksOnline: () => ref.read(settingsProvider).hidesOnline,
  );
  ref.onDispose(g.dispose);
  return g;
});

final bootProvider = FutureProvider<void>((ref) async {
  await ref.read(gatewayProvider).start();
});

final authProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(gatewayProvider).authState,
);

final chatsProvider = StreamProvider<List<ChatSummary>>(
  (ref) => ref.watch(gatewayProvider).watchChats(),
);

final archivedProvider = StreamProvider<List<ChatSummary>>(
  (ref) => ref.watch(gatewayProvider).watchArchived(),
);

final messagesProvider = StreamProvider.family<List<ChatMessage>, int>(
  (ref, id) => ref.watch(gatewayProvider).watchMessages(id),
);

/// My own profile (for the @username title option).
final meProvider = FutureProvider<ProfileInfo?>((ref) async {
  final g = ref.watch(gatewayProvider);
  final auth = ref.watch(authProvider).value;
  if (auth?.step != AuthStep.ready) return null;
  return g.me();
});

/// Whether hidden chats are currently visible. Resets on app pause (see
/// the lifecycle hook in the app root).
class VaultUnlock extends Notifier<bool> {
  @override
  bool build() => false;

  void lock() => state = false;

  /// Opens the vault without asking (the caller already authenticated).
  void open() => state = true;

  /// System biometric / device-credential prompt only; does not open the vault.
  Future<bool> deviceAuth(String reason) async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
    } catch (e) {
      debugPrint('device auth failed: $e');
      return false;
    }
  }

  Future<bool> unlock({required String reason, bool requireAuth = true}) async {
    if (state) return true;
    if (!requireAuth) {
      state = true;
      return true;
    }
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
      state = ok;
      return ok;
    } catch (e) {
      debugPrint('vault auth failed: $e');
      return false;
    }
  }
}

final vaultUnlockProvider = NotifierProvider<VaultUnlock, bool>(
  VaultUnlock.new,
);

/// How many hidden-area screens (the hidden list, hidden chats) are open.
/// While > 0 and the vault is locked, a gate covers the app in place.
class HiddenArea extends Notifier<int> {
  @override
  int build() => 0;
  void enter() => state = state + 1;
  void leave() => state = state > 0 ? state - 1 : 0;
}

final hiddenAreaProvider = NotifierProvider<HiddenArea, int>(HiddenArea.new);

/// App Lock: when on, the app asks for biometrics after being in background.
class AppLocked extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsProvider).appLock; // locked at cold start

  void lock() {
    if (ref.read(settingsProvider).appLock) state = true;
  }

  void unlockNow() => state = false;

  Future<void> unlock(String reason) async {
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
      if (ok) state = false;
    } catch (e) {
      debugPrint('app unlock failed: $e');
    }
  }
}

final notifierProvider = Provider<MessageNotifier>((ref) => MessageNotifier());

final appLockedProvider = NotifierProvider<AppLocked, bool>(AppLocked.new);

/// Pending-download counter for the foreground service (null before the
/// gateway exists).
final pendingDownloadsProvider = Provider<ValueNotifier<int>>((ref) {
  ref.watch(gatewayProvider);
  return _archiving!.pendingDownloads;
});
