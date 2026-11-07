import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudogram/core/settings/app_settings.dart';

Future<ProviderContainer> make() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pins, aliases, folders and profiles survive a restart', () async {
    final c = await make();
    final s = c.read(settingsProvider.notifier);
    s.togglePin(5);
    s.setAlias(5, ' Boss ');
    s.toggleInFolder('Work', 5);
    s.toggleInFolder('Work', 6);
    s.setGhostGlobal(false);
    s.saveProfile('Out');
    s.setGhostGlobal(true);
    c.dispose();

    final again = await make();
    final st = again.read(settingsProvider);
    expect(st.pinned, {5});
    expect(st.aliases[5], 'Boss');
    expect(st.folders['Work'], {5, 6});
    expect(st.profiles['Out']!['ghost'], isFalse);
    again.read(settingsProvider.notifier).applyProfile('Out');
    expect(again.read(settingsProvider).ghostGlobal, isFalse);
  });

  test('your own sections stay when empty; alias can be cleared', () async {
    final c = await make();
    final s = c.read(settingsProvider.notifier);
    s.toggleInFolder('A', 1);
    s.toggleInFolder('A', 1);
    expect(c.read(settingsProvider).folders['A'], isEmpty);
    s.deleteFolder('A');
    expect(c.read(settingsProvider).folders, isEmpty);
    s.setAlias(1, 'x');
    s.setAlias(1, '  ');
    expect(c.read(settingsProvider).aliases, isEmpty);
  });
}
