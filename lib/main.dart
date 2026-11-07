import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/drafts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never let a stray async error take the app down.
  PlatformDispatcher.instance.onError = (e, st) {
    debugPrint('uncaught: $e\n$st');
    return true;
  };
  final prefs = await SharedPreferences.getInstance();
  await initAppDirs();
  await DraftStore.load();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const SudogramApp(),
  ));
}
