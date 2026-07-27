import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/ui/components/upgrade_dialog/index.dart';
import 'package:magic_starter/src/ui/components/upgrade_dialog/upgrade_dialog.preview.dart';

/// Feeds the upsell copy so [trans] returns real English prose instead of the
/// raw key tokens.
class _UpgradeDialogLangLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async => {
    'uptizm.common.upgrade_available_on': 'Available on :plan and up.',
    'uptizm.common.upgrade': 'Upgrade',
    'uptizm.common.upgrade_dialog_not_now': 'Not now',
  };
}

void main() {
  setUp(() async {
    Translator.instance.setLoader(_UpgradeDialogLangLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  Widget wrap(Widget widget, {double width = 390}) => MaterialApp(
    home: WindTheme(
      data: WindThemeData(),
      child: Scaffold(
        body: SizedBox(
          width: width,
          child: SingleChildScrollView(child: widget),
        ),
      ),
    ),
  );

  testWidgets('renders the message and the plan line', (tester) async {
    await tester.pumpWidget(
      wrap(
        MSUpgradeDialog(
          message: "You've reached your 3-responder limit.",
          requiredPlan: 'Pro',
          onUpgrade: () {},
          onDismiss: () {},
        ),
      ),
    );

    expect(find.text("You've reached your 3-responder limit."), findsOneWidget);
    expect(find.text('Available on Pro and up.'), findsOneWidget);
  });

  testWidgets('tapping Upgrade fires onUpgrade', (tester) async {
    var upgraded = false;

    await tester.pumpWidget(
      wrap(
        MSUpgradeDialog(
          message: "You've reached your 3-responder limit.",
          requiredPlan: 'Pro',
          onUpgrade: () => upgraded = true,
          onDismiss: () {},
        ),
      ),
    );

    await tester.tap(find.text('Upgrade'));
    await tester.pump();

    expect(upgraded, isTrue);
  });

  testWidgets('tapping the dismiss button fires onDismiss', (tester) async {
    var dismissed = false;

    await tester.pumpWidget(
      wrap(
        MSUpgradeDialog(
          message: "You've reached your 3-responder limit.",
          requiredPlan: 'Pro',
          onUpgrade: () {},
          onDismiss: () => dismissed = true,
        ),
      ),
    );

    await tester.tap(find.text('Not now'));
    await tester.pump();

    expect(dismissed, isTrue);
  });

  testWidgets('does not overflow at a 390px width', (tester) async {
    await tester.pumpWidget(
      wrap(
        MSUpgradeDialog(
          message:
              'AI Auto mode resolves incidents on its own, without waiting '
              'for a human responder to pick them up first.',
          requiredPlan: 'Business',
          onUpgrade: () {},
          onDismiss: () {},
        ),
        width: 390,
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('preview renders every plan label without error', (tester) async {
    await tester.pumpWidget(wrap(const UpgradeDialogPreview()));

    expect(find.byType(MSUpgradeDialog), findsNWidgets(3));
    expect(find.text('Available on Pro and up.'), findsOneWidget);
    expect(find.text('Available on Business and up.'), findsOneWidget);
    expect(find.text('Available on Enterprise and up.'), findsOneWidget);
  });
}
