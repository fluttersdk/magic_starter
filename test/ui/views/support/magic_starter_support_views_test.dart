import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// The shipped catalogue
// ---------------------------------------------------------------------------

/// The package's own English copy, flattened to the dotted keys `trans()`
/// looks up, so an assertion on rendered text is an assertion about the
/// product and not about a literal typed here.
Map<String, dynamic> _shippedCatalogue() {
  final File stub = File(
    '${Directory.current.path}/assets/stubs/install/en.stub',
  );

  return _flatten(jsonDecode(stub.readAsStringSync()) as Map<String, dynamic>);
}

Map<String, dynamic> _flatten(Map<String, dynamic> json, [String prefix = '']) {
  final Map<String, dynamic> result = <String, dynamic>{};

  for (final MapEntry<String, dynamic> entry in json.entries) {
    final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';

    if (entry.value is Map<String, dynamic>) {
      result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
    } else {
      result[key] = entry.value;
    }
  }

  return result;
}

class _ShippedLoader implements TranslationLoader {
  const _ShippedLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async => _shippedCatalogue();
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> conversationJson({
  int id = 7,
  String subject = 'Cannot add a monitor',
  String status = 'open',
  bool hasUnread = false,
  String? topic,
  bool awaitingAi = false,
  bool waitingOnTeam = false,
  Map<String, dynamic>? lastMessage,
  List<Map<String, dynamic>>? messages,
}) {
  return <String, dynamic>{
    'id': id,
    // The backend sends the display number as an integer.
    'number': id + 100,
    'subject': subject,
    'source': 'in_app',
    'status': status,
    'priority': 'normal',
    'last_activity_at': '2026-10-12T09:30:00+00:00',
    'created_at': '2026-10-12T09:00:00+00:00',
    'has_unread': hasUnread,
    'topic': ?topic,
    'awaiting_ai': awaitingAi,
    'waiting_on_team': waitingOnTeam,
    'last_message': ?lastMessage,
    'messages': ?messages,
  };
}

Map<String, dynamic> lastMessageJson({
  String senderType = 'staff',
  String? senderName = 'Ayse',
  String bodyPreview = 'On it',
}) {
  return <String, dynamic>{
    'sender_type': senderType,
    'sender_name': senderName,
    'body_preview': bodyPreview,
    'created_at': '2026-10-12T09:30:00+00:00',
  };
}

Map<String, dynamic> pageJson(
  List<Map<String, dynamic>> rows, {
  required int page,
  required int lastPage,
}) {
  return <String, dynamic>{
    'data': rows,
    'meta': <String, dynamic>{'current_page': page, 'last_page': lastPage},
  };
}

Map<String, dynamic> messageJson({
  int id = 1,
  String senderType = 'customer',
  String body = 'Hello',
  String kind = 'message',
  String? senderName,
  String? senderAvatarUrl,
}) {
  return <String, dynamic>{
    'id': id,
    'sender_type': senderType,
    'kind': kind,
    'body': body,
    'created_at': '2026-10-12T09:00:00+00:00',
    if (senderName != null || senderAvatarUrl != null)
      'sender': <String, dynamic>{
        'name': senderName,
        'avatar_url': senderAvatarUrl,
      },
  };
}

typedef SentRequest = ({String method, String url, Object? data});

/// Fakes the backend and records every request, in order.
///
/// [answers] is keyed `METHOD /path`; an unlisted request answers 404 so a
/// call the case did not expect cannot pass as a success.
List<SentRequest> fakeBackend(
  Map<String, MagicResponse Function(SentRequest request)> answers,
) {
  final List<SentRequest> sent = <SentRequest>[];

  Http.fake((request) {
    final SentRequest call = (
      method: request.method,
      url: request.url,
      data: request.data,
    );
    sent.add(call);

    final answer = answers['${request.method} ${request.url}'];
    if (answer == null) return Http.response(<String, dynamic>{}, 404);

    return answer(call);
  });

  return sent;
}

MagicResponse ok(Object? data) =>
    Http.response(<String, dynamic>{'data': data});

int count(List<SentRequest> sent, String method, String url) =>
    sent.where((s) => s.method == method && s.url == url).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();

    Magic.singleton('log', () => LogManager());
    Config.set('logging', <String, dynamic>{
      'default': 'console',
      'channels': <String, dynamic>{
        'console': <String, dynamic>{'driver': 'console', 'level': 'debug'},
      },
    });

    Config.set('magic_starter.features.support', true);
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Auth.fake(
      user: MagicStarterAuthUser.fromMap(<String, dynamic>{
        'id': 5,
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
      }),
    );

    Translator.instance.setLoader(const _ShippedLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    Echo.unfake();
    BroadcastListeners.reset();
    Auth.unfake();
    Http.unfake();
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  /// Mounts the three support views THROUGH THE REGISTRY on a real router, so
  /// navigation between them is the router's, not a stub.
  Future<void> mount(
    WidgetTester tester, {
    required String at,
    Size size = const Size(1280, 2000),
  }) async {
    // A logical size: flutter_test's default pixel ratio is 3, which would turn
    // a 1280 surface into a 427 px phone.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    Magic.put(MagicStarterSupportController());

    MagicRoute.page(
      MagicStarterConfig.supportRoute(),
      () => MagicStarter.view.make('support.index'),
    );
    MagicRoute.page(
      MagicStarterConfig.supportCreateRoute(),
      () => MagicStarter.view.make('support.create'),
    ).stacked();
    MagicRoute.page(
      MagicStarterConfig.supportThreadRoute(),
      () => MagicStarter.view.make('support.thread'),
    ).stacked();
    MagicRouter.instance.setInitialLocation(at);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: MagicRouter.instance.routerConfig,
        builder: (context, child) =>
            WindTheme(data: WindThemeData(), child: child!),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the index view', () {
    testWidgets('centres the empty state in the page at desktop width', (
      tester,
    ) async {
      fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[]),
      });

      await mount(tester, at: '/support', size: const Size(1440, 900));

      final double title = tester
          .getCenter(find.text(trans('magic_starter.support.empty_title')))
          .dx;
      final double page = tester.getCenter(find.byType(MSPageScaffold)).dx;
      expect((title - page).abs(), lessThan(24));
    });

    testWidgets('shows the empty state and a New button when there are none', (
      tester,
    ) async {
      fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[]),
      });

      await mount(tester, at: '/support');

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.support.empty_title')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.new_button')),
        findsOneWidget,
      );
    });

    testWidgets(
      'lists open conversations with a status pill and an unread dot',
      (tester) async {
        fakeBackend({
          'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[
            conversationJson(id: 7, hasUnread: true),
            conversationJson(id: 9, subject: 'Slow dashboard'),
            conversationJson(
              id: 8,
              subject: 'Invoice question',
              status: 'resolved',
            ),
          ]),
        });

        await mount(tester, at: '/support');

        expect(find.text('Cannot add a monitor'), findsOneWidget);
        expect(find.text('Slow dashboard'), findsOneWidget);
        expect(find.text('Invoice question'), findsNothing);
        expect(
          find.text(trans('magic_starter.support.status.open')),
          findsNWidgets(2),
        );
        expect(
          find.byKey(const ValueKey<String>('support-unread-7')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('support-unread-9')),
          findsNothing,
        );
        expect(
          find.text(trans('magic_starter.support.empty_title')),
          findsNothing,
        );
      },
    );

    testWidgets('the Resolved tab swaps the rows and carries the counts', (
      tester,
    ) async {
      fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[
          conversationJson(id: 7),
          conversationJson(
            id: 8,
            subject: 'Invoice question',
            status: 'resolved',
          ),
          conversationJson(id: 9, subject: 'Old one', status: 'resolved'),
        ]),
      });

      await mount(tester, at: '/support');

      expect(find.text('Cannot add a monitor'), findsOneWidget);
      expect(
        find.text('${trans('magic_starter.support.status.open')} · 1'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('${trans('magic_starter.support.status.resolved')} · 2'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cannot add a monitor'), findsNothing);
      expect(find.text('Invoice question'), findsOneWidget);
      expect(find.text('Old one'), findsOneWidget);
      expect(
        find.text(trans('magic_starter.support.status.resolved')),
        findsNWidgets(2),
        reason: 'one status pill per resolved row',
      );
    });

    testWidgets('a row previews the last message behind its sender name', (
      tester,
    ) async {
      fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[
          conversationJson(
            id: 7,
            topic: 'sales',
            lastMessage: lastMessageJson(
              senderName: 'Ayse',
              bodyPreview: 'Is 14:00 tomorrow fine?',
            ),
          ),
          conversationJson(
            id: 8,
            subject: 'SSL warning',
            lastMessage: lastMessageJson(
              senderType: 'ai',
              senderName: 'Uptizm AI',
              bodyPreview: 'The last check ran at 14:02',
            ),
          ),
          conversationJson(
            id: 9,
            subject: 'Billing address',
            lastMessage: lastMessageJson(
              senderType: 'customer',
              senderName: null,
              bodyPreview: 'Can you update the tax number?',
            ),
          ),
        ]),
      });

      await mount(tester, at: '/support');

      expect(find.text('Ayse: Is 14:00 tomorrow fine?'), findsOneWidget);
      expect(
        find.text('Uptizm AI: The last check ran at 14:02'),
        findsOneWidget,
      );
      expect(
        find.text(
          '${trans('magic_starter.support.sender.customer')}: '
          'Can you update the tax number?',
        ),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.topic.sales')),
        findsOneWidget,
        reason: 'the topic tag sits beside the subject',
      );
    });

    testWidgets('the status pill names who is answering, on wide screens', (
      tester,
    ) async {
      fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[
          conversationJson(id: 7, awaitingAi: true),
          conversationJson(
            id: 8,
            subject: 'Needs a human',
            waitingOnTeam: true,
          ),
        ]),
      });

      await mount(tester, at: '/support', size: const Size(1200, 800));

      expect(
        find.text(trans('magic_starter.support.status.ai_answering')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.status.team_answering')),
        findsOneWidget,
      );
    });

    testWidgets('the status pill gives way on a phone', (tester) async {
      fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[
          conversationJson(id: 7, awaitingAi: true),
        ]),
      });

      await mount(tester, at: '/support', size: const Size(390, 800));

      expect(find.text('Cannot add a monitor'), findsOneWidget);
      expect(
        find.text(trans('magic_starter.support.status.ai_answering')),
        findsNothing,
      );
    });

    testWidgets('Load more fetches page 2 and drops the control on the last', (
      tester,
    ) async {
      final List<Object?> pages = <Object?>[];
      Http.fake((MagicRequest request) async {
        final Object? page = request.queryParameters?['page'];
        if (request.url == '/support/conversations') pages.add(page);

        return Http.response(switch (page) {
          1 => pageJson(
            <Map<String, dynamic>>[
              conversationJson(id: 1, subject: 'First page'),
            ],
            page: 1,
            lastPage: 2,
          ),
          _ => pageJson(
            <Map<String, dynamic>>[
              conversationJson(id: 2, subject: 'Second page'),
            ],
            page: 2,
            lastPage: 2,
          ),
        });
      });

      await mount(tester, at: '/support');

      expect(find.text('First page'), findsOneWidget);
      expect(find.text('Second page'), findsNothing);
      expect(
        find.text(trans('magic_starter.support.status.open')),
        findsNWidgets(2),
        reason: 'with more pages to come the tab shows no count, the pill does',
      );

      await tester.tap(find.text(trans('magic_starter.support.load_more')));
      await tester.pumpAndSettle();

      expect(pages, <Object?>[1, 2]);
      expect(find.text('First page'), findsOneWidget);
      expect(find.text('Second page'), findsOneWidget);
      expect(find.text(trans('magic_starter.support.load_more')), findsNothing);
    });

    testWidgets('tapping a row opens its thread', (tester) async {
      final sent = fakeBackend({
        'GET /support/conversations': (_) =>
            ok(<Map<String, dynamic>>[conversationJson(id: 7)]),
        'GET /support/conversations/7': (_) => ok(
          conversationJson(
            id: 7,
            messages: <Map<String, dynamic>>[
              messageJson(body: 'My first line'),
            ],
          ),
        ),
        'POST /support/conversations/7/seen': (_) => ok(null),
      });

      await mount(tester, at: '/support');
      await tester.tap(find.text('Cannot add a monitor'));
      await tester.pumpAndSettle();

      expect(count(sent, 'GET', '/support/conversations/7'), 1);
      expect(find.text('My first line'), findsOneWidget);
    });

    testWidgets('opening an unread thread clears its dot on the list', (
      tester,
    ) async {
      var seen = false;
      final sent = fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[
          conversationJson(id: 7, hasUnread: !seen),
        ]),
        'GET /support/conversations/7': (_) => ok(
          conversationJson(
            id: 7,
            hasUnread: !seen,
            messages: <Map<String, dynamic>>[messageJson(body: 'Hi')],
          ),
        ),
        'POST /support/conversations/7/seen': (_) {
          seen = true;

          return ok(null);
        },
      });

      await mount(tester, at: '/support');
      expect(
        find.byKey(const ValueKey<String>('support-unread-7')),
        findsOneWidget,
      );

      await tester.tap(find.text('Cannot add a monitor'));
      await tester.pumpAndSettle();
      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(count(sent, 'POST', '/support/conversations/7/seen'), 1);
      expect(
        find.byKey(const ValueKey<String>('support-unread-7')),
        findsNothing,
      );
    });

    testWidgets('a failed read says so instead of showing an empty list', (
      tester,
    ) async {
      fakeBackend({
        'GET /support/conversations': (_) =>
            Http.response(<String, dynamic>{}, 500),
      });

      await mount(tester, at: '/support');

      expect(
        find.text(trans('magic_starter.support.load_error')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.empty_title')),
        findsNothing,
      );
    });
  });

  group('the create view', () {
    testWidgets('offers the configured topics as chips', (tester) async {
      fakeBackend({});

      await mount(tester, at: '/support/new');

      for (final String topic in MagicStarterConfig.supportTopics()) {
        expect(
          find.text(trans('magic_starter.support.topic.$topic')),
          findsOneWidget,
          reason: 'a chip for $topic',
        );
      }
    });

    testWidgets('posts the chosen topic and the message, with no subject', (
      tester,
    ) async {
      final sent = fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[]),
        'POST /support/conversations': (_) => ok(
          conversationJson(
            id: 9,
            subject: 'Please help',
            messages: <Map<String, dynamic>>[messageJson(body: 'Please help')],
          ),
        ),
        'GET /support/conversations/9': (_) => ok(
          conversationJson(
            id: 9,
            subject: 'Please help',
            messages: <Map<String, dynamic>>[messageJson(body: 'Please help')],
          ),
        ),
        'POST /support/conversations/9/seen': (_) => ok(null),
      });

      await mount(tester, at: '/support/new');

      await tester.tap(
        find.text(trans('magic_starter.support.topic.technical')),
      );
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'Please help');
      await tester.pump();
      await tester.tap(find.text(trans('magic_starter.support.create_submit')));
      await tester.pumpAndSettle();

      final post = sent.singleWhere(
        (s) => s.method == 'POST' && s.url == '/support/conversations',
      );
      expect(post.data, <String, dynamic>{
        'topic': 'technical',
        'body': 'Please help',
        'source': 'in_app',
      });
      expect(
        (post.data as Map).keys,
        isNot(anyOf(contains('team_id'), contains('user_id'))),
        reason: 'the backend scopes to the opener; the client sends no owner',
      );
      expect(count(sent, 'GET', '/support/conversations/9'), 1);
      expect(find.text('Please help'), findsWidgets);
    });

    testWidgets('counts the message against the limit', (tester) async {
      fakeBackend({});

      await mount(tester, at: '/support/new');
      expect(find.text('0 / 2000'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'Hello');
      await tester.pump();

      expect(find.text('5 / 2000'), findsOneWidget);
    });

    testWidgets('explains how it works beside the form on a wide screen', (
      tester,
    ) async {
      fakeBackend({});

      await mount(tester, at: '/support/new', size: const Size(1200, 800));

      expect(
        find.text(trans('magic_starter.support.how_title')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.how_step_1')),
        findsOneWidget,
      );
      expect(find.text(trans('magic_starter.support.how_short')), findsNothing);
    });

    testWidgets('folds the explanation into one line on a phone', (
      tester,
    ) async {
      fakeBackend({});

      await mount(tester, at: '/support/new', size: const Size(390, 800));

      expect(
        find.text(trans('magic_starter.support.how_short')),
        findsOneWidget,
      );
      expect(find.text(trans('magic_starter.support.how_title')), findsNothing);
      expect(
        find.text(trans('magic_starter.support.how_step_1')),
        findsNothing,
      );
    });

    testWidgets('opens clean after a refused reply elsewhere', (tester) async {
      // The controller is one singleton across the support screens. magic's
      // view clears field errors on init, but the write error is this
      // controller's own, so a refusal on a reply would greet a reader who
      // has not typed anything yet.
      fakeBackend({
        'GET /support/conversations/7': (_) => ok(conversationJson(id: 7)),
        'POST /support/conversations/7/messages': (_) => Http.response(
          <String, dynamic>{'message': 'Support is resting.'},
          503,
        ),
      });

      await mount(tester, at: '/support/7');
      await tester.enterText(find.byType(EditableText).last, 'Still there?');
      await tester.tap(find.byKey(const ValueKey<String>('support-send')));
      await tester.pumpAndSettle();
      expect(find.text('Support is resting.'), findsOneWidget);

      MagicRoute.to(MagicStarterConfig.supportCreateRoute());
      await tester.pumpAndSettle();

      expect(
        find.text(trans('magic_starter.support.create_submit')),
        findsOneWidget,
      );
      expect(find.text('Support is resting.'), findsNothing);
    });

    testWidgets('a refused field shows its error and stays on the page', (
      tester,
    ) async {
      fakeBackend({
        'POST /support/conversations': (_) => Http.response(<String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'topic': <String>['The topic field is required.'],
          },
        }, 422),
      });

      await mount(tester, at: '/support/new');
      await tester.tap(find.text(trans('magic_starter.support.create_submit')));
      await tester.pumpAndSettle();

      expect(find.text('The topic field is required.'), findsOneWidget);
      expect(
        find.text(trans('magic_starter.support.create_submit')),
        findsOneWidget,
      );
    });
  });

  group('the thread view', () {
    testWidgets('renders staff and customer messages and marks it seen', (
      tester,
    ) async {
      final sent = fakeBackend({
        'GET /support/conversations/7': (_) => ok(
          conversationJson(
            id: 7,
            hasUnread: true,
            messages: <Map<String, dynamic>>[
              messageJson(id: 1, body: 'My monitor will not save'),
              messageJson(id: 2, senderType: 'staff', body: 'Looking now'),
              messageJson(id: 3, senderType: 'system', body: 'Marked resolved'),
            ],
          ),
        ),
        'POST /support/conversations/7/seen': (_) => ok(null),
      });

      await mount(tester, at: '/support/7');

      expect(find.text('Cannot add a monitor'), findsOneWidget);
      expect(find.text('My monitor will not save'), findsOneWidget);
      expect(find.text('Looking now'), findsOneWidget);
      expect(find.text('Marked resolved'), findsOneWidget);
      expect(
        find.textContaining(trans('magic_starter.support.sender.customer')),
        findsOneWidget,
      );
      expect(
        find.textContaining(trans('magic_starter.support.sender.staff')),
        findsOneWidget,
      );
      expect(count(sent, 'POST', '/support/conversations/7/seen'), 1);
    });

    testWidgets('a thread left before it loaded sends no receipt for it', (
      tester,
    ) async {
      // Open A, go back before it answers, open B with an unread reply. When A
      // finally answers, its read is dropped as stale; the receipt that
      // followed it must not read B's unread state and clear A's dot.
      final answerA = Completer<MagicResponse>();
      final List<String> sent = <String>[];
      Http.fake((MagicRequest request) async {
        sent.add('${request.method} ${request.url}');
        if (request.url == '/support/conversations/1') return answerA.future;
        if (request.url == '/support/conversations/2') {
          return ok(conversationJson(id: 2, hasUnread: true));
        }
        if (request.url == '/support/conversations') {
          return ok(<Map<String, dynamic>>[]);
        }

        return Http.response(<String, dynamic>{});
      });

      await mount(tester, at: '/support');
      // A's skeleton animates while its read is pending, so these pumps run a
      // fixed transition length instead of settling.
      MagicRoute.to('/support/1');
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(sent, contains('GET /support/conversations/1'));
      MagicRoute.back();
      await tester.pump(const Duration(seconds: 1));
      MagicRoute.to('/support/2');
      await tester.pumpAndSettle();

      answerA.complete(ok(conversationJson(id: 1)));
      await tester.pumpAndSettle();

      expect(sent, isNot(contains('POST /support/conversations/1/seen')));
      expect(
        sent.where((s) => s == 'POST /support/conversations/2/seen'),
        hasLength(1),
      );
    });

    testWidgets('sends no seen receipt when nothing is unread', (tester) async {
      // The thread rereads on every poll and broadcast; a receipt that changes
      // nothing would still be a write, and an audit row on the backend.
      final sent = fakeBackend({
        'GET /support/conversations/7': (_) => ok(conversationJson(id: 7)),
        'POST /support/conversations/7/seen': (_) => ok(null),
      });

      await mount(tester, at: '/support/7');

      expect(find.text('Cannot add a monitor'), findsOneWidget);
      expect(count(sent, 'POST', '/support/conversations/7/seen'), 0);
    });

    testWidgets('opened from an unrelated page it still loads its own id', (
      tester,
    ) async {
      // The Contact sales button opens a thread from the billing page. The
      // router rebuilds the page underneath during that push, so an id read
      // from the router's "current" state instead of this page's own route
      // came back empty and the thread fetched `support/conversations/`.
      final sent = fakeBackend({
        'GET /support/conversations/7': (_) => ok(conversationJson(id: 7)),
        'POST /support/conversations/7/seen': (_) => ok(null),
      });
      await tester.binding.setSurfaceSize(const Size(1280, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Two shells, as in uptizm: its billing page sits in the app's own layout
      // group and the support routes in the package's `app` group. go_router
      // builds the pushed thread's page at the root first and the shell
      // underneath after it, so a read of the router's last-built state named
      // the billing page. One shared shell builds them in stack order and
      // never showed the defect.
      MagicRoute.group(
        layout: (child) => Column(children: [Expanded(child: child)]),
        routes: () {
          MagicRoute.page('/elsewhere', () => const Text('Elsewhere'));
        },
      );
      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => Column(children: [Expanded(child: child)]),
        routes: () {
          MagicRoute.page(
            MagicStarterConfig.supportThreadRoute(),
            () => MagicStarter.view.make('support.thread'),
          ).stacked();
        },
      );
      Magic.put(MagicStarterSupportController());
      MagicRouter.instance.setInitialLocation('/elsewhere');
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: MagicRouter.instance.routerConfig,
          builder: (context, child) =>
              WindTheme(data: WindThemeData(), child: child!),
        ),
      );
      await tester.pumpAndSettle();

      MagicRoute.to('/support/7');
      await tester.pumpAndSettle();

      expect(count(sent, 'GET', '/support/conversations/7'), 1);
      expect(count(sent, 'GET', '/support/conversations/'), 0);
      expect(find.text('Cannot add a monitor'), findsOneWidget);
    });

    testWidgets('a reply posts its body and appears in the thread', (
      tester,
    ) async {
      final sent = fakeBackend({
        'GET /support/conversations/7': (_) => ok(
          conversationJson(
            id: 7,
            messages: <Map<String, dynamic>>[messageJson(body: 'First')],
          ),
        ),
        'POST /support/conversations/7/seen': (_) => ok(null),
        'POST /support/conversations/7/messages': (_) =>
            ok(messageJson(id: 4, body: 'A second line')),
      });

      await mount(tester, at: '/support/7');
      await tester.enterText(find.byType(EditableText), 'A second line');
      await tester.tap(find.byKey(const ValueKey<String>('support-send')));
      await tester.pumpAndSettle();

      final post = sent.singleWhere(
        (s) =>
            s.method == 'POST' && s.url == '/support/conversations/7/messages',
      );
      expect(post.data, <String, dynamic>{'body': 'A second line'});
      expect(find.text('A second line'), findsOneWidget);
    });

    testWidgets('a 404 renders the not-found state and marks nothing seen', (
      tester,
    ) async {
      final sent = fakeBackend({
        'GET /support/conversations/99': (_) =>
            Http.response(<String, dynamic>{}, 404),
      });

      await mount(tester, at: '/support/99');

      expect(
        find.text(trans('magic_starter.support.not_found_title')),
        findsOneWidget,
      );
      expect(count(sent, 'GET', '/support/conversations/99'), 1);
      expect(count(sent, 'POST', '/support/conversations/99/seen'), 0);
    });
  });

  group('the thread as a chat', () {
    Rect rectOf(WidgetTester tester, String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key)));

    List<SentRequest> backend({
      List<Map<String, dynamic>>? messages,
      bool awaitingAi = false,
      bool waitingOnTeam = false,
      String? topic,
      String status = 'open',
    }) {
      return fakeBackend({
        'GET /support/conversations/7': (_) => ok(
          conversationJson(
            id: 7,
            status: status,
            topic: topic,
            awaitingAi: awaitingAi,
            waitingOnTeam: waitingOnTeam,
            messages: messages ?? <Map<String, dynamic>>[messageJson()],
          ),
        ),
        'POST /support/conversations/7/seen': (_) => ok(null),
        'POST /support/conversations/7/messages': (request) => ok(
          messageJson(id: 99, body: (request.data as Map)['body'] as String),
        ),
      });
    }

    for (final double width in <double>[1200, 390]) {
      testWidgets('keeps the composer docked at ${width.toInt()}px with 30 '
          'messages and the newest in view', (tester) async {
        backend(
          messages: <Map<String, dynamic>>[
            for (var i = 1; i <= 30; i++)
              messageJson(
                id: i,
                senderType: i.isEven ? 'staff' : 'customer',
                body: 'Line $i',
              ),
          ],
        );

        await mount(tester, at: '/support/7', size: Size(width, 800));

        final Rect composer = rectOf(tester, 'support-composer');
        expect(composer.bottom, closeTo(800, 1));

        final Rect newest = tester.getRect(find.text('Line 30'));
        expect(newest.bottom, lessThanOrEqualTo(composer.top));
        expect(newest.top, greaterThanOrEqualTo(0));
      });
    }

    testWidgets(
      'an AI reply wears the AI chip and its avatar tops the bubble',
      (tester) async {
        backend(
          messages: <Map<String, dynamic>>[
            messageJson(id: 1, body: 'Is my SSL fine?'),
            messageJson(
              id: 2,
              senderType: 'ai',
              senderName: 'Uptizm AI',
              body: 'The last check passed.',
            ),
          ],
        );

        await mount(tester, at: '/support/7', size: const Size(1200, 800));

        expect(find.text('Uptizm AI'), findsOneWidget);
        final Rect avatar = rectOf(tester, 'support-avatar-2');
        final Rect bubble = rectOf(tester, 'support-bubble-2');
        final Rect label = rectOf(tester, 'support-label-2');

        expect(avatar.top, bubble.top);
        expect(label.top, greaterThanOrEqualTo(bubble.bottom));
        expect(avatar.right, lessThanOrEqualTo(bubble.left));
      },
    );

    testWidgets('a staff reply names the teammate under the bubble', (
      tester,
    ) async {
      backend(
        messages: <Map<String, dynamic>>[
          messageJson(
            id: 2,
            senderType: 'staff',
            senderName: 'Ayse Yilmaz',
            body: 'Tomorrow at 14:00?',
          ),
        ],
      );

      await mount(tester, at: '/support/7', size: const Size(1200, 800));

      expect(
        find.textContaining(
          'Ayse · ${trans('magic_starter.support.sender.staff')}',
        ),
        findsOneWidget,
      );
      expect(
        rectOf(tester, 'support-avatar-2').top,
        rectOf(tester, 'support-bubble-2').top,
      );
      expect(
        rectOf(tester, 'support-label-2').top,
        greaterThanOrEqualTo(rectOf(tester, 'support-bubble-2').bottom),
      );
    });

    testWidgets('the customer sits on the right, labelled You', (tester) async {
      backend(
        messages: <Map<String, dynamic>>[
          messageJson(id: 1, body: 'Please help'),
        ],
      );

      await mount(tester, at: '/support/7', size: const Size(1200, 800));

      expect(
        find.textContaining(trans('magic_starter.support.sender.customer')),
        findsOneWidget,
      );
      expect(rectOf(tester, 'support-bubble-1').center.dx, greaterThan(600));
      expect(
        find.byKey(const ValueKey<String>('support-avatar-1')),
        findsNothing,
      );
    });

    for (final double width in <double>[1200, 390]) {
      testWidgets('a system handoff line is centred with no bubble at '
          '${width.toInt()}px', (tester) async {
        backend(
          messages: <Map<String, dynamic>>[
            messageJson(id: 1, body: 'Is it billing?'),
            messageJson(
              id: 2,
              senderType: 'system',
              kind: 'activity',
              body: 'Handed over to the team',
            ),
          ],
        );

        await mount(tester, at: '/support/7', size: Size(width, 800));

        final Finder line = find.text('Handed over to the team');
        expect(line, findsOneWidget);
        expect(tester.getCenter(line).dx, closeTo(width / 2, 2));
        expect(
          find.byKey(const ValueKey<String>('support-bubble-2')),
          findsNothing,
        );
      });
    }

    testWidgets('shows the typing bubble while the AI owes an answer, then '
        'the taking-longer note after 45 seconds', (tester) async {
      backend(awaitingAi: true);

      await mount(tester, at: '/support/7', size: const Size(1200, 800));

      expect(
        find.byKey(const ValueKey<String>('support-typing')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.taking_longer')),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 44));
      expect(
        find.byKey(const ValueKey<String>('support-typing')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.taking_longer')),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text(trans('magic_starter.support.taking_longer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('support-typing')),
        findsNothing,
      );
    });

    testWidgets('shows no typing bubble once the AI is not pending', (
      tester,
    ) async {
      backend();

      await mount(tester, at: '/support/7', size: const Size(1200, 800));

      expect(
        find.byKey(const ValueKey<String>('support-typing')),
        findsNothing,
      );
    });

    testWidgets('sets the expectation above the composer', (tester) async {
      backend(awaitingAi: true);
      await mount(tester, at: '/support/7', size: const Size(1200, 800));
      expect(
        find.text(trans('magic_starter.support.expect_ai')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.expect_team')),
        findsNothing,
      );
    });

    testWidgets('names the team while the conversation waits on it', (
      tester,
    ) async {
      backend(waitingOnTeam: true);
      await mount(tester, at: '/support/7', size: const Size(1200, 800));
      expect(
        find.text(trans('magic_starter.support.expect_team')),
        findsOneWidget,
      );
      expect(find.text(trans('magic_starter.support.expect_ai')), findsNothing);
    });

    testWidgets('keeps the AI pill and line on an AI-owned thread it answered', (
      tester,
    ) async {
      // Pending with nothing owed: the AI has answered and still owns the
      // conversation, so it reads as the AI's, not as a plain open thread.
      backend(status: 'pending');
      await mount(tester, at: '/support/7', size: const Size(1200, 800));
      expect(
        find.text(trans('magic_starter.support.status.ai_answering')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.expect_ai')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.status.open')),
        findsNothing,
      );
    });

    testWidgets('reads the thread in a centred column at desktop width', (
      tester,
    ) async {
      backend();
      await mount(tester, at: '/support/7', size: const Size(1440, 900));
      // The keyed box is the full-width slot `mx-auto` centres inside; the
      // field it holds is what the eye reads, so that is what is measured.
      final double field = tester
          .getSize(
            find.descendant(
              of: find.byKey(const ValueKey<String>('support-composer')),
              matching: find.byType(EditableText),
            ),
          )
          .width;
      expect(field, lessThanOrEqualTo(768));
    });

    testWidgets('says nothing when neither is pending', (tester) async {
      backend();
      await mount(tester, at: '/support/7', size: const Size(1200, 800));
      expect(find.text(trans('magic_starter.support.expect_ai')), findsNothing);
      expect(
        find.text(trans('magic_starter.support.expect_team')),
        findsNothing,
      );
    });

    testWidgets('the header carries the number, topic and open date', (
      tester,
    ) async {
      backend(topic: 'billing');

      await mount(tester, at: '/support/7', size: const Size(1200, 800));

      expect(
        find.textContaining(
          '#107 · ${trans('magic_starter.support.topic.billing')} · ',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Enter sends and Shift+Enter does not, on a desktop', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final sent = backend();
        await mount(tester, at: '/support/7', size: const Size(1200, 800));
        const String url = '/support/conversations/7/messages';

        await tester.tap(find.byType(EditableText));
        await tester.enterText(find.byType(EditableText), 'First line');
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(
          count(sent, 'POST', url),
          0,
          reason: 'Shift+Enter breaks a line',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(count(sent, 'POST', url), 1);
        expect(
          sent.singleWhere((s) => s.method == 'POST' && s.url == url).data,
          <String, dynamic>{'body': 'First line'},
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          isEmpty,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a sent message scrolls to the newest', (tester) async {
      backend(
        messages: <Map<String, dynamic>>[
          for (var i = 1; i <= 30; i++)
            messageJson(
              id: i,
              senderType: i.isEven ? 'staff' : 'customer',
              body: 'Line $i',
            ),
        ],
      );

      await mount(tester, at: '/support/7', size: const Size(390, 800));
      await tester.enterText(find.byType(EditableText), 'One more');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('support-send')));
      await tester.pumpAndSettle();

      final Rect composer = rectOf(tester, 'support-composer');
      final Rect sent = tester.getRect(find.text('One more').last);
      expect(sent.bottom, lessThanOrEqualTo(composer.top));
      expect(sent.top, greaterThanOrEqualTo(0));
    });
  });

  group('live refresh', () {
    const event = 'support.conversation.updated';

    testWidgets('polls every 30 seconds when there is no socket', (
      tester,
    ) async {
      final sent = fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[]),
      });

      await mount(tester, at: '/support');
      expect(count(sent, 'GET', '/support/conversations'), 1);

      await tester.pump(const Duration(seconds: 29));
      expect(count(sent, 'GET', '/support/conversations'), 1);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(count(sent, 'GET', '/support/conversations'), 2);
    });

    testWidgets('refreshes on the private user channel event and keeps polling', (
      tester,
    ) async {
      final fake = Echo.fake();
      Config.set('broadcasting.default', 'reverb');
      final sent = fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[]),
      });

      await mount(tester, at: '/support');
      await tester.pump();

      fake.assertSubscribed('private-App.Models.User.5');
      expect(count(sent, 'GET', '/support/conversations'), 1);

      fake.dispatch('private-App.Models.User.5', event, <String, dynamic>{});
      await tester.pump();
      expect(count(sent, 'GET', '/support/conversations'), 2);

      // A connected socket is not a subscribed one: the live walk caught a
      // socket that pinged for minutes with no channel joined, and a screen
      // that trusted it never refreshed. The poll is the floor either way.
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(
        count(sent, 'GET', '/support/conversations'),
        3,
        reason: 'the poll still runs beside a connected socket',
      );
    });

    testWidgets('stops listening when the view goes away', (tester) async {
      final fake = Echo.fake();
      Config.set('broadcasting.default', 'reverb');
      fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[]),
      });

      await mount(tester, at: '/support');
      await tester.pump();
      fake.assertListening('private-App.Models.User.5', event);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      fake.assertNotListening('private-App.Models.User.5', event);
    });
  });

  group('the user menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: const Scaffold(body: MSUserProfileDropdown()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MSAvatar));
      await tester.pumpAndSettle();
    }

    testWidgets('offers Support when the feature is on', (tester) async {
      await openMenu(tester);

      expect(find.text(trans('magic_starter.nav.support')), findsOneWidget);
    });

    testWidgets('offers no Support when the feature is off', (tester) async {
      Config.set('magic_starter.features.support', false);

      await openMenu(tester);

      expect(find.text(trans('magic_starter.nav.support')), findsNothing);
    });
  });
}
