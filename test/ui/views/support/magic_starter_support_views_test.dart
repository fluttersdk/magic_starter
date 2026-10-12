import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
  Future<void> mount(WidgetTester tester, {required String at}) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    testWidgets('lists conversations with a status badge and an unread dot', (
      tester,
    ) async {
      fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[
          conversationJson(id: 7, hasUnread: true),
          conversationJson(
            id: 8,
            subject: 'Invoice question',
            status: 'resolved',
          ),
        ]),
      });

      await mount(tester, at: '/support');

      expect(find.text('Cannot add a monitor'), findsOneWidget);
      expect(find.text('Invoice question'), findsOneWidget);
      expect(
        find.text(trans('magic_starter.support.status.open')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.support.status.resolved')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('support-unread-7')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('support-unread-8')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.support.empty_title')),
        findsNothing,
      );
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
    testWidgets('posts subject and message as in_app and opens the thread', (
      tester,
    ) async {
      final sent = fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[]),
        'POST /support/conversations': (_) => ok(
          conversationJson(
            id: 9,
            subject: 'Billing help',
            messages: <Map<String, dynamic>>[messageJson(body: 'Please help')],
          ),
        ),
        'GET /support/conversations/9': (_) => ok(
          conversationJson(
            id: 9,
            subject: 'Billing help',
            messages: <Map<String, dynamic>>[messageJson(body: 'Please help')],
          ),
        ),
        'POST /support/conversations/9/seen': (_) => ok(null),
      });

      await mount(tester, at: '/support/new');

      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), 'Billing help');
      await tester.enterText(fields.at(1), 'Please help');
      await tester.tap(find.text(trans('magic_starter.support.create_submit')));
      await tester.pumpAndSettle();

      final post = sent.singleWhere(
        (s) => s.method == 'POST' && s.url == '/support/conversations',
      );
      expect(post.data, <String, dynamic>{
        'subject': 'Billing help',
        'body': 'Please help',
        'source': 'in_app',
      });
      expect(
        (post.data as Map).keys,
        isNot(anyOf(contains('team_id'), contains('user_id'))),
        reason: 'the backend scopes to the opener; the client sends no owner',
      );
      expect(count(sent, 'GET', '/support/conversations/9'), 1);
      expect(find.text('Please help'), findsOneWidget);
    });

    testWidgets('a refused field shows its error and stays on the page', (
      tester,
    ) async {
      fakeBackend({
        'POST /support/conversations': (_) => Http.response(<String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'subject': <String>['The subject field is required.'],
          },
        }, 422),
      });

      await mount(tester, at: '/support/new');
      await tester.tap(find.text(trans('magic_starter.support.create_submit')));
      await tester.pumpAndSettle();

      expect(find.text('The subject field is required.'), findsOneWidget);
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
      await tester.tap(find.text(trans('magic_starter.support.reply_submit')));
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

    testWidgets('refreshes on the private user channel event, not the poll', (
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

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(
        count(sent, 'GET', '/support/conversations'),
        2,
        reason: 'a live socket makes the poll redundant',
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
