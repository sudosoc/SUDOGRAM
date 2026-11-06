import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/data/tdlib/td_gateway.dart';
import 'package:sudogram/data/tdlib/td_transport.dart';
import 'package:sudogram/domain/models.dart';

class FakeTransport implements TdTransport {
  final ctrl = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final sent = <Map<String, dynamic>>[];
  Map<String, dynamic> Function(Map<String, dynamic>)? onRequest;

  @override
  Stream<Map<String, dynamic>> get updates => ctrl.stream;

  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> req,
      {Duration timeout = const Duration(seconds: 60)}) async {
    sent.add(req);
    return onRequest?.call(req) ?? {'@type': 'ok'};
  }

  @override
  void fire(Map<String, dynamic> req) => sent.add(req);

  @override
  Future<void> close() async => ctrl.close();

  void push(Map<String, dynamic> u) => ctrl.add(u);
}

Map<String, dynamic> chat(int id, String title, String order, String text) => {
      '@type': 'updateNewChat',
      'chat': {
        'id': id.toString(),
        'title': title,
        'unread_count': 2,
        'positions': [
          {
            '@type': 'chatPosition',
            'list': {'@type': 'chatListMain'},
            'order': order,
          }
        ],
        'last_message': {
          'id': 10,
          'date': 1700000000,
          'content': {
            '@type': 'messageText',
            'text': {'text': text}
          },
        },
      }
    };

void main() {
  late FakeTransport t;
  late TdlibGateway g;

  setUp(() async {
    t = FakeTransport();
    g = TdlibGateway(
      transportFactory: () async => t,
      apiId: 1,
      apiHash: 'h',
      databaseDirectory: '/db',
      filesDirectory: '/files',
      chatListDebounce: Duration.zero,
    );
    await g.start();
  });

  tearDown(() => g.dispose());

  test('sends parameters then reaches ready', () async {
    final states = <AuthStep>[];
    g.authState.listen((s) => states.add(s.step));
    t.push({
      '@type': 'updateAuthorizationState',
      'authorization_state': {
        '@type': 'authorizationStateWaitTdlibParameters'
      }
    });
    expect(t.sent.last['@type'], 'setTdlibParameters');
    expect(t.sent.last['api_id'], 1);
    t.push({
      '@type': 'updateAuthorizationState',
      'authorization_state': {'@type': 'authorizationStateWaitPhoneNumber'}
    });
    t.push({
      '@type': 'updateAuthorizationState',
      'authorization_state': {'@type': 'authorizationStateReady'}
    });
    await Future<void>.delayed(Duration.zero);
    expect(states, containsAllInOrder([AuthStep.waitPhone, AuthStep.ready]));
    expect(t.sent.any((r) => r['@type'] == 'loadChats'), isTrue);
  });

  test('chat list is ordered by the order string (int64)', () async {
    t.push(chat(1, 'A', '100', 'a'));
    t.push(chat(2, 'B', '9000000000000000000', 'b'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final list = await g.watchChats().first;
    expect(list.map((c) => c.title), ['B', 'A']);
    expect(list.first.lastText, 'b');
    expect(list.first.unread, 2);
  });

  test('new message inserted; permanent delete keeps peer messages', () async {
    t.onRequest = (r) => {'@type': 'messages', 'messages': []};
    final seen = <List<ChatMessage>>[];
    final sub = g.watchMessages(5).listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    Map<String, dynamic> msg(int id, bool out) => {
          '@type': 'updateNewMessage',
          'message': {
            'id': id,
            'chat_id': '5',
            'is_outgoing': out,
            'date': 1700000000,
            'content': {
              '@type': 'messageText',
              'text': {'text': 'm$id'}
            },
          }
        };
    t.push(msg(1, false));
    t.push(msg(2, true));
    t.push({
      '@type': 'updateDeleteMessages',
      'chat_id': '5',
      'message_ids': [1, 2],
      'is_permanent': true,
      'from_cache': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final last = seen.last;
    expect(last.length, 1);
    expect(last.single.id, 1);
    expect(last.single.deletedByPeer, isTrue);
    await sub.cancel();
  });

  test('non-permanent delete (cache eviction) changes nothing', () async {
    t.onRequest = (r) => {'@type': 'messages', 'messages': []};
    final seen = <List<ChatMessage>>[];
    final sub = g.watchMessages(5).listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    t.push({
      '@type': 'updateNewMessage',
      'message': {
        'id': 1,
        'chat_id': '5',
        'is_outgoing': false,
        'date': 1,
        'content': {
          '@type': 'messageText',
          'text': {'text': 'x'}
        },
      }
    });
    t.push({
      '@type': 'updateDeleteMessages',
      'chat_id': '5',
      'message_ids': [1],
      'is_permanent': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(seen.last.single.deletedByPeer, isFalse);
    await sub.cancel();
  });

  test('never requests sponsored messages', () async {
    t.push(chat(1, 'A', '5', 'x'));
    await g.openChat(1);
    await g.sendText(1, 'hi');
    expect(
        t.sent.any((r) => r['@type'].toString().contains('Sponsored')), isFalse);
  });

  test('contact profile changes are reported', () async {
    final seen = <ContactChange>[];
    g.contactChanges().listen(seen.add);
    Map<String, dynamic> user(String first, String name) => {
          '@type': 'updateUser',
          'user': {
            'id': '9',
            'first_name': first,
            'last_name': '',
            'phone_number': '20100',
            'usernames': {
              'active_usernames': [name]
            },
          }
        };
    t.push(user('Ali', 'ali1'));
    expect(seen, isEmpty);
    t.push(user('Ali', 'ali2'));
    t.push(user('Ali K', 'ali2'));
    await Future<void>.delayed(Duration.zero);
    expect(seen.map((c) => c.field), ['username', 'name']);
    expect(seen.first.oldValue, 'ali1');
    expect(seen.first.newValue, 'ali2');
  });

  test('media: single item is a message, many become albums of 10', () async {
    await g.sendMedia(1, ['/a/x.jpg']);
    expect(t.sent.last['@type'], 'sendMessage');
    expect(t.sent.last['input_message_content']['photo']['photo']['@type'], 'inputFileLocal');
    expect(t.sent.last['input_message_content']['@type'], 'inputMessagePhoto');
    await g.sendMedia(1, ['/a/v.MP4']);
    expect(t.sent.last['input_message_content']['@type'], 'inputMessageVideo');
    expect(t.sent.last['input_message_content']['video']['supports_streaming'], isTrue);
    // TDLib wraps the file: inputPhoto{photo: InputFile}, inputVideo{video: InputFile}
    expect(t.sent.last['input_message_content']['video']['video']['@type'], 'inputFileLocal');

    t.sent.clear();
    await g.sendMedia(1, [for (var i = 0; i < 12; i++) i.isEven ? '/a/$i.jpg' : '/a/$i.mov'],
        caption: 'hi');
    final albums = t.sent.where((r) => r['@type'] == 'sendMessageAlbum').toList();
    expect(albums.length, 2);
    expect((albums[0]['input_message_contents'] as List).length, 10);
    expect((albums[1]['input_message_contents'] as List).length, 2);
    expect(albums[0]['input_message_contents'][0]['caption']['text'], 'hi');
    expect(albums[1]['input_message_contents'][0]['caption']['text'], '');
  });

  Map<String, dynamic> tmsg(int id, {bool out = false, int sender = 77, int reply = 0, String text = 't'}) => {
        '@type': 'updateNewMessage',
        'message': {
          'id': id,
          'chat_id': '5',
          'is_outgoing': out,
          'date': 1700000000 + id,
          'sender_id': {'@type': 'messageSenderUser', 'user_id': sender},
          if (reply != 0)
            'reply_to': {'@type': 'messageReplyToMessage', 'message_id': reply},
          'content': {
            '@type': 'messageText',
            'text': {'text': text}
          },
        }
      };

  test('chat type, mute, avatar, read ticks, sender names, replies', () async {
    t.onRequest = (r) => {'@type': 'messages', 'messages': []};
    t.push({
      '@type': 'updateNewChat',
      'chat': {
        'id': '5',
        'title': 'Group',
        'type': {'@type': 'chatTypeSupergroup', 'is_channel': false},
        'photo': {
          'small': {'id': 9, 'size': 10, 'local': {'path': '', 'is_downloading_completed': false}}
        },
        'notification_settings': {'mute_for': 100},
        'permissions': {'can_send_basic_messages': true},
        'last_read_outbox_message_id': 2,
        'positions': [
          {'list': {'@type': 'chatListMain'}, 'order': '7'}
        ],
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final c = (await g.watchChats().first).single;
    expect(c.type, ChatType.group);
    expect(c.muted, isTrue);
    expect(c.canSend, isTrue);
    expect(c.avatar!.fileId, 9);
    expect(t.sent.any((r) => r['@type'] == 'downloadFile' && r['file_id'] == 9), isTrue);

    final seen = <List<ChatMessage>>[];
    final sub = g.watchMessages(5).listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    t.push({
      '@type': 'updateUser',
      'user': {'id': '77', 'first_name': 'Sara', 'last_name': '', 'phone_number': ''}
    });
    t.push(tmsg(1, out: true));
    t.push(tmsg(3, out: true, reply: 1));
    t.push(tmsg(4));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    var l = seen.last;
    expect(l.firstWhere((m) => m.id == 4).senderName, 'Sara');
    expect(l.firstWhere((m) => m.id == 1).read, isTrue); // <= last read outbox
    expect(l.firstWhere((m) => m.id == 3).read, isFalse);
    expect(l.firstWhere((m) => m.id == 3).replyToId, 1);
    t.push({'@type': 'updateChatReadOutbox', 'chat_id': '5', 'last_read_outbox_message_id': 3});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(seen.last.firstWhere((m) => m.id == 3).read, isTrue);
    await sub.cancel();
  });

  test('typing and last seen status', () async {
    t.push({
      '@type': 'updateNewChat',
      'chat': {
        'id': '9',
        'title': 'Ali',
        'type': {'@type': 'chatTypePrivate', 'user_id': 9},
        'positions': [],
      }
    });
    final statuses = <ChatStatus>[];
    final sub = g.watchChatStatus(9).listen(statuses.add);
    await Future<void>.delayed(Duration.zero);
    t.push({'@type': 'updateUserStatus', 'user_id': 9, 'status': {'@type': 'userStatusOnline'}});
    t.push({
      '@type': 'updateChatAction',
      'chat_id': '9',
      'sender_id': {'@type': 'messageSenderUser', 'user_id': 9},
      'action': {'@type': 'chatActionTyping'}
    });
    await Future<void>.delayed(Duration.zero);
    expect(statuses.last.typing, isTrue);
    expect(statuses.last.seen, SeenKind.online);
    t.push({
      '@type': 'updateChatAction',
      'chat_id': '9',
      'sender_id': {'@type': 'messageSenderUser', 'user_id': 9},
      'action': {'@type': 'chatActionCancel'}
    });
    await Future<void>.delayed(Duration.zero);
    expect(statuses.last.typing, isFalse);
    await sub.cancel();
  });

  test('older history pages in, reply goes out, self-deleted incoming vanishes', () async {
    t.onRequest = (r) {
      if (r['@type'] == 'getChatHistory') {
        if (r['from_message_id'] == 0) {
          return {'@type': 'messages', 'messages': [
          (tmsg(10)['message']), (tmsg(11)['message'])
        ]};
        }
        return {'@type': 'messages', 'messages': [(tmsg(8)['message']), (tmsg(9)['message']), (tmsg(10)['message'])]};
      }
      return {'@type': 'ok'};
    };
    final seen = <List<ChatMessage>>[];
    final sub = g.watchMessages(5).listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await g.loadOlder(5), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.map((m) => m.id), [11, 10, 9, 8]);
    expect(t.sent.where((r) => r['@type'] == 'getChatHistory').last['from_message_id'], 10);
    t.onRequest = (r) => {'@type': 'messages', 'messages': []};
    expect(await g.loadOlder(5), isFalse);

    await g.sendText(5, 'yo', replyTo: 9);
    expect(t.sent.last['reply_to']['message_id'], 9);

    await g.deleteMessages(5, [9], forAll: true);
    t.push({'@type': 'updateDeleteMessages', 'chat_id': '5', 'message_ids': [9], 'is_permanent': true});
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.any((m) => m.id == 9), isFalse);
    expect(t.sent.last['revoke'], isTrue);
    await sub.cancel();
  });

  test('contacts, in-chat search and pinned message map through', () async {
    t.onRequest = (r) {
      switch (r['@type']) {
        case 'getContacts':
          return {'@type': 'users', 'user_ids': [5, 6]};
        case 'getUser':
          return {
            '@type': 'user',
            'id': r['user_id'],
            'first_name': r['user_id'] == 5 ? 'Zed' : 'Amr',
            'last_name': '',
          };
        case 'searchChatMessages':
          return {'@type': 'foundChatMessages', 'messages': [tmsg(3)['message'] ?? tmsg(3)]};
        case 'getChatPinnedMessage':
          return tmsg(4)['message'] as Map<String, dynamic>;
      }
      return {'@type': 'ok'};
    };
    final c = await g.contacts();
    expect(c.map((e) => e.title), ['Amr', 'Zed']);
    expect((await g.searchChat(1, 'x')).length, 1);
    expect((await g.searchChat(1, '  ')).length, 0);
    expect((await g.pinnedMessage(1))?.id, 4);
  });

  test('reactions parse and toggle; group info loads', () async {
    final sent = <String>[];
    t.onRequest = (r) {
      sent.add(r['@type'] as String);
      if (r['@type'] == 'getSupergroupFullInfo') {
        return {'@type': 'supergroupFullInfo', 'description': 'hi', 'member_count': 12};
      }
      return {'@type': 'ok'};
    };
    await g.toggleReaction(1, 2, '👍', on: true);
    await g.toggleReaction(1, 2, '👍', on: false);
    expect(sent, ['addMessageReaction', 'removeMessageReaction']);
    expect(await g.chatInfo(999), isNull); // unknown chat
  });

  test('polls, link previews, sessions and group creation map through', () async {
    t.onRequest = (r) {
      switch (r['@type']) {
        case 'getActiveSessions':
          return {'@type': 'sessions', 'sessions': [
            {'id': '9', 'application_name': 'X', 'device_model': 'Pixel', 'is_current': true, 'last_active_date': 1700000000}
          ]};
      }
      return {'@type': 'ok'};
    };
    final sent = <String>[];
    final prev = t.onRequest!;
    t.onRequest = (r) {
      sent.add(r['@type'] as String);
      return prev(r);
    };
    final s = await g.sessions();
    expect(s.single.current, isTrue);
    expect(s.single.id, 9);
    await g.votePoll(1, 2, [0]);
    await g.terminateSession(5);
    await g.setArchived(1, true);
    expect(sent, containsAll(['setPollAnswer', 'terminateSession', 'addChatToList']));

    List<ChatMessage> got = const [];
    final sub = g.watchMessages(5).listen((v) => got = v);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final base = tmsg(50)['message'] as Map<String, dynamic>;
    t.push({'@type': 'updateNewMessage', 'message': {
      ...base,
      'content': {'@type': 'messagePoll', 'poll': {
        'question': {'text': 'Q?'}, 'total_voter_count': 3,
        'options': [
          {'text': {'text': 'A'}, 'voter_count': 2, 'is_chosen': true},
          {'text': {'text': 'B'}, 'voter_count': 1, 'is_chosen': false},
        ],
        'type': {'@type': 'pollTypeRegular'},
      }},
    }});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final poll = got.firstWhere((m) => m.id == 50).poll!;
    expect(poll.question, 'Q?');
    expect(poll.options.first.chosen, isTrue);
    await sub.cancel();
  });

  test('privacy rules map both ways; mention search skips users without username', () async {
    final sent = <Map<String, dynamic>>[];
    t.onRequest = (r) {
      sent.add(r);
      switch (r['@type']) {
        case 'getUserPrivacySettingRules':
          return {'@type': 'userPrivacySettingRules', 'rules': [
            {'@type': 'userPrivacySettingRuleAllowContacts'}
          ]};
        case 'searchChatMembers':
          return {'@type': 'chatMembers', 'members': [
            {'member_id': {'@type': 'messageSenderUser', 'user_id': 1}},
            {'member_id': {'@type': 'messageSenderUser', 'user_id': 2}},
          ]};
        case 'getUser':
          return {
            '@type': 'user', 'id': r['user_id'], 'first_name': 'N${r['user_id']}',
            'usernames': r['user_id'] == 1 ? {'active_usernames': ['bob']} : {'active_usernames': []},
          };
      }
      return {'@type': 'ok'};
    };
    expect(await g.getPrivacy('seen'), 'contacts');
    await g.setPrivacy('seen', 'nobody');
    final set = sent.firstWhere((r) => r['@type'] == 'setUserPrivacySettingRules');
    expect(((set['rules'] as Map)['rules'] as List).single['@type'],
        'userPrivacySettingRuleRestrictAll');
    final m = await g.searchMembers(1, 'b');
    expect(m.map((e) => e.username), ['bob']);
  });

  test('profile, mute, voice and leave map to the right TDLib calls', () async {
    final sent = <Map<String, dynamic>>[];
    t.onRequest = (r) {
      sent.add(r);
      if (r['@type'] == 'getMe') {
        return {'@type': 'user', 'id': 9, 'first_name': 'Seif', 'last_name': 'A',
          'usernames': {'active_usernames': ['sudo']}, 'phone_number': '20100'};
      }
      return {'@type': 'ok'};
    };
    final me = await g.me();
    expect(me?.username, 'sudo');
    expect(me?.firstName, 'Seif');
    await g.updateProfile(firstName: 'S', lastName: 'B', bio: 'hi');
    await g.setMuted(5, true);
    await g.sendVoice(5, '/tmp/v.ogg', 3);
    await g.blockUser(5, true);
    final types = sent.map((r) => r['@type']).toList();
    expect(types, containsAll(['setName', 'setBio', 'setChatNotificationSettings',
        'sendMessage', 'setMessageSenderBlockList']));
    final voice = sent.firstWhere((r) => r['@type'] == 'sendMessage');
    expect((voice['input_message_content'] as Map)['@type'], 'inputMessageVoiceNote');
    expect(sent.firstWhere((r) => r['@type'] == 'setChatNotificationSettings')
        ['notification_settings']['mute_for'], greaterThan(0));
  });

  test('invite link, blocked list, global search, 2FA, stickers, members', () async {
    final sent = <Map<String, dynamic>>[];
    t.onRequest = (r) {
      sent.add(r);
      switch (r['@type']) {
        case 'joinChatByInviteLink':
          return {'@type': 'chatJoinResultSuccess', 'chat_id': 77};
        case 'getChat':
          return {'@type': 'chat', 'id': 77, 'title': 'Joined', 'type': {'@type': 'chatTypeBasicGroup', 'basic_group_id': 3}};
        case 'getBlockedMessageSenders':
          return {'@type': 'messageSenders', 'senders': [{'@type': 'messageSenderUser', 'user_id': 8}]};
        case 'getUser':
          return {'@type': 'user', 'id': r['user_id'], 'first_name': 'U${r['user_id']}'};
        case 'getPasswordState':
          return {'@type': 'passwordState', 'has_password': true};
        case 'getInstalledStickerSets':
          return {'@type': 'stickerSets', 'sets': [{'id': '5', 'title': 'Cats'}]};
        case 'getStickerSet':
          return {'@type': 'stickerSet', 'stickers': [
            {'emoji': '😺', 'sticker': {'id': 100}, 'thumbnail': {'file': {'id': 101}}}
          ]};
        case 'downloadFile':
          return {'@type': 'file', 'id': r['file_id'],
            'local': {'path': '/tmp/x.webp', 'is_downloading_completed': true}};
      }
      return {'@type': 'ok'};
    };
    final j = await g.joinByLink('https://t.me/+abc');
    expect(j?.title, 'Joined');
    expect(j?.type, ChatType.group);
    expect((await g.blockedUsers()).single.title, 'U8');
    expect(await g.hasCloudPassword(), isTrue);
    final sets = await g.stickerSets();
    expect(sets.single.title, 'Cats');
    final items = await g.stickerSetItems(sets.single.id);
    expect(items.single.fileId, 100);
    expect(await g.fetchFile(items.single.thumbFileId), '/tmp/x.webp');
    await g.sendSticker(5, items.single);
    final sticker = sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect((sticker['input_message_content'] as Map)['@type'], 'inputMessageSticker');
    expect(await g.setCloudPassword(oldPassword: 'a', newPassword: 'b'), isTrue);
  });

  test('poll, location, contact, gif and pin requests are well-formed', () async {
    final sent = <Map<String, dynamic>>[];
    t.onRequest = (r) {
      sent.add(r);
      if (r['@type'] == 'getSavedAnimations') {
        return {'@type': 'animations', 'animations': [
          {'animation': {'id': 40}, 'thumbnail': {'file': {'id': 41}}}
        ]};
      }
      return {'@type': 'ok'};
    };
    await g.sendPoll(5, 'Q', ['a', 'b'], multiple: true);
    await g.sendLocation(5, 30.1, 31.2);
    await g.sendContact(5, 9);
    final gifs = await g.savedGifs();
    await g.sendGif(5, gifs.single);
    await g.pinMessage(5, 3, pin: true);
    await g.pinMessage(5, 3, pin: false);
    String kind(int i) => (sent[i]['input_message_content'] as Map)['@type'] as String;
    expect(kind(0), 'inputMessagePoll');
    expect(kind(1), 'inputMessageLocation');
    expect(kind(2), 'inputMessageContact');
    expect(sent.map((r) => r['@type']), containsAll(['pinChatMessage', 'unpinChatMessage']));
    expect(gifs.single.gif, isTrue);
    final poll = sent[0]['input_message_content'] as Map;
    expect(poll['allows_multiple_answers'], isTrue);
    expect((poll['type'] as Map)['@type'], 'inputPollTypeRegular');
    expect((poll['options'] as List).length, 2);
  });

  test('failed sends are flagged and can be resent', () async {
    List<ChatMessage> got = const [];
    final sub = g.watchMessages(5).listen((v) => got = v);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final base = Map<String, dynamic>.from(tmsg(60)['message'] as Map<String, dynamic>);
    base['is_outgoing'] = true;
    base['sending_state'] = {'@type': 'messageSendingStateFailed'};
    t.push({'@type': 'updateMessageSendFailed', 'old_message_id': 59, 'message': base,
        'error': {'code': 400, 'message': 'x'}});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(got.firstWhere((m) => m.id == 60).sendState, 2);
    final sent = <String>[];
    t.onRequest = (r) {
      sent.add(r['@type'] as String);
      return {'@type': 'ok'};
    };
    await g.resend(5, 60);
    expect(sent, ['resendMessages']);
    await sub.cancel();
  });

  test('mark unread and scheduled text requests are well-formed', () async {
    final sent = <Map<String, dynamic>>[];
    t.onRequest = (r) {
      sent.add(r);
      if (r['@type'] == 'getChatScheduledMessages') {
        return {'@type': 'messages', 'total_count': 0, 'messages': []};
      }
      return {'@type': 'ok'};
    };
    await g.markUnread(5, true);
    await g.scheduleText(5, 'hi', DateTime.fromMillisecondsSinceEpoch(2000000000 * 1000));
    await g.scheduledMessages(5);
    expect(sent[0]['@type'], 'toggleChatIsMarkedAsUnread');
    expect(sent[0]['is_marked_as_unread'], isTrue);
    final opts = sent[1]['options'] as Map;
    final st = opts['scheduling_state'] as Map;
    expect(st['@type'], 'messageSchedulingStateSendAtDate');
    expect(st['send_date'], 2000000000);
    expect(sent[2]['@type'], 'getChatScheduledMessages');
  });

  test('shared contact becomes a card; around/shared-media requests', () async {
    List<ChatMessage> got = const [];
    final sub = g.watchMessages(5).listen((v) => got = v);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final m = Map<String, dynamic>.from(tmsg(70)['message'] as Map<String, dynamic>);
    m['content'] = {
      '@type': 'messageContact',
      'contact': {
        '@type': 'contact',
        'phone_number': '201001234567',
        'first_name': 'Ali',
        'last_name': 'Hassan',
        'user_id': 9,
      },
    };
    t.push({'@type': 'updateNewMessage', 'message': m});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final c = got.firstWhere((x) => x.id == 70).contact!;
    expect(c.name, 'Ali Hassan');
    expect(c.phone, '201001234567');
    expect(c.userId, 9);
    final back = ContactCard.parse(got.firstWhere((x) => x.id == 70).text)!;
    expect(back.name, 'Ali Hassan');
    expect(back.phone, '201001234567');

    final sent = <Map<String, dynamic>>[];
    t.onRequest = (r) {
      sent.add(r);
      return {'@type': 'messages', 'total_count': 0, 'messages': []};
    };
    await g.loadAround(5, 40);
    await g.sharedMedia(5, 'photo');
    expect(sent[0]['@type'], 'getChatHistory');
    expect(sent[0]['from_message_id'], 40);
    expect(sent[0]['offset'], lessThan(0));
    expect(sent[1]['@type'], 'searchChatMessages');
    expect((sent[1]['filter'] as Map)['@type'], 'searchMessagesFilterPhoto');
    await sub.cancel();
  });
}
