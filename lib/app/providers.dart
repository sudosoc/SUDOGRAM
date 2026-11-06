import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

import '../core/settings/app_settings.dart';
import '../data/mock_gateway.dart';
import '../data/tdlib/td_gateway.dart';
import '../data/tdlib/td_native.dart';
import '../domain/ghost_gateway.dart';
import '../domain/models.dart';
import '../domain/telegram_gateway.dart';

const _apiId = int.fromEnvironment('TG_API_ID');
const _apiHash = String.fromEnvironment('TG_API_HASH');

/// Real TDLib only when credentials are compiled in and the native library
/// loads. Otherwise the demo gateway is used (and the UI says so).
TelegramGateway _buildRaw() {
  final real = _apiId != 0 && _apiHash.isNotEmpty && TdBindings.isAvailable;
  if (!real) return MockGateway();
  return TdlibGateway(
    transportFactory: NativeTdTransport.start,
    apiId: _apiId,
    apiHash: _apiHash,
    databaseDirectory: '${_dir.path}/td_db',
    filesDirectory: '${_dir.path}/td_files',
  );
}

late Directory _dir;

Future<void> initAppDirs() async {
  _dir = await getApplicationSupportDirectory();
}

/// The gateway the UI uses: raw gateway wrapped in the Ghost guard.
final gatewayProvider = Provider<TelegramGateway>((ref) {
  final g = GhostGateway(
    _buildRaw(),
    isGhost: (id) => ref.read(settingsProvider).ghostFor(id),
    globalGhost: () => ref.read(settingsProvider).ghostGlobal,
  );
  ref.onDispose(g.dispose);
  return g;
});

final bootProvider = FutureProvider<void>((ref) async {
  await ref.read(gatewayProvider).start();
});

final authProvider = StreamProvider<AuthState>(
    (ref) => ref.watch(gatewayProvider).authState);

final chatsProvider = StreamProvider<List<ChatSummary>>(
    (ref) => ref.watch(gatewayProvider).watchChats());

final messagesProvider = StreamProvider.family<List<ChatMessage>, int>(
    (ref, id) => ref.watch(gatewayProvider).watchMessages(id));

/// Whether hidden chats are currently visible. Resets on app pause (see
/// the lifecycle hook in the app root).
class VaultUnlock extends Notifier<bool> {
  @override
  bool build() => false;

  void lock() => state = false;

  Future<bool> unlock({required String reason}) async {
    if (state) return true;
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

final vaultUnlockProvider =
    NotifierProvider<VaultUnlock, bool>(VaultUnlock.new);
