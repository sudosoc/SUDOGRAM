import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudogram/core/settings/app_settings.dart';

void main() {
  test('granular ghost switches, per-chat overrides and forced hidden chats',
      () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    var s = AppSettings.load(p);
    expect(s.blocksRead(1), isTrue);
    expect(s.blocksTyping(1), isTrue);
    expect(s.hidesOnline, isTrue);

    s = s.copyWith(x: {'ghostRead': false});
    expect(s.blocksRead(1), isFalse);
    expect(s.blocksTyping(1), isTrue);

    // per-chat override wins over the global switch
    s = s.copyWith(x: {'ghostRead': false, 'ghostParts': {'7:read': true}});
    expect(s.blocksRead(7), isTrue);
    expect(s.blocksRead(8), isFalse);

    // ghost off globally, but hidden chats are forced to ghost
    s = s.copyWith(ghostGlobal: false, hiddenChats: {9});
    expect(s.blocksTyping(9), isTrue);
    expect(s.blocksTyping(10), isFalse);
    expect(s.hidesOnline, isFalse);
  });

  test('hidden-chat options persist and never lock you out', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final s = AppSettings.load(p).copyWith(x: {
      'hiddenMethods': ['search', 'title'],
      'hiddenFolders': {'Work': [1, 2]},
    });
    await s.save(p);
    final back = AppSettings.load(p);
    expect(back.hiddenMethods, {'search', 'title'});
    expect(back.hiddenFolders['Work'], {1, 2});
    expect(back.hiddenAuth, isTrue);
    expect(back.titleMode, 0);
  });
}
