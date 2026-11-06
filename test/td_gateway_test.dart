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
    expect(t.sent.last['input_message_content']['@type'], 'inputMessagePhoto');
    await g.sendMedia(1, ['/a/v.MP4']);
    expect(t.sent.last['input_message_content']['@type'], 'inputMessageVideo');
    expect(t.sent.last['input_message_content']['supports_streaming'], isTrue);

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
}
