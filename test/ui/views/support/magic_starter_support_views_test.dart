import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/views/support/magic_starter_support_message_bubble.dart';

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
  bool canRate = false,
  Map<String, dynamic>? rating,
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
    'can_rate': canRate,
    'rating': ?rating,
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
  List<Map<String, dynamic>>? attachments,
}) {
  return <String, dynamic>{
    'id': id,
    'sender_type': senderType,
    'kind': kind,
    'body': body,
    'created_at': '2026-10-12T09:00:00+00:00',
    'attachments': ?attachments,
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

Map<String, dynamic> attachmentJson({
  int id = 11,
  String name = 'error.png',
  String kind = 'image',
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'mime': kind == 'image' ? 'image/png' : 'application/pdf',
    'size': 2048,
    'width': kind == 'image' ? 640 : null,
    'height': kind == 'image' ? 480 : null,
    'kind': kind,
    'url': 'support/conversations/7/attachments/$id',
  };
}

/// A picked file, as `Pick.files` hands it over. [size] defaults to the byte
/// count; pass it to claim a size the picker reported.
MagicFile pickedFile(String name, {int bytes = 1024, int? size}) {
  return MagicFile(
    name: name,
    size: size ?? bytes,
    mimeType: name.endsWith('.pdf') ? 'application/pdf' : 'image/png',
    bytes: Uint8List(bytes),
  );
}

/// Records what the screen asked the system to open instead of opening it.
class _RecordingLaunchAdapter implements LaunchAdapter {
  final List<Uri> launched = <Uri>[];
  final List<String?> windowNames = <String?>[];

  @override
  Future<bool> launch(
    Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
    String? webOnlyWindowName,
  }) async {
    launched.add(url);
    windowNames.add(webOnlyWindowName);

    return true;
  }

  @override
  Future<bool> canLaunch(Uri url) async => true;
}

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
    Future<List<MagicFile>> Function(List<String> extensions)? pickFiles,
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
      () => pickFiles == null
          ? MagicStarter.view.make('support.create')
          : MagicStarterSupportCreateView(pickFiles: pickFiles),
    ).stacked();
    MagicRoute.page(
      MagicStarterConfig.supportThreadRoute(),
      () => pickFiles == null
          ? MagicStarter.view.make('support.thread')
          : MagicStarterSupportThreadView(pickFiles: pickFiles),
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

    testWidgets('the Resolved tab offers Load more instead of claiming there '
        'is nothing while pages remain', (tester) async {
      Http.fake((MagicRequest request) async {
        return Http.response(switch (request.queryParameters?['page']) {
          1 => pageJson(
            <Map<String, dynamic>>[
              conversationJson(id: 1, subject: 'Open one'),
            ],
            page: 1,
            lastPage: 2,
          ),
          _ => pageJson(
            <Map<String, dynamic>>[
              conversationJson(
                id: 2,
                subject: 'Closed long ago',
                status: 'resolved',
              ),
            ],
            page: 2,
            lastPage: 2,
          ),
        });
      });

      await mount(tester, at: '/support');
      await tester.tap(
        find.text(trans('magic_starter.support.status.resolved')).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(trans('magic_starter.support.empty_resolved_title')),
        findsNothing,
        reason: 'an unloaded page may still hold resolved conversations',
      );
      expect(
        find.text(trans('magic_starter.support.load_more')),
        findsOneWidget,
      );

      await tester.tap(find.text(trans('magic_starter.support.load_more')));
      await tester.pumpAndSettle();

      expect(find.text('Closed long ago'), findsOneWidget);
    });

    testWidgets('the Resolved tab says so once every page is read', (
      tester,
    ) async {
      fakeBackend({
        'GET /support/conversations': (_) =>
            ok(<Map<String, dynamic>>[conversationJson(id: 1)]),
      });

      await mount(tester, at: '/support');
      await tester.tap(
        find.text('${trans('magic_starter.support.status.resolved')} · 0'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(trans('magic_starter.support.empty_resolved_title')),
        findsOneWidget,
      );
    });

    testWidgets('a poll after Load more keeps the second page', (tester) async {
      Http.fake((MagicRequest request) async {
        return Http.response(switch (request.queryParameters?['page']) {
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
      await tester.tap(find.text(trans('magic_starter.support.load_more')));
      await tester.pumpAndSettle();
      expect(find.text('Second page'), findsOneWidget);

      await tester.pump(MagicStarterSupportLiveRefresh.pollInterval);
      await tester.pumpAndSettle();

      expect(find.text('First page'), findsOneWidget);
      expect(find.text('Second page'), findsOneWidget);
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

    testWidgets('counts against the configured message limit', (tester) async {
      Config.set('magic_starter.support.message_max_length', 500);
      fakeBackend({});

      await mount(tester, at: '/support/new');

      expect(find.text('0 / 500'), findsOneWidget);
      expect(find.text('0 / 2000'), findsNothing);
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

    testWidgets(
      'a follow-up on a pending thread shows the typing bubble before '
      'any refetch',
      (tester) async {
        // The AI answered an earlier turn: pending, nothing owed.
        final sent = backend(
          status: 'pending',
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
        expect(
          find.byKey(const ValueKey<String>('support-typing')),
          findsNothing,
        );

        await tester.enterText(find.byType(EditableText), 'Can I mute it?');
        await tester.tap(find.byKey(const ValueKey<String>('support-send')));
        await tester.pump();
        await tester.pump();

        expect(count(sent, 'GET', '/support/conversations/7'), 1);
        expect(
          find.byKey(const ValueKey<String>('support-typing')),
          findsOneWidget,
        );
      },
    );

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

    testWidgets(
      'keeps the AI pill and line on an AI-owned thread it answered',
      (tester) async {
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
      },
    );

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

    testWidgets(
      'refreshes on the private user channel event and keeps polling',
      (tester) async {
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
      },
    );

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

  group('the design tokens on the support screens', () {
    Widget themed(Widget child, {Brightness brightness = Brightness.light}) {
      return MaterialApp(
        home: WindTheme(
          data: WindThemeData(
            brightness: brightness,
            aliases: MagicStarterTokens.defaultAliases,
          ),
          child: Scaffold(body: Center(child: child)),
        ),
      );
    }

    String classOf(WidgetTester tester, String key) {
      return tester.widget<WDiv>(find.byKey(ValueKey<String>(key))).className!;
    }

    for (final (
          String label,
          MagicStarterSupportStatusBadge badge,
          String bg,
          String fg,
        )
        in <(String, MagicStarterSupportStatusBadge, String, String)>[
          (
            'the team',
            const MagicStarterSupportStatusBadge('open', waitingOnTeam: true),
            'bg-warning-soft',
            'text-warning-soft-foreground',
          ),
          (
            'a resolved conversation',
            const MagicStarterSupportStatusBadge('resolved'),
            'bg-success-soft',
            'text-success-soft-foreground',
          ),
          (
            'the AI',
            const MagicStarterSupportStatusBadge('open', awaitingAi: true),
            'bg-ai-soft',
            'text-ai-soft-foreground',
          ),
          (
            'a plain open conversation',
            const MagicStarterSupportStatusBadge('open'),
            'bg-surface-container-high',
            'text-fg-muted',
          ),
        ]) {
      testWidgets('the status pill for $label is a soft tint with a leading '
          'dot', (tester) async {
        await tester.pumpWidget(themed(badge));

        final String pill = classOf(tester, 'support-status-pill');
        expect(pill, contains(bg));
        expect(pill, contains('rounded-full'));

        final Finder dotFinder = find.byKey(
          const ValueKey<String>('support-status-dot'),
        );
        final WIcon dot = tester.widget<WIcon>(dotFinder);
        expect(dot.className, contains(fg));

        // The dot leads the label on one line: `inline-flex` is inert in Wind,
        // and a pill without a row axis stacks the dot above its label.
        final Rect dotRect = tester.getRect(dotFinder);
        final Rect labelRect = tester.getRect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('support-status-pill')),
            matching: find.byType(WText),
          ),
        );
        expect(dotRect.right, lessThanOrEqualTo(labelRect.left));
        expect((dotRect.center.dy - labelRect.center.dy).abs(), lessThan(2));
      });
    }

    testWidgets('a team pill resolves to a tint, not the solid warning fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              MagicStarterSupportStatusBadge('open', waitingOnTeam: true),
              WDiv(
                key: ValueKey<String>('solid'),
                className: 'w-4 h-4 bg-warning',
              ),
            ],
          ),
        ),
      );

      Color? fillOf(Finder owner) {
        final Finder box = find.descendant(
          of: owner,
          matching: find.byType(DecoratedBox),
        );

        return (tester.widget<DecoratedBox>(box.first).decoration
                as BoxDecoration)
            .color;
      }

      final Color? tint = fillOf(
        find.byKey(const ValueKey<String>('support-status-pill')),
      );
      final Color? solid = fillOf(find.byKey(const ValueKey<String>('solid')));

      expect(tint, isNotNull, reason: 'bg-warning-soft was dropped');
      expect(solid, isNotNull);
      expect(tint, isNot(solid));
    });

    testWidgets('the AI bubble carries a 2px violet left edge', (tester) async {
      await tester.pumpWidget(
        themed(
          MagicStarterSupportMessageBubble(
            MagicStarterSupportMessage(
              id: 2,
              senderType: 'ai',
              senderName: 'Uptizm AI',
              body: 'The last check passed.',
              createdAt: DateTime.utc(2026, 10, 12, 9),
            ),
          ),
        ),
      );

      final String bubble = classOf(tester, 'support-bubble-2');
      expect(bubble, contains('border-l-2'));
      expect(bubble, contains('border-ai'));

      final Finder box = find
          .descendant(
            of: find.byKey(const ValueKey<String>('support-bubble-2')),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final BoxDecoration decoration =
          tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
      final Border border = decoration.border! as Border;

      expect(border.left.width, 2);
      expect(
        border.left.color,
        isNot(const Color(0x00000000)),
        reason: 'border-ai was dropped',
      );
      expect(border.right.width, 0);
    });

    testWidgets('a customer bubble has no accent edge', (tester) async {
      await tester.pumpWidget(
        themed(
          MagicStarterSupportMessageBubble(
            MagicStarterSupportMessage(
              id: 1,
              senderType: 'customer',
              body: 'Hello',
              createdAt: DateTime.utc(2026, 10, 12, 9),
            ),
          ),
        ),
      );

      expect(classOf(tester, 'support-bubble-1'), isNot(contains('border-ai')));
    });
  });

  group('avatar initials', () {
    test('two words give their first letters', () {
      expect(MagicStarterSupportSenderAvatar.initials('Ayse Yilmaz'), 'AY');
      expect(MagicStarterSupportSenderAvatar.initials('Anılcan Çakır'), 'AÇ');
    });

    test('more than two words stop at the second', () {
      expect(
        MagicStarterSupportSenderAvatar.initials('Ada King Lovelace'),
        'AK',
      );
    });

    test('a single word gives its first two letters', () {
      expect(MagicStarterSupportSenderAvatar.initials('Ayse'), 'AY');
      expect(MagicStarterSupportSenderAvatar.initials('A'), 'A');
    });

    test('no name gives nothing', () {
      expect(MagicStarterSupportSenderAvatar.initials(null), '');
      expect(MagicStarterSupportSenderAvatar.initials('   '), '');
    });

    testWidgets('a teammate with one name wears two letters in the thread', (
      tester,
    ) async {
      fakeBackend({
        'GET /support/conversations/7': (_) => ok(
          conversationJson(
            id: 7,
            messages: <Map<String, dynamic>>[
              messageJson(
                id: 2,
                senderType: 'staff',
                senderName: 'Ayse',
                body: 'Tomorrow?',
              ),
            ],
          ),
        ),
        'POST /support/conversations/7/seen': (_) => ok(null),
      });

      await mount(tester, at: '/support/7', size: const Size(1200, 800));

      expect(find.text('AY'), findsOneWidget);
    });

    testWidgets('the list row shows the viewer own two letters', (
      tester,
    ) async {
      fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[
          conversationJson(
            id: 7,
            lastMessage: lastMessageJson(
              senderType: 'customer',
              senderName: null,
            ),
          ),
        ]),
      });

      await mount(tester, at: '/support');

      expect(find.text('AL'), findsOneWidget, reason: 'Ada Lovelace');
    });
  });

  group('the support routes on a phone', () {
    const String bottomNavLabel = 'Overview';

    Future<void> mountRoutes(WidgetTester tester, {required String at}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      Magic.put(MagicStarterSupportController());
      Kernel.register('auth', AllowAllMiddleware.new);
      addTearDown(Kernel.flush);
      MagicStarter.useNavigation(
        mainItems: const [],
        bottomItems: const [
          MagicStarterNavItem(
            icon: Icons.dashboard_outlined,
            labelKey: bottomNavLabel,
            path: '/',
          ),
        ],
      );

      registerMagicStarterSupportRoutes();
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

    testWidgets('the list keeps the bottom navigation', (tester) async {
      fakeBackend({
        'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[]),
      });

      await mountRoutes(tester, at: '/support');

      expect(find.text(bottomNavLabel), findsOneWidget);
    });

    testWidgets('the thread hides it, like a chat screen', (tester) async {
      fakeBackend({
        'GET /support/conversations/7': (_) =>
            ok(conversationJson(id: 7, messages: <Map<String, dynamic>>[])),
        'POST /support/conversations/7/seen': (_) => ok(null),
      });

      await mountRoutes(tester, at: '/support/7');

      expect(find.byKey(const ValueKey<String>('support-composer')), findsOne);
      expect(find.text(bottomNavLabel), findsNothing);
    });

    testWidgets('the create screen keeps it', (tester) async {
      fakeBackend({});

      await mountRoutes(tester, at: '/support/new');

      expect(find.text(bottomNavLabel), findsOneWidget);
    });
  });

  group('attachments', () {
    const ValueKey<String> attach = ValueKey<String>('support-attach');
    const ValueKey<String> send = ValueKey<String>('support-send');

    List<SentRequest> threadBackend({List<Map<String, dynamic>>? messages}) {
      return fakeBackend({
        'GET /support/conversations/7': (_) => ok(
          conversationJson(
            id: 7,
            messages: messages ?? <Map<String, dynamic>>[messageJson()],
          ),
        ),
        'POST /support/conversations/7/seen': (_) => ok(null),
        'POST /support/conversations/7/messages': (request) => ok(
          messageJson(
            id: 99,
            body: ((request.data as Map)['body'] as String?) ?? '',
            attachments: <Map<String, dynamic>>[attachmentJson(id: 31)],
          ),
        ),
        'POST /support/conversations/7/attachments/12/link': (_) =>
            Http.response(<String, dynamic>{
              'url': 'https://api.example.com/signed?sig=1',
            }),
      });
    }

    Map<String, dynamic> imageMessage() => messageJson(
      id: 2,
      senderType: 'staff',
      body: 'Here is the screenshot',
      attachments: <Map<String, dynamic>>[attachmentJson()],
    );

    Future<void> pick(WidgetTester tester) async {
      await tester.tap(find.byKey(attach));
      await tester.pumpAndSettle();
    }

    testWidgets('the thread shows no attach button while the flag is off', (
      tester,
    ) async {
      threadBackend();

      await mount(tester, at: '/support/7');

      expect(find.byKey(attach), findsNothing);
    });

    testWidgets(
      'the create view shows no attach button while the flag is off',
      (tester) async {
        fakeBackend({});

        await mount(tester, at: '/support/new');

        expect(find.byKey(attach), findsNothing);
      },
    );

    group('with the flag on', () {
      setUp(() {
        Config.set('magic_starter.features.support_attachments', true);
        Config.set(
          'network.drivers.api.base_url',
          'https://api.example.com/v1',
        );
      });

      testWidgets('the picker is asked for the shipped extensions only', (
        tester,
      ) async {
        threadBackend();
        List<String>? asked;

        await mount(
          tester,
          at: '/support/7',
          pickFiles: (extensions) async {
            asked = extensions;

            return <MagicFile>[];
          },
        );
        await pick(tester);

        expect(asked, <String>['jpg', 'jpeg', 'png', 'webp', 'pdf']);
      });

      testWidgets('a picked file shows as a chip with its size and can go', (
        tester,
      ) async {
        threadBackend();

        await mount(
          tester,
          at: '/support/7',
          pickFiles: (_) async => <MagicFile>[
            pickedFile('error.png', bytes: 1536),
          ],
        );
        await pick(tester);

        expect(find.text('error.png'), findsOneWidget);
        expect(find.text('1.5 KB'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey<String>('support-attachment-remove-0')),
        );
        await tester.pumpAndSettle();

        expect(find.text('error.png'), findsNothing);
      });

      testWidgets('a fourth file shows the limit error and sends nothing', (
        tester,
      ) async {
        final sent = threadBackend();

        await mount(
          tester,
          at: '/support/7',
          pickFiles: (_) async => <MagicFile>[
            for (var i = 1; i <= 4; i++) pickedFile('shot$i.png'),
          ],
        );
        await pick(tester);
        await tester.tap(find.byKey(send));
        await tester.pumpAndSettle();

        expect(
          find.text(
            trans('magic_starter.support.attachment_too_many', {'max': 3}),
          ),
          findsOneWidget,
        );
        expect(count(sent, 'POST', '/support/conversations/7/messages'), 0);
      });

      testWidgets('a file over 5 MB shows the size error and sends nothing', (
        tester,
      ) async {
        final sent = threadBackend();

        await mount(
          tester,
          at: '/support/7',
          pickFiles: (_) async => <MagicFile>[
            pickedFile('huge.png', bytes: 16, size: 5 * 1024 * 1024 + 1),
          ],
        );
        await pick(tester);
        await tester.tap(find.byKey(send));
        await tester.pumpAndSettle();

        expect(
          find.text(
            trans('magic_starter.support.attachment_too_large', {
              'name': 'huge.png',
              'max': 5,
            }),
          ),
          findsOneWidget,
        );
        expect(count(sent, 'POST', '/support/conversations/7/messages'), 0);
      });

      testWidgets('an image-only reply is sent and the chips clear', (
        tester,
      ) async {
        final sent = threadBackend();

        await mount(
          tester,
          at: '/support/7',
          pickFiles: (_) async => <MagicFile>[pickedFile('error.png')],
        );
        await pick(tester);
        await tester.tap(find.byKey(send));
        await tester.pumpAndSettle();

        final post = sent.singleWhere(
          (s) =>
              s.method == 'POST' &&
              s.url == '/support/conversations/7/messages',
        );
        final Map data = post.data! as Map;
        expect(data.keys, contains('attachments[0]'));
        expect(data.keys, isNot(contains('body')));
        expect(find.text('error.png'), findsNothing);
      });

      testWidgets('the create view posts the picked files with the message', (
        tester,
      ) async {
        final sent = fakeBackend({
          'GET /support/conversations': (_) => ok(<Map<String, dynamic>>[]),
          'POST /support/conversations': (_) => ok(
            conversationJson(
              id: 9,
              messages: <Map<String, dynamic>>[messageJson(body: 'See file')],
            ),
          ),
          'GET /support/conversations/9': (_) => ok(conversationJson(id: 9)),
          'POST /support/conversations/9/seen': (_) => ok(null),
        });

        await mount(
          tester,
          at: '/support/new',
          pickFiles: (_) async => <MagicFile>[pickedFile('error.png')],
        );
        await pick(tester);
        await tester.enterText(find.byType(EditableText), 'See file');
        await tester.pump();
        await tester.tap(
          find.text(trans('magic_starter.support.create_submit')),
        );
        await tester.pumpAndSettle();

        final post = sent.singleWhere(
          (s) => s.method == 'POST' && s.url == '/support/conversations',
        );
        final Map data = post.data! as Map;
        expect(data['body'], 'See file');
        expect(data.keys, contains('attachments[0]'));
      });

      testWidgets('a bubble shows the image through the bearer header', (
        tester,
      ) async {
        threadBackend(messages: <Map<String, dynamic>>[imageMessage()]);
        await Auth.login(<String, dynamic>{
          'token': 'abc123',
        }, MagicStarterAuthUser());

        await mount(tester, at: '/support/7');

        final Image image = tester.widget<Image>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('support-attachment-11')),
            matching: find.byType(Image),
          ),
        );
        final NetworkImage provider = image.image as NetworkImage;
        expect(
          provider.url,
          'https://api.example.com/v1/support/conversations/7/attachments/11',
        );
        expect(provider.headers, <String, String>{
          'Authorization': 'Bearer abc123',
        });
      });

      testWidgets('tapping the thumbnail opens it full size', (tester) async {
        threadBackend(messages: <Map<String, dynamic>>[imageMessage()]);

        await mount(tester, at: '/support/7');
        expect(find.byType(Image), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey<String>('support-attachment-11')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsNWidgets(2));
      });

      testWidgets('a PDF is an untrusted chip that opens the signed link', (
        tester,
      ) async {
        final launcher = _RecordingLaunchAdapter();
        Magic.singleton('launch', () => LaunchService(adapter: launcher));
        final sent = threadBackend(
          messages: <Map<String, dynamic>>[
            messageJson(
              id: 2,
              senderType: 'staff',
              body: 'The invoice',
              attachments: <Map<String, dynamic>>[
                attachmentJson(id: 12, name: 'invoice.pdf', kind: 'pdf'),
              ],
            ),
          ],
        );

        await mount(tester, at: '/support/7');

        expect(find.text('invoice.pdf'), findsOneWidget);
        expect(
          find.text(trans('magic_starter.support.attachment_untrusted')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('support-attachment-12')),
        );
        await tester.pumpAndSettle();

        expect(
          count(sent, 'POST', '/support/conversations/7/attachments/12/link'),
          1,
        );
        expect(launcher.launched, <Uri>[
          Uri.parse('https://api.example.com/signed?sig=1'),
        ]);
        // Opened after the link request, so a new web window is a popup Safari
        // blocks; the current tab downloads it and stays where it was.
        expect(launcher.windowNames, <String?>['_self']);
      });

      testWidgets('attachments wrap from one shared start edge, evenly spaced', (
        tester,
      ) async {
        threadBackend(
          messages: <Map<String, dynamic>>[
            messageJson(
              id: 2,
              body: 'Three files',
              attachments: <Map<String, dynamic>>[
                attachmentJson(id: 21, name: 'one.png'),
                attachmentJson(
                  id: 22,
                  name: 'a-fairly-long-invoice-name.pdf',
                  kind: 'pdf',
                ),
                attachmentJson(id: 23, name: 'two.png'),
              ],
            ),
          ],
        );

        await mount(tester, at: '/support/7');

        final List<Rect> items = <Rect>[
          for (final int id in <int>[21, 22, 23])
            tester.getRect(
              find.byKey(ValueKey<String>('support-attachment-$id')),
            ),
        ];
        final double firstRowTop = items.first.top;
        final List<Rect> firstRow = items
            .where((Rect r) => r.top == firstRowTop)
            .toList();
        final List<Rect> laterRows = items
            .where((Rect r) => r.top != firstRowTop)
            .toList();

        // The pdf chip is wide enough to push the last image onto a second row.
        expect(laterRows, isNotEmpty);
        for (final Rect row in laterRows) {
          expect(row.left, firstRow.first.left);
        }
        for (var i = 1; i < firstRow.length; i++) {
          expect(firstRow[i].left - firstRow[i - 1].right, 8);
        }
        expect(laterRows.first.top - firstRow.first.bottom, 8);
      });
    });

    testWidgets('a bubble shows no attachment while the flag is off', (
      tester,
    ) async {
      threadBackend(messages: <Map<String, dynamic>>[imageMessage()]);

      await mount(tester, at: '/support/7');

      expect(find.text('Here is the screenshot'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('support-attachment-11')),
        findsNothing,
      );
    });
  });

  group('the rating block', () {
    const ValueKey<String> block = ValueKey<String>('support-rating');
    const ValueKey<String> submit = ValueKey<String>('support-rating-submit');

    Map<String, dynamic> ratingJson(String value, {String? comment}) =>
        <String, dynamic>{
          'value': value,
          'comment': comment,
          'rated_at': '2026-10-12T10:00:00+00:00',
        };

    List<SentRequest> backend({
      String status = 'resolved',
      bool canRate = true,
      Map<String, dynamic>? rating,
    }) {
      return fakeBackend({
        'GET /support/conversations/7': (_) => ok(
          conversationJson(
            id: 7,
            status: status,
            canRate: canRate,
            rating: rating,
            messages: <Map<String, dynamic>>[messageJson()],
          ),
        ),
        'POST /support/conversations/7/seen': (_) => ok(null),
        'POST /support/conversations/7/rating': (_) => ok(null),
      });
    }

    setUp(() => Config.set('magic_starter.features.support_csat', true));

    testWidgets('is absent while the flag is off', (tester) async {
      Config.set('magic_starter.features.support_csat', false);
      backend();

      await mount(tester, at: '/support/7');

      expect(find.byKey(block), findsNothing);
    });

    testWidgets('is absent on a conversation that is not resolved', (
      tester,
    ) async {
      backend(status: 'open');

      await mount(tester, at: '/support/7');

      expect(find.byKey(block), findsNothing);
    });

    testWidgets('is absent when it cannot be rated and has no rating', (
      tester,
    ) async {
      backend(canRate: false);

      await mount(tester, at: '/support/7');

      expect(find.byKey(block), findsNothing);
    });

    testWidgets('posts the chosen value and thanks the customer', (
      tester,
    ) async {
      final sent = backend();

      await mount(tester, at: '/support/7');

      expect(find.byKey(block), findsOneWidget);
      expect(
        find.text(trans('magic_starter.support.rating_prompt')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('support-rating-down')),
      );
      await tester.pump();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('support-rating-comment')),
          matching: find.byType(EditableText),
        ),
        'Too slow',
      );
      await tester.pump();
      await tester.tap(find.byKey(submit));
      await tester.pumpAndSettle();

      final post = sent.singleWhere(
        (s) => s.method == 'POST' && s.url == '/support/conversations/7/rating',
      );
      expect(post.data, <String, dynamic>{
        'rating': 'down',
        'comment': 'Too slow',
      });
      expect(
        find.byKey(const ValueKey<String>('support-rating-thanks')),
        findsOneWidget,
      );
    });

    testWidgets('the thumbs and the send button are 44 tall on a phone', (
      tester,
    ) async {
      backend();

      await mount(tester, at: '/support/7', size: const Size(390, 2400));

      for (final String key in <String>[
        'support-rating-up',
        'support-rating-down',
        'support-rating-submit',
      ]) {
        expect(
          tester.getSize(find.byKey(ValueKey<String>(key))).height,
          greaterThanOrEqualTo(44),
          reason: key,
        );
      }
    });

    testWidgets('does nothing until a thumb is chosen', (tester) async {
      final sent = backend();

      await mount(tester, at: '/support/7');
      await tester.tap(find.byKey(submit));
      await tester.pumpAndSettle();

      expect(count(sent, 'POST', '/support/conversations/7/rating'), 0);
    });

    testWidgets('an existing rating shows its choice and can be changed', (
      tester,
    ) async {
      final sent = backend(
        canRate: false,
        rating: ratingJson('up', comment: 'Great help'),
      );

      await mount(tester, at: '/support/7');

      expect(find.byKey(block), findsOneWidget);
      expect(find.text('Great help'), findsOneWidget);
      expect(
        find.text(trans('magic_starter.support.rating_update')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('support-rating-down')),
      );
      await tester.pump();
      await tester.tap(find.byKey(submit));
      await tester.pumpAndSettle();

      final post = sent.singleWhere(
        (s) => s.method == 'POST' && s.url == '/support/conversations/7/rating',
      );
      expect((post.data as Map)['rating'], 'down');
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

    group('feedback and store review', () {
      setUp(() {
        Config.set('magic_starter.features.support_feedback', true);
        Config.set('magic_starter.features.store_review', true);
        MagicStarterStoreReview.debugIsWebOverride = false;
        Auth.fake(
          user: MagicStarterAuthUser.fromMap(<String, dynamic>{
            'id': 5,
            'name': 'Ada Lovelace',
            'email': 'ada@example.com',
            'email_verified_at': '2026-10-01T09:00:00+00:00',
          }),
        );
      });

      tearDown(MagicStarterStoreReview.resetForTesting);

      testWidgets('offers Send feedback when the feature is on', (
        tester,
      ) async {
        await openMenu(tester);

        expect(find.text(trans('magic_starter.nav.feedback')), findsOneWidget);
      });

      testWidgets('offers no Send feedback to a guest', (tester) async {
        Auth.fake(
          user: MagicStarterAuthUser.fromMap(<String, dynamic>{
            'id': 6,
            'is_guest': true,
          }),
        );

        await openMenu(tester);

        expect(find.text(trans('magic_starter.nav.feedback')), findsNothing);
      });

      testWidgets('offers no Send feedback to an unverified email', (
        tester,
      ) async {
        Auth.fake(
          user: MagicStarterAuthUser.fromMap(<String, dynamic>{
            'id': 7,
            'name': 'Grace',
            'email': 'grace@example.com',
            'email_verified_at': null,
          }),
        );

        await openMenu(tester);

        expect(find.text(trans('magic_starter.nav.feedback')), findsNothing);
      });

      testWidgets('offers no Send feedback when the feature is off', (
        tester,
      ) async {
        Config.set('magic_starter.features.support_feedback', false);

        await openMenu(tester);

        expect(find.text(trans('magic_starter.nav.feedback')), findsNothing);
      });

      testWidgets('offers Rate us on a device', (tester) async {
        await openMenu(tester);

        expect(find.text(trans('magic_starter.nav.rate_us')), findsOneWidget);
      });

      testWidgets('hides Rate us on the web', (tester) async {
        MagicStarterStoreReview.debugIsWebOverride = true;

        await openMenu(tester);

        expect(find.text(trans('magic_starter.nav.rate_us')), findsNothing);
      });
    });
  });

  group('the feedback page', () {
    setUp(() {
      Config.set('magic_starter.features.support_feedback', true);
    });

    tearDown(MagicStarterStoreReview.resetForTesting);

    Future<void> mountRoutes(WidgetTester tester, {required String at}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 2000);
      addTearDown(tester.view.reset);

      Kernel.register('auth', AllowAllMiddleware.new);
      addTearDown(Kernel.flush);
      MagicStarter.view.registerLayout('layout.app', (child) => child);

      registerMagicStarterSupportRoutes();
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

    testWidgets('resolves to the feedback form, not to a thread', (
      tester,
    ) async {
      final sent = fakeBackend({
        'GET /support/feedback': (_) =>
            Http.response(<String, dynamic>{'eligible': false}),
      });

      await mountRoutes(tester, at: '/support/feedback');

      expect(
        find.text(trans('magic_starter.support.feedback_question')),
        findsOneWidget,
      );
      expect(count(sent, 'GET', '/support/conversations/feedback'), 0);
    });

    testWidgets('posts the chosen score', (tester) async {
      final sent = fakeBackend({
        'POST /support/feedback': (_) =>
            Http.response(<String, dynamic>{'conversation_id': null}),
      });
      await mountRoutes(tester, at: '/support/feedback');

      await tester.tap(find.byKey(const ValueKey<String>('feedback-score-8')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('feedback-submit')));
      await tester.pumpAndSettle();

      final post = sent.singleWhere((s) => s.method == 'POST');
      expect((post.data! as Map)['score'], 8);
    });

    test('is not registered while the feature is off', () {
      Config.set('magic_starter.features.support_feedback', false);

      registerMagicStarterSupportRoutes();

      expect(
        MagicRouter.instance.allRoutes.map((route) => route.fullPath),
        isNot(contains(magicStarterSupportFeedbackRoute())),
      );
    });
  });

  group('diagnostics on the create view', () {
    const ValueKey<String> screenshot = ValueKey<String>('support-screenshot');
    const ValueKey<String> removeScreenshot = ValueKey<String>(
      'support-screenshot-remove',
    );

    /// A real 1x1 PNG, so the preview decodes what a capture would hold.
    final Uint8List png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );

    late List<SentRequest> sent;

    setUp(() {
      Config.set('magic_starter.features.support_diagnostics', true);
      PackageInfo.setMockInitialValues(
        appName: 'Uptizm',
        packageName: 'com.example.app',
        version: '2.3.0',
        buildNumber: '45',
        buildSignature: '',
      );
      MagicStarterScreenCapture.resetForTesting();
      MagicStarterScreenCapture.holder.debugHold(png, route: '/monitors/3');

      sent = fakeBackend({
        'POST /support/conversations': (_) => ok(
          conversationJson(
            id: 9,
            messages: <Map<String, dynamic>>[messageJson()],
          ),
        ),
        'GET /support/conversations/9': (_) => ok(conversationJson(id: 9)),
        'POST /support/conversations/9/seen': (_) => ok(null),
      });
    });

    tearDown(MagicStarterScreenCapture.resetForTesting);

    Future<Map> send(WidgetTester tester) async {
      await tester.enterText(find.byType(EditableText), 'It broke');
      await tester.pump();
      await tester.tap(find.text(trans('magic_starter.support.create_submit')));
      await tester.pumpAndSettle();

      return sent
              .singleWhere(
                (s) => s.method == 'POST' && s.url == '/support/conversations',
              )
              .data!
          as Map;
    }

    testWidgets('shows the screenshot and sends it with the client info', (
      tester,
    ) async {
      await mount(tester, at: '/support/new');

      expect(find.byKey(screenshot), findsOneWidget);

      final data = await send(tester);

      final MagicFile file = data['screenshot'] as MagicFile;
      expect(file.name, 'screenshot.png');
      expect(file.mimeType, 'image/png');
      expect(data['client_context[route]'], '/monitors/3');
      expect(data['client_context[app_version]'], '2.3.0');
      expect(data['client_context[build_number]'], '45');
      expect(data['client_context[platform]'], isNotEmpty);
      expect(data['client_context[locale]'], 'en');
      expect(data['client_context[timezone]'], isNotEmpty);
    });

    testWidgets('remove drops the screenshot but keeps the client info', (
      tester,
    ) async {
      await mount(tester, at: '/support/new');

      await tester.tap(find.byKey(removeScreenshot));
      await tester.pumpAndSettle();

      expect(find.byKey(screenshot), findsNothing);
      expect(MagicStarterScreenCapture.holder.bytes, isNull);

      final data = await send(tester);

      expect(data.containsKey('screenshot'), isFalse);
      expect((data['client_context'] as Map)['route'], '/monitors/3');
    });

    testWidgets('a sent screenshot is not offered again', (tester) async {
      await mount(tester, at: '/support/new');

      await send(tester);

      expect(MagicStarterScreenCapture.holder.bytes, isNull);
    });

    testWidgets('a screenshot that arrives after the page opened is shown', (
      tester,
    ) async {
      MagicStarterScreenCapture.holder.clear();
      await mount(tester, at: '/support/new');
      expect(find.byKey(screenshot), findsNothing);

      MagicStarterScreenCapture.holder.debugHold(png, route: '/monitors/3');
      await tester.pumpAndSettle();

      expect(find.byKey(screenshot), findsOneWidget);
    });

    testWidgets('a refused screenshot is explained under its preview', (
      tester,
    ) async {
      fakeBackend({
        'POST /support/conversations': (_) => Http.response(<String, dynamic>{
          'message': 'The screenshot is too large.',
          'errors': <String, dynamic>{
            'screenshot': <String>['The screenshot is too large.'],
          },
        }, 422),
      });
      await mount(tester, at: '/support/new');

      await tester.enterText(find.byType(EditableText), 'It broke');
      await tester.pump();
      await tester.tap(find.text(trans('magic_starter.support.create_submit')));
      await tester.pumpAndSettle();

      expect(find.text('The screenshot is too large.'), findsOneWidget);
      expect(find.byKey(screenshot), findsOneWidget);
    });

    testWidgets('an error on an unplaced field falls back to the write error', (
      tester,
    ) async {
      fakeBackend({
        'POST /support/conversations': (_) => Http.response(<String, dynamic>{
          'message': 'The client_context.route field is too long.',
          'errors': <String, dynamic>{
            'client_context.route': <String>['The route is too long.'],
          },
        }, 422),
      });
      await mount(tester, at: '/support/new');

      await tester.enterText(find.byType(EditableText), 'It broke');
      await tester.pump();
      await tester.tap(find.text(trans('magic_starter.support.create_submit')));
      await tester.pumpAndSettle();

      expect(
        find.text(trans('magic_starter.support.create_error')),
        findsOneWidget,
      );
    });

    testWidgets('sends neither while the flag is off', (tester) async {
      Config.set('magic_starter.features.support_diagnostics', false);

      await mount(tester, at: '/support/new');

      expect(find.byKey(screenshot), findsNothing);

      final data = await send(tester);

      expect(data.containsKey('screenshot'), isFalse);
      expect(data.containsKey('client_context'), isFalse);
    });
  });
}
