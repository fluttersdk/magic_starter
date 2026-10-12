import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> conversationJson({
  int id = 7,
  bool hasUnread = false,
  List<Map<String, dynamic>>? messages,
}) {
  return <String, dynamic>{
    'id': id,
    // The backend sends the display number as an integer.
    'number': id + 100,
    'subject': 'Cannot add a monitor',
    'source': 'help_page',
    'status': 'open',
    'priority': 'normal',
    'last_activity_at': '2026-10-12T09:30:00+00:00',
    'created_at': '2026-10-12T09:00:00+00:00',
    'has_unread': hasUnread,
    'messages': ?messages,
  };
}

Map<String, dynamic> messageJson({
  int id = 1,
  String senderType = 'customer',
  String body = 'Hello',
}) {
  return <String, dynamic>{
    'id': id,
    'sender_type': senderType,
    'body': body,
    'created_at': '2026-10-12T09:00:00+00:00',
  };
}

/// The route whose `fullPath` is [path], flat or inside a layout.
RouteDefinition? routeFor(String path) {
  for (final route in MagicRouter.instance.routes) {
    if (route.fullPath == path) return route;
  }

  for (final layout in MagicRouter.instance.mergedLayouts) {
    for (final route in layout.children) {
      if (route.fullPath == path) return route;
    }
  }

  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MagicStarterSupportController controller;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    setUpMagicStarterForTests();

    controller = MagicStarterSupportController();
  });

  tearDown(() {
    controller.dispose();
    Http.unfake();
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  group('MagicStarterSupportController', () {
    test('loadConversations reads the opener-only list', () async {
      final fake = Http.fake((request) {
        expect(request.method, 'GET');
        expect(request.url, '/support/conversations');

        return Http.response(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            conversationJson(id: 7, hasUnread: true),
            conversationJson(id: 8),
          ],
        });
      });

      await controller.loadConversations();

      fake.assertSentCount(1);
      expect(controller.listStatus, MagicStarterSupportReadStatus.loaded);
      expect(controller.conversations, hasLength(2));

      final first = controller.conversations.first;
      expect(first.id, 7);
      expect(first.number, 107);
      expect(first.subject, 'Cannot add a monitor');
      expect(first.source, 'help_page');
      expect(first.status, 'open');
      expect(first.priority, 'normal');
      expect(first.hasUnread, isTrue);
      expect(first.lastActivityAt, DateTime.utc(2026, 10, 12, 9, 30));
      expect(first.createdAt, DateTime.utc(2026, 10, 12, 9));
      expect(first.messages, isEmpty);
      expect(controller.conversations.last.hasUnread, isFalse);
    });

    test('loadConversations reports failed on a server error', () async {
      Http.fake((request) => Http.response(<String, dynamic>{}, 500));

      await controller.loadConversations();

      expect(controller.listStatus, MagicStarterSupportReadStatus.failed);
      expect(controller.conversations, isEmpty);
    });

    test('loadConversation reads the thread with its messages', () async {
      final fake = Http.fake((request) {
        expect(request.method, 'GET');
        expect(request.url, '/support/conversations/7');

        return Http.response(<String, dynamic>{
          'data': conversationJson(
            messages: <Map<String, dynamic>>[
              messageJson(id: 1),
              messageJson(id: 2, senderType: 'staff', body: 'On it'),
            ],
          ),
        });
      });

      await controller.loadConversation(7);

      fake.assertSentCount(1);
      expect(controller.threadStatus, MagicStarterSupportReadStatus.loaded);
      expect(controller.conversation!.id, 7);
      expect(controller.conversation!.messages, hasLength(2));
      expect(controller.conversation!.messages.last.senderType, 'staff');
      expect(controller.conversation!.messages.last.body, 'On it');
    });

    test(
      'a slower answer for an earlier thread never replaces a newer one',
      () async {
        // Open A, go back before it loads, open B. A answering last must not
        // put A's messages on B's page, where the composer posts to B.
        final answerA = Completer<MagicResponse>();
        // `async`, so the handler's type is a FakeRequestHandler: `Http.fake`
        // takes `dynamic`, and a closure returning a Future on one branch and a
        // response on the other infers as returning Object and is ignored.
        Http.fake((MagicRequest request) async {
          if (request.url == '/support/conversations/1') return answerA.future;

          return Http.response(<String, dynamic>{
            'data': conversationJson(id: 2),
          });
        });

        final readA = controller.loadConversation(1);
        await controller.loadConversation(2);
        answerA.complete(
          Http.response(<String, dynamic>{'data': conversationJson(id: 1)}),
        );
        await readA;

        expect(controller.threadStatus, MagicStarterSupportReadStatus.loaded);
        expect(controller.conversation!.id, 2);
      },
    );

    test('a 404 for an earlier thread leaves the newer one standing', () async {
      final answerA = Completer<MagicResponse>();
      Http.fake((MagicRequest request) async {
        if (request.url == '/support/conversations/1') return answerA.future;

        return Http.response(<String, dynamic>{
          'data': conversationJson(id: 2),
        });
      });

      final readA = controller.loadConversation(1);
      await controller.loadConversation(2);
      answerA.complete(Http.response(<String, dynamic>{}, 404));
      await readA;

      expect(controller.threadStatus, MagicStarterSupportReadStatus.loaded);
      expect(controller.conversation!.id, 2);
    });

    test('createConversation sends subject, body and source only', () async {
      final fake = Http.fake((request) {
        expect(request.method, 'POST');
        expect(request.url, '/support/conversations');
        expect(request.data, <String, dynamic>{
          'subject': 'Cannot add a monitor',
          'body': 'It says the limit is reached',
          'source': 'help_page',
        });

        return Http.response(<String, dynamic>{
          'data': conversationJson(
            messages: <Map<String, dynamic>>[messageJson()],
          ),
        }, 201);
      });

      final created = await controller.createConversation(
        subject: 'Cannot add a monitor',
        body: 'It says the limit is reached',
        source: 'help_page',
      );

      fake.assertSentCount(1);
      expect(created, isNotNull);
      expect(created!.id, 7);
    });

    test(
      'createConversation answers null and keeps the field errors',
      () async {
        Http.fake((request) {
          return Http.response(<String, dynamic>{
            'message': 'The subject field is required.',
            'errors': <String, dynamic>{
              'subject': <String>['The subject field is required.'],
            },
          }, 422);
        });

        final created = await controller.createConversation(
          subject: '',
          body: 'x',
          source: 'help_page',
        );

        expect(created, isNull);
        expect(
          controller.getError('subject'),
          'The subject field is required.',
        );
      },
    );

    test('sendMessage posts the body to the thread and appends it', () async {
      Http.fake((request) {
        if (request.method == 'GET') {
          return Http.response(<String, dynamic>{
            'data': conversationJson(
              messages: <Map<String, dynamic>>[messageJson(id: 1)],
            ),
          });
        }

        expect(request.method, 'POST');
        expect(request.url, '/support/conversations/7/messages');
        expect(request.data, <String, dynamic>{'body': 'Any update?'});

        return Http.response(<String, dynamic>{
          'data': messageJson(id: 2, body: 'Any update?'),
        }, 201);
      });

      await controller.loadConversation(7);
      final sent = await controller.sendMessage(7, 'Any update?');

      expect(sent, isTrue);
      expect(controller.conversation!.messages, hasLength(2));
      expect(controller.conversation!.messages.last.body, 'Any update?');
    });

    test('markSeen posts to the seen endpoint with no body', () async {
      final fake = Http.fake((request) {
        expect(request.method, 'POST');
        expect(request.url, '/support/conversations/7/seen');
        expect(request.data, isNull);

        return Http.response(<String, dynamic>{});
      });

      final seen = await controller.markSeen(7);

      fake.assertSentCount(1);
      expect(seen, isTrue);
    });

    test('a 404 resolves to not-found and is never retried', () async {
      final fake = Http.fake((request) {
        return Http.response(<String, dynamic>{'message': ''}, 404);
      });

      await controller.loadConversation(99);

      expect(controller.threadStatus, MagicStarterSupportReadStatus.notFound);
      expect(controller.conversation, isNull);
      fake.assertSentCount(1);
    });

    test('a 404 on a reply also resolves the thread to not-found', () async {
      final fake = Http.fake((request) {
        return Http.response(<String, dynamic>{'message': ''}, 404);
      });

      final sent = await controller.sendMessage(99, 'hello');

      expect(sent, isFalse);
      expect(controller.threadStatus, MagicStarterSupportReadStatus.notFound);
      fake.assertSentCount(1);
    });

    test('resetForSession drops the previous session rows', () async {
      Http.fake((request) {
        return Http.response(<String, dynamic>{
          'data': <Map<String, dynamic>>[conversationJson()],
        });
      });

      await controller.loadConversations();
      expect(controller.conversations, isNotEmpty);

      Http.fake((request) => Http.response(<String, dynamic>{}, 500));
      await controller.resetForSession();

      expect(controller.conversations, isEmpty);
      expect(controller.conversation, isNull);
      expect(controller.listStatus, MagicStarterSupportReadStatus.failed);
    });
  });

  group('registerMagicStarterSupportRoutes', () {
    test('has the feature off by default', () {
      expect(MagicStarterConfig.hasSupportFeatures(), isFalse);
    });

    test('registers nothing when the feature is off', () {
      Config.set('magic_starter.features.support', false);

      registerMagicStarterSupportRoutes();

      expect(routeFor('/support'), isNull);
      expect(routeFor('/support/new'), isNull);
      expect(routeFor('/support/:id'), isNull);
    });

    test('registers the three pages through the view registry', () {
      Config.set('magic_starter.features.support', true);
      MagicStarter.view
        ..register('support.index', () => const Text('index'))
        ..register('support.create', () => const Text('create'))
        ..register('support.thread', () => const Text('thread'));

      registerMagicStarterSupportRoutes();

      final expected = <String, String>{
        '/support': 'index',
        '/support/new': 'create',
        '/support/:id': 'thread',
      };

      for (final entry in expected.entries) {
        final route = routeFor(entry.key);
        expect(route, isNotNull, reason: '${entry.key} is not registered');

        final widget = Function.apply(route!.handler, const <Object>[]);
        expect((widget as Text).data, entry.value);
      }
    });
  });
}
