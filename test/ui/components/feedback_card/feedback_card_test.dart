import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/feedback_card/feedback_card.preview.dart';

/// The package's own English copy, so the card renders real prose.
class _ShippedLoader implements TranslationLoader {
  const _ShippedLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final raw = File(
      '${Directory.current.path}/assets/stubs/install/en.stub',
    ).readAsStringSync();

    return _flatten(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Map<String, dynamic> _flatten(
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

typedef _Sent = ({String method, String url, Object? data});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<_Sent> sent;

  /// Fakes `support/feedback`: [eligible] answers the read, [conversationId]
  /// the write.
  void backend({bool eligible = true, Object? conversationId}) {
    sent = <_Sent>[];
    Http.fake((request) {
      sent.add((method: request.method, url: request.url, data: request.data));

      if (request.method == 'GET') {
        return Http.response(<String, dynamic>{'eligible': eligible});
      }

      return Http.response(<String, dynamic>{
        'conversation_id': conversationId,
      });
    });
  }

  List<_Sent> posts() => sent.where((s) => s.method == 'POST').toList();

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    MagicStarterStoreReview.resetForTesting();

    Magic.singleton('log', () => LogManager());
    Config.set('logging', <String, dynamic>{
      'default': 'console',
      'channels': <String, dynamic>{
        'console': <String, dynamic>{'driver': 'console', 'level': 'debug'},
      },
    });
    Config.set('magic_starter.features.support', true);
    Config.set('magic_starter.features.support_feedback', true);
    Auth.fake(
      user: MagicStarterAuthUser.fromMap(<String, dynamic>{
        'id': 5,
        'name': 'Ada Lovelace',
      }),
    );

    Translator.instance.setLoader(const _ShippedLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    MagicStarterStoreReview.resetForTesting();
    Http.unfake();
    Auth.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  Future<void> mount(WidgetTester tester, Widget card) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(),
          child: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const ValueKey<String> submit = ValueKey<String>('feedback-submit');
  const ValueKey<String> dismiss = ValueKey<String>('feedback-dismiss');

  testWidgets('shows the question once the backend says it is due', (
    tester,
  ) async {
    backend();

    await mount(tester, const MSFeedbackCard());

    expect(
      find.text(trans('magic_starter.support.feedback_question')),
      findsOneWidget,
    );
    for (var score = 0; score <= 10; score++) {
      expect(
        find.byKey(ValueKey<String>('feedback-score-$score')),
        findsOneWidget,
      );
    }
    expect(MagicStarterStoreReview.feedbackCardShown, isTrue);
  });

  testWidgets('shows nothing and records nothing when it is not due', (
    tester,
  ) async {
    backend(eligible: false);

    await mount(tester, const MSFeedbackCard());

    expect(find.byKey(submit), findsNothing);
    expect(MagicStarterStoreReview.feedbackCardShown, isFalse);
  });

  testWidgets('a guest is never asked and never shown the card', (
    tester,
  ) async {
    backend();
    Auth.fake(
      user: MagicStarterAuthUser.fromMap(<String, dynamic>{
        'id': 6,
        'is_guest': true,
      }),
    );

    await mount(tester, const MSFeedbackCard());

    expect(sent, isEmpty);
    expect(find.byKey(submit), findsNothing);
    expect(MagicStarterStoreReview.feedbackCardShown, isFalse);
  });

  testWidgets('posts the chosen score with the comment and thanks', (
    tester,
  ) async {
    backend();
    await mount(tester, const MSFeedbackCard());

    await tester.tap(find.byKey(const ValueKey<String>('feedback-score-9')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('feedback-comment')),
      'Fast and clear',
    );
    await tester.tap(find.byKey(submit));
    await tester.pumpAndSettle();

    final post = posts().single;
    expect(post.url, '/support/feedback');
    expect((post.data! as Map)['score'], 9);
    expect((post.data! as Map)['comment'], 'Fast and clear');
    expect(
      find.text(trans('magic_starter.support.feedback_thanks')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('feedback-conversation')),
      findsNothing,
    );
  });

  testWidgets('sends nothing until a score is chosen', (tester) async {
    backend();
    await mount(tester, const MSFeedbackCard());

    await tester.tap(find.byKey(submit));
    await tester.pumpAndSettle();

    expect(posts(), isEmpty);
  });

  testWidgets('a low score offers the conversation it opened', (tester) async {
    backend(conversationId: 'c-42');
    await mount(tester, const MSFeedbackCard());

    await tester.tap(find.byKey(const ValueKey<String>('feedback-score-2')));
    await tester.pump();
    await tester.tap(find.byKey(submit));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('feedback-conversation')),
      findsOneWidget,
    );
  });

  testWidgets('Not now posts a dismissal and the card goes away', (
    tester,
  ) async {
    backend();
    await mount(tester, const MSFeedbackCard());

    await tester.tap(find.byKey(dismiss));
    await tester.pumpAndSettle();

    final post = posts().single;
    expect((post.data! as Map).containsKey('score'), isTrue);
    expect((post.data! as Map)['score'], isNull);
    expect(find.byKey(submit), findsNothing);
  });

  testWidgets('on demand it asks without reading eligibility and offers no '
      'dismissal', (tester) async {
    backend(eligible: false);

    await mount(tester, const MSFeedbackCard(onDemand: true));

    expect(sent.where((s) => s.method == 'GET'), isEmpty);
    expect(find.byKey(submit), findsOneWidget);
    expect(find.byKey(dismiss), findsNothing);
  });

  testWidgets('the preview builds', (tester) async {
    backend();

    await mount(tester, const FeedbackCardPreview());

    expect(find.byType(MSFeedbackCard), findsWidgets);
  });
}
