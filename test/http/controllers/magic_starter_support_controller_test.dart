import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> conversationJson({
  int id = 7,
  String status = 'open',
  bool hasUnread = false,
  bool awaitingAi = false,
  Map<String, dynamic>? lastMessage,
  List<Map<String, dynamic>>? messages,
}) {
  return <String, dynamic>{
    'id': id,
    // The backend sends the display number as an integer.
    'number': id + 100,
    'subject': 'Cannot add a monitor',
    'source': 'help_page',
    'status': status,
    'priority': 'normal',
    'last_activity_at': '2026-10-12T09:30:00+00:00',
    'created_at': '2026-10-12T09:00:00+00:00',
    'has_unread': hasUnread,
    'topic': 'technical',
    'awaiting_ai': awaitingAi,
    'waiting_on_team': false,
    'last_message': ?lastMessage,
    'messages': ?messages,
  };
}

/// One page of the Laravel resource collection the index answers with.
Map<String, dynamic> pageJson(
  List<Map<String, dynamic>> rows, {
  required int page,
  required int lastPage,
}) {
  return <String, dynamic>{
    'data': rows,
    'links': <String, dynamic>{'next': null},
    'meta': <String, dynamic>{
      'current_page': page,
      'last_page': lastPage,
      'per_page': 2,
      'total': lastPage * 2,
    },
  };
}

Map<String, dynamic> messageJson({
  int id = 1,
  String senderType = 'customer',
  String body = 'Hello',
  Map<String, dynamic>? sender,
}) {
  return <String, dynamic>{
    'id': id,
    'sender_type': senderType,
    'kind': 'message',
    'sender': sender,
    'body': body,
    'created_at': '2026-10-12T09:00:00+00:00',
  };
}

Map<String, dynamic> attachmentJson({
  String id = 'a1',
  String name = 'error.png',
  String mime = 'image/png',
  String kind = 'image',
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'mime': mime,
    'size': 2048,
    'width': kind == 'image' ? 640 : null,
    'height': kind == 'image' ? 480 : null,
    'kind': kind,
    'url': 'support/conversations/7/attachments/$id',
  };
}

/// A picked file, as `Pick` would hand it over. [size] stays null when the
/// picker could not read it, which is the case the client check must cover.
MagicFile pickedFile(
  String name, {
  String? mimeType,
  int? size,
  int bytes = 16,
}) {
  return MagicFile(
    name: name,
    size: size,
    mimeType: mimeType,
    bytes: Uint8List(bytes),
  );
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
    test('loadConversations reads page 1 of the opener-only list', () async {
      final fake = Http.fake((request) {
        expect(request.method, 'GET');
        expect(request.url, '/support/conversations');
        expect(request.queryParameters?['page'], 1);
        expect(request.queryParameters, contains('per_page'));

        return Http.response(
          pageJson(
            <Map<String, dynamic>>[
              conversationJson(
                id: 7,
                hasUnread: true,
                lastMessage: <String, dynamic>{
                  'sender_type': 'staff',
                  'sender_name': 'Ayse',
                  'body_preview': 'On it',
                  'created_at': '2026-10-12T09:30:00+00:00',
                },
              ),
              conversationJson(id: 8),
            ],
            page: 1,
            lastPage: 1,
          ),
        );
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
      expect(first.topic, 'technical');
      expect(first.lastMessage!.senderName, 'Ayse');
      expect(first.lastMessage!.bodyPreview, 'On it');
      expect(controller.conversations.last.hasUnread, isFalse);
      expect(controller.conversations.last.lastMessage, isNull);
      expect(controller.hasMoreConversations, isFalse);
    });

    test(
      'loadMoreConversations appends page 2 and stops at last_page',
      () async {
        final fake = Http.fake((request) {
          final page = request.queryParameters?['page'];

          return Http.response(switch (page) {
            1 => pageJson(
              <Map<String, dynamic>>[
                conversationJson(id: 1),
                conversationJson(id: 2),
              ],
              page: 1,
              lastPage: 2,
            ),
            _ => pageJson(
              <Map<String, dynamic>>[conversationJson(id: 3)],
              page: 2,
              lastPage: 2,
            ),
          });
        });

        await controller.loadConversations();
        expect(controller.hasMoreConversations, isTrue);

        await controller.loadMoreConversations();

        expect(controller.conversations.map((c) => c.id), <dynamic>[1, 2, 3]);
        expect(controller.hasMoreConversations, isFalse);

        await controller.loadMoreConversations();

        fake.assertSentCount(2);
        expect(controller.conversations, hasLength(3));
      },
    );

    test('loadMoreConversations skips a row it already holds', () async {
      Http.fake((request) {
        return Http.response(switch (request.queryParameters?['page']) {
          1 => pageJson(
            <Map<String, dynamic>>[
              conversationJson(id: 1),
              conversationJson(id: 2),
            ],
            page: 1,
            lastPage: 2,
          ),
          _ => pageJson(
            <Map<String, dynamic>>[
              // New activity pushed id 2 onto the next page too.
              conversationJson(id: 2),
              conversationJson(id: 3),
            ],
            page: 2,
            lastPage: 2,
          ),
        });
      });

      await controller.loadConversations();
      await controller.loadMoreConversations();

      expect(controller.conversations.map((c) => c.id), <dynamic>[1, 2, 3]);
    });

    test('a refresh keeps the pages Load more already read', () async {
      final requested = <Object?>[];
      Http.fake((request) {
        final page = request.queryParameters?['page'];
        requested.add(page);

        return Http.response(switch (page) {
          1 => pageJson(
            <Map<String, dynamic>>[
              conversationJson(id: 1),
              conversationJson(id: 2),
            ],
            page: 1,
            lastPage: 3,
          ),
          2 => pageJson(
            <Map<String, dynamic>>[
              conversationJson(id: 3),
              conversationJson(id: 4),
            ],
            page: 2,
            lastPage: 3,
          ),
          _ => pageJson(
            <Map<String, dynamic>>[conversationJson(id: 5)],
            page: 3,
            lastPage: 3,
          ),
        });
      });

      await controller.loadConversations();
      await controller.loadMoreConversations();
      requested.clear();

      // The 30 second poll and the thread's own refresh both land here.
      await controller.loadConversations();

      expect(controller.conversations.map((c) => c.id), <dynamic>[
        1,
        2,
        3,
        4,
      ], reason: 'page 2 must survive a refresh');
      expect(requested, <Object?>[1, 2]);
      expect(controller.hasMoreConversations, isTrue);

      await controller.loadMoreConversations();

      expect(controller.conversations.map((c) => c.id), <dynamic>[
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(controller.hasMoreConversations, isFalse);
    });

    test('more pages stay announced while a refresh is in flight', () async {
      // The 30 second poll rereads with the rows on screen; reading "no more
      // pages" off the read status hid Load more and let an empty tab claim
      // "no conversations" every 30 seconds.
      Http.fake((request) {
        final page = request.queryParameters?['page'];

        return Http.response(
          pageJson(
            <Map<String, dynamic>>[conversationJson(id: page == 1 ? 1 : 2)],
            page: page == 1 ? 1 : 2,
            lastPage: 3,
          ),
        );
      });

      await controller.loadConversations();
      await controller.loadMoreConversations();

      final Future<void> refresh = controller.loadConversations();

      expect(controller.listStatus, MagicStarterSupportReadStatus.loading);
      expect(controller.hasMoreConversations, isTrue);

      // A tap landing mid-reread waits for the next one instead of racing it.
      await controller.loadMoreConversations();
      await refresh;

      expect(controller.conversations.map((c) => c.id), <dynamic>[1, 2]);
      expect(controller.hasMoreConversations, isTrue);
    });

    test(
      'a refresh stops at the last page the backend still reports',
      () async {
        var lastPage = 2;
        final requested = <Object?>[];
        Http.fake((request) {
          final page = request.queryParameters?['page'];
          requested.add(page);

          return Http.response(switch (page) {
            1 => pageJson(
              <Map<String, dynamic>>[conversationJson(id: 1)],
              page: 1,
              lastPage: lastPage,
            ),
            _ => pageJson(
              <Map<String, dynamic>>[conversationJson(id: 2)],
              page: 2,
              lastPage: lastPage,
            ),
          });
        });

        await controller.loadConversations();
        await controller.loadMoreConversations();

        // A conversation was deleted: page 2 no longer exists.
        lastPage = 1;
        requested.clear();
        await controller.loadConversations();

        expect(requested, <Object?>[1]);
        expect(controller.conversations.map((c) => c.id), <dynamic>[1]);
        expect(controller.hasMoreConversations, isFalse);
      },
    );

    test('a refresh that fails on a later page keeps every row', () async {
      var failPage2 = false;
      Http.fake((request) {
        final page = request.queryParameters?['page'];
        if (page == 2 && failPage2) {
          return Http.response(<String, dynamic>{}, 500);
        }

        return Http.response(switch (page) {
          1 => pageJson(
            <Map<String, dynamic>>[conversationJson(id: 1)],
            page: 1,
            lastPage: 2,
          ),
          _ => pageJson(
            <Map<String, dynamic>>[conversationJson(id: 2)],
            page: 2,
            lastPage: 2,
          ),
        });
      });

      await controller.loadConversations();
      await controller.loadMoreConversations();

      failPage2 = true;
      await controller.loadConversations();

      expect(controller.listStatus, MagicStarterSupportReadStatus.failed);
      expect(controller.conversations.map((c) => c.id), <dynamic>[1, 2]);
    });

    test('loadMoreConversations keeps the rows when the page fails', () async {
      final logs = Log.fake();
      addTearDown(Log.unfake);
      Http.fake((request) {
        if (request.queryParameters?['page'] == 1) {
          return Http.response(
            pageJson(
              <Map<String, dynamic>>[conversationJson(id: 1)],
              page: 1,
              lastPage: 2,
            ),
          );
        }

        return Http.response(<String, dynamic>{}, 500);
      });

      await controller.loadConversations();
      await controller.loadMoreConversations();

      expect(controller.listStatus, MagicStarterSupportReadStatus.loaded);
      expect(controller.conversations, hasLength(1));
      expect(controller.hasMoreConversations, isTrue);
      expect(controller.isLoadingMoreConversations, isFalse);
      expect(
        logs.entries.where(
          (e) =>
              e.level == 'warning' &&
              e.message.contains('loadMoreConversations'),
        ),
        hasLength(1),
      );
    });

    test(
      'a page that answers after the list was reloaded is dropped',
      () async {
        final page2 = Completer<MagicResponse>();
        Http.fake((MagicRequest request) async {
          if (request.queryParameters?['page'] == 2) return page2.future;

          return Http.response(
            pageJson(
              <Map<String, dynamic>>[conversationJson(id: 1)],
              page: 1,
              lastPage: 2,
            ),
          );
        });

        await controller.loadConversations();
        final more = controller.loadMoreConversations();
        await controller.loadConversations();
        page2.complete(
          Http.response(
            pageJson(
              <Map<String, dynamic>>[conversationJson(id: 9)],
              page: 2,
              lastPage: 2,
            ),
          ),
        );
        await more;

        expect(controller.conversations.map((c) => c.id), <dynamic>[1]);
        expect(controller.hasMoreConversations, isTrue);
      },
    );

    test('a page that answers after a session reset is dropped', () async {
      final page2 = Completer<MagicResponse>();
      Http.fake((MagicRequest request) async {
        if (request.queryParameters?['page'] == 2) return page2.future;

        return Http.response(
          pageJson(
            <Map<String, dynamic>>[conversationJson(id: 1)],
            page: 1,
            lastPage: 2,
          ),
        );
      });

      await controller.loadConversations();
      final more = controller.loadMoreConversations();

      Http.fake((request) => Http.response(<String, dynamic>{}, 500));
      await controller.resetForSession();
      page2.complete(
        Http.response(
          pageJson(
            <Map<String, dynamic>>[conversationJson(id: 9)],
            page: 2,
            lastPage: 2,
          ),
        ),
      );
      await more;

      expect(controller.conversations, isEmpty);
      expect(controller.hasMoreConversations, isFalse);
    });

    test('loadMoreConversations is a no-op before the first page', () async {
      final fake = Http.fake((request) => Http.response(<String, dynamic>{}));

      await controller.loadMoreConversations();

      fake.assertNothingSent();
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
              messageJson(
                id: 2,
                senderType: 'staff',
                body: 'On it',
                sender: <String, dynamic>{
                  'name': 'Ayse',
                  'avatar_url': 'https://cdn.example.com/a.png',
                },
              ),
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
      expect(controller.conversation!.messages.last.senderName, 'Ayse');
      expect(controller.conversation!.messages.last.kind, 'message');
    });

    test('isAwaitingAi follows the open thread', () async {
      expect(controller.isAwaitingAi, isFalse);

      Http.fake((request) {
        return Http.response(<String, dynamic>{
          'data': conversationJson(awaitingAi: true),
        });
      });

      await controller.loadConversation(7);

      expect(controller.isAwaitingAi, isTrue);

      Http.fake((request) {
        return Http.response(<String, dynamic>{'data': conversationJson()});
      });

      await controller.loadConversation(7);

      expect(controller.isAwaitingAi, isFalse);
    });

    test('topics fall back to the five defaults', () {
      expect(controller.topics, <String>[
        'billing',
        'technical',
        'account',
        'sales',
        'other',
      ]);
    });

    test('topics follow magic_starter.support.topics', () {
      Config.set('magic_starter.support.topics', <String>['billing', 'other']);

      expect(controller.topics, <String>['billing', 'other']);
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

    test(
      'createConversation sends topic, body and source, no subject',
      () async {
        final fake = Http.fake((request) {
          expect(request.method, 'POST');
          expect(request.url, '/support/conversations');
          expect(request.data, <String, dynamic>{
            'topic': 'technical',
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
          topic: 'technical',
          body: 'It says the limit is reached',
          source: 'help_page',
        );

        fake.assertSentCount(1);
        expect(created, isNotNull);
        expect(created!.id, 7);
      },
    );

    test(
      'createConversation sends an explicit subject when given one',
      () async {
        Http.fake((request) {
          expect(request.data, <String, dynamic>{
            'subject': 'Contact sales: Enterprise',
            'body': 'Hello',
            'source': 'contact_sales',
          });

          return Http.response(<String, dynamic>{
            'data': conversationJson(),
          }, 201);
        });

        final created = await controller.createConversation(
          subject: 'Contact sales: Enterprise',
          body: 'Hello',
          source: 'contact_sales',
        );

        expect(created, isNotNull);
      },
    );

    test(
      'createConversation answers null and keeps the field errors',
      () async {
        Http.fake((request) {
          return Http.response(<String, dynamic>{
            'message': 'The body field is required.',
            'errors': <String, dynamic>{
              'body': <String>['The body field is required.'],
            },
          }, 422);
        });

        final created = await controller.createConversation(
          topic: 'other',
          body: '',
          source: 'help_page',
        );

        expect(created, isNull);
        expect(controller.getError('body'), 'The body field is required.');
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

    test('a reply on a pending thread puts the AI back on the clock', () async {
      Http.fake((request) {
        if (request.method == 'GET') {
          return Http.response(<String, dynamic>{
            'data': conversationJson(
              status: 'pending',
              messages: <Map<String, dynamic>>[
                messageJson(id: 1),
                messageJson(id: 2, senderType: 'ai', body: 'First answer'),
              ],
            ),
          });
        }

        return Http.response(<String, dynamic>{
          'data': messageJson(id: 3, body: 'And another thing'),
        }, 201);
      });

      await controller.loadConversation(7);
      expect(controller.isAwaitingAi, isFalse);

      await controller.sendMessage(7, 'And another thing');

      expect(
        controller.isAwaitingAi,
        isTrue,
        reason: 'the typing bubble must not wait for the next refetch',
      );
    });

    test('a reply on an open thread leaves the AI out of it', () async {
      Http.fake((request) {
        if (request.method == 'GET') {
          return Http.response(<String, dynamic>{
            'data': conversationJson(
              messages: <Map<String, dynamic>>[messageJson(id: 1)],
            ),
          });
        }

        return Http.response(<String, dynamic>{
          'data': messageJson(id: 2, body: 'Any update?'),
        }, 201);
      });

      await controller.loadConversation(7);
      await controller.sendMessage(7, 'Any update?');

      expect(controller.isAwaitingAi, isFalse);
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

  group('MagicStarterSupportController attachments and diagnostics', () {
    test('createConversation with files uploads one part per file', () async {
      final first = pickedFile('error.png', mimeType: 'image/png');
      final second = pickedFile('invoice.pdf', mimeType: 'application/pdf');
      final screenshot = pickedFile('screenshot.png', mimeType: 'image/png');

      final fake = Http.fake((request) {
        expect(request.method, 'POST');
        expect(request.url, '/support/conversations');
        expect(request.data['body'], 'See the attachment');
        expect(request.data['source'], 'in_app');
        expect(request.data['attachments[0]'], same(first));
        expect(request.data['attachments[1]'], same(second));
        expect(request.data['screenshot'], same(screenshot));
        expect(request.data['client_context[route]'], '/monitors');
        expect(request.data['client_context[app_version]'], '1.4.0');
        expect(request.data, isNot(contains('attachments')));
        expect(request.data, isNot(contains('client_context')));

        return Http.response(<String, dynamic>{
          'data': conversationJson(),
        }, 201);
      });

      final created = await controller.createConversation(
        body: 'See the attachment',
        source: 'in_app',
        attachments: <MagicFile>[first, second],
        screenshot: screenshot,
        clientContext: <String, String>{
          'route': '/monitors',
          'app_version': '1.4.0',
        },
      );

      fake.assertSentCount(1);
      expect(created, isNotNull);
    });

    test('createConversation without files keeps the JSON body', () async {
      Http.fake((request) {
        expect(request.data, <String, dynamic>{
          'body': 'Hello',
          'source': 'in_app',
          'client_context': <String, String>{'route': '/monitors'},
        });

        return Http.response(<String, dynamic>{
          'data': conversationJson(),
        }, 201);
      });

      final created = await controller.createConversation(
        body: 'Hello',
        source: 'in_app',
        clientContext: <String, String>{'route': '/monitors'},
      );

      expect(created, isNotNull);
    });

    test('a screenshot alone is enough to take the upload path', () async {
      final screenshot = pickedFile('screenshot.png', mimeType: 'image/png');

      Http.fake((request) {
        expect(request.data['screenshot'], same(screenshot));
        expect(request.data, isNot(contains('attachments[0]')));

        return Http.response(<String, dynamic>{
          'data': conversationJson(),
        }, 201);
      });

      final created = await controller.createConversation(
        body: 'Hello',
        source: 'in_app',
        screenshot: screenshot,
      );

      expect(created, isNotNull);
    });

    test('sendMessage with files omits an empty body and appends the '
        'message with its attachments', () async {
      final photo = pickedFile('error.png', mimeType: 'image/png');

      Http.fake((request) {
        if (request.method == 'GET') {
          return Http.response(<String, dynamic>{
            'data': conversationJson(
              messages: <Map<String, dynamic>>[messageJson(id: 1)],
            ),
          });
        }

        expect(request.url, '/support/conversations/7/messages');
        expect(request.data['attachments[0]'], same(photo));
        expect(request.data, isNot(contains('body')));
        expect(request.data, isNot(contains('screenshot')));

        return Http.response(<String, dynamic>{
          'data': <String, dynamic>{
            ...messageJson(id: 2, body: ''),
            'attachments': <Map<String, dynamic>>[attachmentJson()],
          },
        }, 201);
      });

      await controller.loadConversation(7);
      final sent = await controller.sendMessage(
        7,
        '',
        attachments: <MagicFile>[photo],
      );

      expect(sent, isTrue);

      final attachment = controller.conversation!.messages.last.attachments;
      expect(attachment, hasLength(1));
      expect(attachment.single.name, 'error.png');
      expect(attachment.single.url, 'support/conversations/7/attachments/a1');
    });

    test('sendMessage with files keeps a typed body', () async {
      Http.fake((request) {
        expect(request.data['body'], 'Here it is');
        expect(request.data, contains('attachments[0]'));

        return Http.response(<String, dynamic>{
          'data': messageJson(id: 2, body: 'Here it is'),
        }, 201);
      });

      final sent = await controller.sendMessage(
        7,
        'Here it is',
        attachments: <MagicFile>[pickedFile('a.pdf')],
      );

      expect(sent, isTrue);
    });

    test('a send without files stays JSON', () async {
      Http.fake((request) {
        expect(request.data, <String, dynamic>{'body': 'Any update?'});

        return Http.response(<String, dynamic>{
          'data': messageJson(id: 2, body: 'Any update?'),
        }, 201);
      });

      expect(await controller.sendMessage(7, 'Any update?'), isTrue);
    });

    test('refuses more files than the limit before any request', () async {
      final fake = Http.fake((request) => Http.response());

      final sent = await controller.sendMessage(
        7,
        'Four',
        attachments: <MagicFile>[
          for (var i = 0; i < 4; i++) pickedFile('a$i.png'),
        ],
      );

      expect(sent, isFalse);
      expect(controller.writeError, isNotNull);
      fake.assertNothingSent();
    });

    test('refuses an extension outside the allowed list', () async {
      final fake = Http.fake((request) => Http.response());

      final created = await controller.createConversation(
        body: 'Hello',
        source: 'in_app',
        attachments: <MagicFile>[pickedFile('payload.svg')],
      );

      expect(created, isNull);
      expect(controller.writeError, isNotNull);
      fake.assertNothingSent();
    });

    test('refuses a file over the size limit', () async {
      final fake = Http.fake((request) => Http.response());

      final sent = await controller.sendMessage(
        7,
        'Big',
        attachments: <MagicFile>[
          pickedFile('big.png', size: 5 * 1024 * 1024 + 1),
        ],
      );

      expect(sent, isFalse);
      expect(controller.writeError, isNotNull);
      fake.assertNothingSent();
    });

    test('reads the byte length when the picker reported no size', () async {
      final fake = Http.fake((request) => Http.response());

      // Neither a null size nor a zero one is a measurement (MagicFile.size).
      for (final unknown in <int?>[null, 0]) {
        final sent = await controller.sendMessage(
          7,
          'Big',
          attachments: <MagicFile>[
            pickedFile('big.png', size: unknown, bytes: 5 * 1024 * 1024 + 1),
          ],
        );

        expect(sent, isFalse, reason: 'size $unknown must fall back to bytes');
      }

      fake.assertNothingSent();
    });

    test('an unmeasured file under the limit is sent', () async {
      Http.fake((request) {
        return Http.response(<String, dynamic>{
          'data': messageJson(id: 2, body: 'Small'),
        }, 201);
      });

      final sent = await controller.sendMessage(
        7,
        'Small',
        attachments: <MagicFile>[pickedFile('small.JPG', bytes: 1024)],
      );

      expect(sent, isTrue);
      expect(controller.writeError, isNull);
    });

    test('matches a host extension list written in upper case', () async {
      Config.set('magic_starter.support.attachments.extensions', <String>[
        'PNG',
      ]);
      Http.fake((request) {
        return Http.response(<String, dynamic>{
          'data': messageJson(id: 2, body: 'Shot'),
        }, 201);
      });

      final sent = await controller.sendMessage(
        7,
        'Shot',
        attachments: <MagicFile>[pickedFile('shot.png', bytes: 1024)],
      );

      expect(sent, isTrue);
      expect(controller.writeError, isNull);
    });

    test('rate posts the rating and the comment', () async {
      Http.fake((request) {
        if (request.method == 'GET') {
          return Http.response(<String, dynamic>{
            'data': <String, dynamic>{
              ...conversationJson(status: 'resolved'),
              'can_rate': true,
              'rating': null,
            },
          });
        }

        expect(request.method, 'POST');
        expect(request.url, '/support/conversations/7/rating');
        expect(request.data, <String, dynamic>{
          'rating': 'down',
          'comment': 'Still broken',
        });

        return Http.response(<String, dynamic>{});
      });

      await controller.loadConversation(7);
      expect(controller.conversation!.canRate, isTrue);

      final rated = await controller.rate(7, 'down', comment: 'Still broken');

      expect(rated, isTrue);
      expect(controller.conversation!.canRate, isFalse);
      expect(controller.conversation!.rating!.value, 'down');
      expect(controller.conversation!.rating!.comment, 'Still broken');
    });

    test('rate leaves the comment out when there is none', () async {
      Http.fake((request) {
        expect(request.data, <String, dynamic>{'rating': 'up'});

        return Http.response(<String, dynamic>{});
      });

      expect(await controller.rate(7, 'up'), isTrue);
    });

    test('a 422 on rating surfaces as an error, not a throw', () async {
      Http.fake((request) {
        return Http.response(<String, dynamic>{
          'message': 'The conversation is not resolved.',
          'errors': <String, dynamic>{
            'rating': <String>['The conversation is not resolved.'],
          },
        }, 422);
      });

      final rated = await controller.rate(7, 'up');

      expect(rated, isFalse);
      expect(
        controller.getError('rating'),
        'The conversation is not resolved.',
      );
    });

    test('a 404 on rating resolves the thread to not-found', () async {
      Http.fake((request) => Http.response(<String, dynamic>{}, 404));

      expect(await controller.rate(99, 'up'), isFalse);
      expect(controller.threadStatus, MagicStarterSupportReadStatus.notFound);
    });

    test('attachmentHeaders carries the bearer token', () async {
      Auth.fake();
      addTearDown(Auth.unfake);
      await Auth.login(<String, dynamic>{
        'token': 'abc123',
      }, MagicStarterAuthUser());

      expect(await controller.attachmentHeaders(), <String, String>{
        'Authorization': 'Bearer abc123',
      });
    });

    test('attachmentHeaders is empty without a token', () async {
      Auth.fake();
      addTearDown(Auth.unfake);

      expect(await controller.attachmentHeaders(), isEmpty);
    });

    test(
      'attachmentLink posts to the link endpoint and answers the url',
      () async {
        final fake = Http.fake((request) {
          expect(request.method, 'POST');
          expect(request.url, '/support/conversations/7/attachments/a2/link');

          return Http.response(<String, dynamic>{
            'url': 'https://api.example.com/signed?sig=1',
          });
        });

        final url = await controller.attachmentLink(7, 'a2');

        fake.assertSentCount(1);
        expect(url, 'https://api.example.com/signed?sig=1');
      },
    );

    test('attachmentLink answers null when the backend refuses', () async {
      Log.fake();
      addTearDown(Log.unfake);
      Http.fake((request) => Http.response(<String, dynamic>{}, 403));

      expect(await controller.attachmentLink(7, 'a1'), isNull);
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
