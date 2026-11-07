import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/core/settings/app_settings.dart';
import 'package:sudogram/core/theme/presets.dart';

void main() {
  test('settings sliders deliver doubles safely', () {
    const s = AppSettings(x: {'sendDelay': 3.0, 'homeLines': 2.0, 'barHeight': 60});
    expect(s.sendDelay, 3);
    expect(s.homeLines, 2);
    expect(s.barHeight, 60.0);
  });

  test('top-bar settings button only hides while the bar has settings', () {
    const withBar = AppSettings(x: {'homeShowSettings': false});
    expect(withBar.homeShowSettings, isFalse);
    const noSettings = AppSettings(x: {
      'homeShowSettings': false,
      'barItems': ['chats', 'contacts'],
    });
    expect(noSettings.homeShowSettings, isTrue);
    const barOff = AppSettings(x: {'homeShowSettings': false, 'barOn': false});
    expect(barOff.homeShowSettings, isTrue);
  });

  test('theme presets are unique and resolvable', () {
    final ids = themePresets.map((p) => p.id).toSet();
    expect(ids.length, themePresets.length);
    expect(presetById('nope').id, 'aurora');
  });
}
