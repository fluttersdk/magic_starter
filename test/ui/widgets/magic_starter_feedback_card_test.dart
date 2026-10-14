import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

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

/// The semantic aliases the card's recipe names, which a host app's theme
/// defines (`design:sync` writes them) and wind's defaults do not.
const Map<String, String> _semanticAliases = <String, String>{
  'bg-primary': 'bg-primary-500',
  'text-on-primary': 'text-white',
  'bg-surface-container-high': 'bg-gray-200',
  'border-color-border': 'border-gray-300',
  'text-fg': 'text-gray-900',
  'text-fg-disabled': 'text-gray-400',
};

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

  Future<void> mount(
    WidgetTester tester,
    Widget card, {
    Size size = const Size(800, 1200),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(
            colors: <String, MaterialColor>{'primary': Colors.green},
            aliases: _semanticAliases,
          ),
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

    await mount(tester, const MagicStarterFeedbackCard());

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

    await mount(tester, const MagicStarterFeedbackCard());

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

    await mount(tester, const MagicStarterFeedbackCard());

    expect(sent, isEmpty);
    expect(find.byKey(submit), findsNothing);
    expect(MagicStarterStoreReview.feedbackCardShown, isFalse);
  });

  testWidgets('posts the chosen score with the comment and thanks', (
    tester,
  ) async {
    backend();
    await mount(tester, const MagicStarterFeedbackCard());

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
    await mount(tester, const MagicStarterFeedbackCard());

    await tester.tap(find.byKey(submit));
    await tester.pumpAndSettle();

    expect(posts(), isEmpty);
  });

  testWidgets('a low score offers the conversation it opened', (tester) async {
    backend(conversationId: 'c-42');
    await mount(tester, const MagicStarterFeedbackCard());

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
    await mount(tester, const MagicStarterFeedbackCard());

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

    await mount(tester, const MagicStarterFeedbackCard(onDemand: true));

    expect(sent.where((s) => s.method == 'GET'), isEmpty);
    expect(find.byKey(submit), findsOneWidget);
    expect(find.byKey(dismiss), findsNothing);
  });

  group('on a phone', () {
    const Size phone = Size(390, 844);

    testWidgets('every score is a tap target of at least 44 x 44', (
      tester,
    ) async {
      backend();
      await mount(tester, const MagicStarterFeedbackCard(), size: phone);

      for (var score = 0; score <= 10; score++) {
        final Size size = tester.getSize(
          find.byKey(ValueKey<String>('feedback-score-$score')),
        );

        expect(size.width, greaterThanOrEqualTo(44), reason: 'score $score');
        expect(size.height, greaterThanOrEqualTo(44), reason: 'score $score');
      }
    });

    testWidgets('the send and Not now buttons are at least 44 tall', (
      tester,
    ) async {
      backend();
      await mount(tester, const MagicStarterFeedbackCard(), size: phone);

      expect(
        tester.getSize(find.byKey(submit)).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.byKey(dismiss)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('the scale wraps inside the card without overflowing', (
      tester,
    ) async {
      backend();
      await mount(tester, const MagicStarterFeedbackCard(), size: phone);

      final Rect card = tester.getRect(
        find.byKey(const ValueKey<String>('feedback-card')),
      );
      for (var score = 0; score <= 10; score++) {
        final Rect rect = tester.getRect(
          find.byKey(ValueKey<String>('feedback-score-$score')),
        );

        expect(card.contains(rect.topLeft), isTrue, reason: 'score $score');
        expect(card.contains(rect.bottomRight), isTrue, reason: 'score $score');
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('each score is exactly one button, named by its number', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      backend();
      await mount(tester, const MagicStarterFeedbackCard());

      final List<String> names = _buttonNames(tester);

      for (var score = 0; score <= 10; score++) {
        expect(
          names.where((String name) => name == '$score'),
          hasLength(1),
          reason: 'score $score',
        );
      }
      handle.dispose();
    });

    testWidgets('the chosen score is announced as selected', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      backend();
      await mount(tester, const MagicStarterFeedbackCard());

      await tester.tap(find.byKey(const ValueKey<String>('feedback-score-7')));
      await tester.pump();

      final List<SemanticsNode> selected = _buttonNodes(tester)
          .where(
            (SemanticsNode n) =>
                n.getSemanticsData().flagsCollection.isSelected ==
                Tristate.isTrue,
          )
          .toList();

      expect(selected, hasLength(1));
      expect(selected.single.getSemanticsData().label, '7');
      handle.dispose();
    });

    testWidgets('the focused score thickens its border', (tester) async {
      backend();
      await mount(tester, const MagicStarterFeedbackCard());

      final Finder score = find.byKey(
        const ValueKey<String>('feedback-score-0'),
      );
      BorderSide borderOf() =>
          (_decorationUnder(
                    score,
                    (BoxDecoration d) => d.border != null,
                  ).border!
                  as Border)
              .top;

      final BorderSide resting = borderOf();

      tester
          .widget<Focus>(
            find.descendant(of: score, matching: find.byType(Focus)).first,
          )
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();

      expect(borderOf().width, greaterThan(resting.width));
      expect(borderOf().color, isNot(equals(resting.color)));
    });
  });

  group('control states', () {
    /// The fill of the button's or the chip's own surface.
    Color? fillOf(Finder owner) =>
        _decorationUnder(owner, (BoxDecoration d) => d.color != null).color;

    testWidgets('Send feedback looks disabled until a score is chosen', (
      tester,
    ) async {
      backend();
      await mount(tester, const MagicStarterFeedbackCard());

      final Color? disabled = fillOf(find.byKey(submit));

      await tester.tap(find.byKey(const ValueKey<String>('feedback-score-4')));
      await tester.pump();

      final Color? enabled = fillOf(find.byKey(submit));

      expect(disabled, isNotNull);
      expect(disabled, isNot(equals(enabled)));
    });

    testWidgets('the chosen score is filled with the primary colour', (
      tester,
    ) async {
      backend();
      await mount(tester, const MagicStarterFeedbackCard());

      final Finder score = find.byKey(
        const ValueKey<String>('feedback-score-4'),
      );
      final Color? idle = fillOf(score);

      await tester.tap(score);
      await tester.pump();

      final Color? selected = fillOf(score);

      expect(selected, isNotNull);
      expect(selected, isNot(equals(idle)));
      expect(selected, fillOf(find.byKey(submit)));
    });
  });
}

/// The accessible name of every button node the platform would receive.
///
/// A node carrying `isMergedIntoParent` is folded into its parent and never
/// sent to assistive technology, so counting one reports a control that does
/// not exist.
List<String> _buttonNames(WidgetTester tester) => _buttonNodes(
  tester,
).map((SemanticsNode node) => node.getSemanticsData().label).toList();

List<SemanticsNode> _buttonNodes(WidgetTester tester) {
  final List<SemanticsNode> found = <SemanticsNode>[];

  void walk(SemanticsNode node) {
    if (!node.isMergedIntoParent &&
        node.getSemanticsData().flagsCollection.isButton) {
      found.add(node);
    }
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(tester.getSemantics(find.byType(MaterialApp)));

  return found;
}

/// The first box decoration under [owner] that [matches] accepts.
BoxDecoration _decorationUnder(
  Finder owner,
  bool Function(BoxDecoration decoration) matches,
) {
  for (final Element element
      in find
          .descendant(
            of: owner,
            matching: find.byWidgetPredicate((Widget _) => true),
          )
          .evaluate()) {
    final Widget widget = element.widget;
    final Decoration? decoration = switch (widget) {
      Container() => widget.decoration,
      DecoratedBox() => widget.decoration,
      _ => null,
    };

    if (decoration is BoxDecoration && matches(decoration)) return decoration;
  }

  throw StateError('no matching box under the finder');
}
