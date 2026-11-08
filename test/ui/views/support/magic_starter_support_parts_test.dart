import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// The fixtures and the fake backend are the views test's own, so a payload
// the views read is the payload these parts read.
import 'magic_starter_support_views_test.dart'
    show SentRequest, conversationJson, count, fakeBackend, messageJson, ok;

class _ShippedLoader implements TranslationLoader {
  const _ShippedLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final File stub = File(
      '${Directory.current.path}/assets/stubs/install/en.stub',
    );

    return _flatten(
      jsonDecode(stub.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
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
}

const ValueKey<String> _typing = ValueKey<String>('support-typing');
const ValueKey<String> _send = ValueKey<String>('support-send');

MagicStarterSupportConversation _conversation({
  int id = 7,
  bool awaitingAi = false,
  List<Map<String, dynamic>>? messages,
}) {
  return MagicStarterSupportConversation.fromMap(
    conversationJson(
      id: id,
      awaitingAi: awaitingAi,
      messages:
          messages ??
          <Map<String, dynamic>>[
            messageJson(id: 1, body: 'My monitor will not save'),
            messageJson(id: 2, senderType: 'staff', body: 'Looking now'),
          ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MagicStarterSupportController controller;

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

    controller = Magic.put(MagicStarterSupportController());
  });

  tearDown(() {
    Auth.unfake();
    Http.unfake();
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  /// Mounts [part] with no router and no page chrome, in a panel-sized box.
  Future<void> mountPart(
    WidgetTester tester,
    Widget part, {
    Size size = const Size(400, 700),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            WindTheme(data: WindThemeData(), child: child!),
        home: Scaffold(body: part),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reply(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await tester.pump();
    await tester.tap(find.byKey(_send));
  }

  group('the thread body', () {
    testWidgets(
      'draws the given conversation and replies on its own surface without '
      'reading a thread',
      (tester) async {
        final List<SentRequest> sent = fakeBackend({
          'POST /support/conversations/7/messages': (request) => ok(
            messageJson(id: 9, body: (request.data as Map)['body'] as String),
          ),
        });

        await mountPart(
          tester,
          MagicStarterSupportThreadBody(
            conversation: _conversation(),
            surface: 'chat',
          ),
        );

        expect(find.text('My monitor will not save'), findsOneWidget);
        expect(find.text('Looking now'), findsOneWidget);

        await reply(tester, 'A second line');
        await tester.pumpAndSettle();

        expect(sent.map((s) => '${s.method} ${s.url}'), <String>[
          'POST /support/conversations/7/messages',
        ], reason: 'no GET of the thread, and never an empty id');
        expect(sent.single.data, <String, dynamic>{'body': 'A second line'});
        expect(controller.isSubmittingFor('chat'), isFalse);
      },
    );

    testWidgets('a chat reply is not refused while the page surface writes', (
      tester,
    ) async {
      final Completer<MagicResponse> pageWrite = Completer<MagicResponse>();
      final List<String> sent = <String>[];
      Http.fake((MagicRequest request) {
        sent.add('${request.method} ${request.url}');
        if (request.url == '/support/conversations/7/rating') {
          return pageWrite.future;
        }

        return Future<MagicResponse>.value(ok(messageJson(id: 9)));
      });

      await mountPart(
        tester,
        MagicStarterSupportThreadBody(
          conversation: _conversation(),
          surface: 'chat',
        ),
      );

      unawaited(controller.rate(7, 'up'));
      await tester.pump();
      expect(controller.isSubmittingFor('page'), isTrue);

      await reply(tester, 'Still there?');
      await tester.pump();
      await tester.pump();

      expect(sent, contains('POST /support/conversations/7/messages'));

      pageWrite.complete(ok(null));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'the same reply on the page surface is refused while it writes',
      (tester) async {
        // The control for the case above: without it, "not refused" could mean
        // the lock never refuses anything.
        final Completer<MagicResponse> pageWrite = Completer<MagicResponse>();
        final List<String> sent = <String>[];
        Http.fake((MagicRequest request) {
          sent.add('${request.method} ${request.url}');
          if (request.url == '/support/conversations/7/rating') {
            return pageWrite.future;
          }

          return Future<MagicResponse>.value(ok(messageJson(id: 9)));
        });

        await mountPart(
          tester,
          MagicStarterSupportThreadBody(conversation: _conversation()),
        );

        unawaited(controller.rate(7, 'up'));
        await tester.pump();

        await reply(tester, 'Still there?');
        await tester.pump();
        await tester.pump();

        expect(sent, isNot(contains('POST /support/conversations/7/messages')));

        pageWrite.complete(ok(null));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('mounting it leaves the page errors on the controller', (
      tester,
    ) async {
      fakeBackend({
        'POST /support/conversations/7/rating': (_) =>
            Http.response(<String, dynamic>{}, 500),
      });
      await controller.rate(7, 'up');
      final String? refusal = controller.writeError;
      expect(refusal, isNotNull);

      await mountPart(
        tester,
        MagicStarterSupportThreadBody(conversation: _conversation()),
      );

      expect(controller.writeError, refusal);
      expect(find.text(refusal!), findsOneWidget);
    });

    testWidgets('shows the typing bubble while the AI owes an answer, then '
        'the slow note after 45 seconds', (tester) async {
      fakeBackend({});

      await mountPart(
        tester,
        MagicStarterSupportThreadBody(
          conversation: _conversation(awaitingAi: true),
        ),
      );

      expect(find.byKey(_typing), findsOneWidget);
      expect(
        find.text(trans('magic_starter.support.taking_longer')),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 44));
      expect(find.byKey(_typing), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text(trans('magic_starter.support.taking_longer')),
        findsOneWidget,
      );
      expect(find.byKey(_typing), findsNothing);
    });

    testWidgets('shows no typing bubble once the AI is not pending', (
      tester,
    ) async {
      fakeBackend({});

      await mountPart(
        tester,
        MagicStarterSupportThreadBody(conversation: _conversation()),
      );

      expect(find.byKey(_typing), findsNothing);
    });

    testWidgets('scrolls to the newest message when one arrives', (
      tester,
    ) async {
      fakeBackend({});
      MagicStarterSupportConversation crowded(int lines) => _conversation(
        messages: <Map<String, dynamic>>[
          for (var i = 1; i <= lines; i++)
            messageJson(id: i, body: 'Line $i', senderType: 'staff'),
        ],
      );

      await mountPart(
        tester,
        MagicStarterSupportThreadBody(conversation: crowded(30)),
      );

      final ScrollPosition position = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller!
          .position;
      final double before = position.maxScrollExtent;
      expect(before, greaterThan(0));
      expect(position.pixels, before);

      await mountPart(
        tester,
        MagicStarterSupportThreadBody(conversation: crowded(31)),
      );

      expect(position.maxScrollExtent, greaterThan(before));
      expect(position.pixels, position.maxScrollExtent);
      final Rect newest = tester.getRect(find.text('Line 31'));
      expect(newest.bottom, lessThanOrEqualTo(700));
      expect(newest.top, greaterThanOrEqualTo(0));
    });
  });

  group('the create form', () {
    Map<String, dynamic> refusal() => <String, dynamic>{
      'message': 'The given data was invalid.',
      'errors': <String, dynamic>{
        'topic': <String>['The topic field is required.'],
      },
    };

    testWidgets('hands the created conversation to the host and goes nowhere', (
      tester,
    ) async {
      final List<SentRequest> sent = fakeBackend({
        'POST /support/conversations': (_) =>
            ok(conversationJson(id: 9, subject: 'Please help')),
      });
      final List<MagicStarterSupportConversation> created =
          <MagicStarterSupportConversation>[];

      MagicRoute.page(
        '/start',
        () => Scaffold(
          body: SingleChildScrollView(
            child: MagicStarterSupportCreateForm(onCreated: created.add),
          ),
        ),
      );
      MagicRoute.page(
        MagicStarterConfig.supportThreadRoute(),
        () => const Text('THREAD PAGE'),
      );
      MagicRouter.instance.setInitialLocation('/start');
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: MagicRouter.instance.routerConfig,
          builder: (context, child) =>
              WindTheme(data: WindThemeData(), child: child!),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText), 'Please help');
      await tester.pump();
      await tester.tap(find.text(trans('magic_starter.support.create_submit')));
      await tester.pumpAndSettle();

      expect(created.map((c) => c.id), <Object?>[9]);
      expect(count(sent, 'POST', '/support/conversations'), 1);
      expect(find.text('THREAD PAGE'), findsNothing);
      expect(find.byType(MagicStarterSupportCreateForm), findsOneWidget);
    });

    testWidgets('writes under the surface it was given', (tester) async {
      final Completer<MagicResponse> held = Completer<MagicResponse>();
      Http.fake((MagicRequest request) => held.future);

      await mountPart(
        tester,
        SingleChildScrollView(
          child: MagicStarterSupportCreateForm(
            onCreated: (_) {},
            surface: 'chat',
          ),
        ),
      );

      await tester.enterText(find.byType(EditableText), 'Please help');
      await tester.pump();
      await tester.tap(find.text(trans('magic_starter.support.create_submit')));
      await tester.pump();

      expect(controller.isSubmittingFor('chat'), isTrue);
      expect(controller.isSubmitting, isFalse);

      held.complete(ok(conversationJson(id: 9)));
      await tester.pumpAndSettle();
    });

    testWidgets('mounting it leaves a refusal the page already holds', (
      tester,
    ) async {
      fakeBackend({
        'POST /support/conversations': (_) => Http.response(refusal(), 422),
      });
      await controller.createConversation(body: 'x', source: 'in_app');
      expect(controller.getError('topic'), isNotNull);

      await mountPart(
        tester,
        SingleChildScrollView(
          child: MagicStarterSupportCreateForm(onCreated: (_) {}),
        ),
      );

      expect(controller.getError('topic'), 'The topic field is required.');
      expect(find.text('The topic field is required.'), findsOneWidget);
    });

    testWidgets('the topic chips are 44 tall on a phone', (tester) async {
      fakeBackend({});

      await mountPart(
        tester,
        SingleChildScrollView(
          child: MagicStarterSupportCreateForm(onCreated: (_) {}),
        ),
        size: const Size(390, 1400),
      );

      for (final String topic in MagicStarterConfig.supportTopics()) {
        expect(
          tester
              .getSize(find.byKey(ValueKey<String>('support-topic-$topic')))
              .height,
          greaterThanOrEqualTo(44),
          reason: topic,
        );
      }
    });

    group('in a bounded panel box', () {
      const ValueKey<String> host = ValueKey<String>('create-host');
      final String firstTopic = MagicStarterConfig.supportTopics().first;

      Finder send() => find.ancestor(
        of: find.text(trans('magic_starter.support.create_submit')),
        matching: find.byType(MSButton),
      );

      Finder topicChip() =>
          find.byKey(ValueKey<String>('support-topic-$firstTopic'));

      Finder article(String slug) =>
          find.byKey(ValueKey<String>('support-article-$slug'));

      void expectInside(WidgetTester tester, Finder inner, Finder outer) {
        final Rect box = tester.getRect(outer);
        final Rect rect = tester.getRect(inner);

        expect(rect.top, greaterThanOrEqualTo(box.top));
        expect(rect.bottom, lessThanOrEqualTo(box.bottom));
        expect(rect.left, greaterThanOrEqualTo(box.left));
        expect(rect.right, lessThanOrEqualTo(box.right));
      }

      Future<void> typeMessage(WidgetTester tester) async {
        await tester.enterText(
          find.byType(EditableText),
          'My monitor will not save',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
      }

      Future<void> mountCompact(WidgetTester tester) async {
        await mountPart(
          tester,
          SizedBox(
            key: host,
            width: 400,
            height: 520,
            child: MagicStarterSupportCreateForm(
              compact: true,
              onCreated: (_) {},
            ),
          ),
          size: const Size(400, 520),
        );
      }

      Map<String, dynamic> suggestion(String slug) => <String, dynamic>{
        'id': slug,
        'slug': slug,
        'question': 'Question $slug',
        'excerpt': 'Excerpt $slug',
        'url': null,
      };

      testWidgets('keeps Send in view while the fields scroll above it', (
        tester,
      ) async {
        fakeBackend({
          'GET /support/articles': (_) => ok(<Map<String, dynamic>>[
            for (final String slug in <String>['a', 'b', 'c']) suggestion(slug),
          ]),
        });
        await mountCompact(tester);
        await typeMessage(tester);

        expect(article('c'), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expectInside(tester, send(), find.byKey(host));

        final Rect buttonBefore = tester.getRect(send());
        final Rect chipBefore = tester.getRect(topicChip());

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pump();

        expect(tester.getRect(topicChip()).top, lessThan(chipBefore.top));
        expect(tester.getRect(send()), buttonBefore);
        expect(tester.takeException(), isNull);
      });

      testWidgets('is not wrapped in a card; the panel is the card', (
        tester,
      ) async {
        fakeBackend({});
        await mountCompact(tester);

        expect(
          find.descendant(
            of: find.byType(MagicStarterSupportCreateForm),
            matching: find.byType(MSCard),
          ),
          findsNothing,
        );
      });

      testWidgets('a long validation error does not push Send out', (
        tester,
      ) async {
        final String long = List<String>.filled(
          40,
          'The message could not be accepted',
        ).join(' ');
        fakeBackend({
          'POST /support/conversations': (_) => Http.response(<String, dynamic>{
            'message': 'The given data was invalid.',
            'errors': <String, dynamic>{
              'body': <String>[long],
            },
          }, 422),
        });
        await mountCompact(tester);
        await tester.enterText(find.byType(EditableText), 'Short');
        await tester.pump();

        await tester.tap(send());
        await tester.pumpAndSettle();

        expect(find.text(long), findsOneWidget);
        expectInside(tester, send(), find.byKey(host));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the page form stays a card with Send after the articles', (
        tester,
      ) async {
        fakeBackend({
          'GET /support/articles': (_) => ok(<Map<String, dynamic>>[
            for (final String slug in <String>['a', 'b', 'c']) suggestion(slug),
          ]),
        });
        await mountPart(
          tester,
          SingleChildScrollView(
            child: MagicStarterSupportCreateForm(onCreated: (_) {}),
          ),
          size: const Size(400, 1400),
        );
        await typeMessage(tester);

        expect(
          find.descendant(
            of: find.byType(MagicStarterSupportCreateForm),
            matching: find.byType(MSCard),
          ),
          findsOneWidget,
        );
        expect(
          tester.getRect(send()).top,
          greaterThanOrEqualTo(tester.getRect(article('c')).bottom),
        );
      });
    });
  });
}
