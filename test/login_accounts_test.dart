import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudogram/core/settings/app_settings.dart';
import 'package:sudogram/features/login/countries.dart';

void main() {
  group('phone normalisation', () {
    final eg = countryByIso('EG');
    test('leading zero is dropped', () {
      final p = normalizePhone(eg, '010 1234 5678');
      expect(p.e164, '+201012345678');
      expect(p.valid, isTrue);
    });
    test('without zero, with + and with 00 give the same number', () {
      expect(normalizePhone(eg, '1012345678').e164, '+201012345678');
      expect(normalizePhone(eg, '+20 101 234 5678').e164, '+201012345678');
      expect(normalizePhone(eg, '0020 1012345678').e164, '+201012345678');
    });
    test('too short is invalid', () {
      expect(normalizePhone(eg, '0101').valid, isFalse);
    });
    test('italy keeps the zero', () {
      final it = countryByIso('IT');
      expect(normalizePhone(it, '0612345678').e164, '+390612345678');
    });
    test('flag emoji from iso', () {
      expect(eg.flag, '🇪🇬');
    });
  });

  group('accounts and schedule', () {
    test('add, switch and remove accounts', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final c = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(p)]);
      addTearDown(c.dispose);
      final n = c.read(settingsProvider.notifier);
      expect(c.read(settingsProvider).activeSlot, 0);
      final slot = n.addAccount();
      expect(slot, 1);
      expect(c.read(settingsProvider).accounts.length, 2);
      expect(c.read(settingsProvider).activeSlot, 1);
      n.updateAccount(1, name: 'Sudo', unread: 4);
      expect(c.read(settingsProvider).accounts[1]['unread'], 4);
      n.switchAccount(0);
      n.removeAccount(1);
      expect(c.read(settingsProvider).accounts.length, 1);
      expect(c.read(settingsProvider).activeSlot, 0);
    });

    test('ghost schedule forces ghost inside the window', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      var s = AppSettings.load(p).copyWith(ghostGlobal: false);
      expect(s.blocksRead(1), isFalse);
      final now = DateTime.now();
      final m = now.hour * 60 + now.minute;
      s = s.copyWith(x: {
        'ghostSchedule': true,
        'ghostFrom': (m - 5) % 1440,
        'ghostTo': (m + 5) % 1440,
      });
      expect(s.scheduleActive, isTrue);
      expect(s.blocksRead(1), isTrue);
      expect(s.hidesOnline, isTrue);
    });
  });
}
