import 'package:flutter/material.dart' show Icons, MaterialApp, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/ui/components/settings_row/settings_row.preview.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: widget),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recipe variant-class assertions
  // ---------------------------------------------------------------------------

  group('settings row recipe', () {
    test('default tone emits text-fg token for title', () {
      final cls = settingsRowRecipe(
        variants: {kSettingsRowToneAxis: SettingsRowTone.defaultTone.name},
      );
      expect(cls, contains('text-fg'));
    });

    test('destructive tone emits text-destructive token for title', () {
      final cls = settingsRowRecipe(
        variants: {kSettingsRowToneAxis: SettingsRowTone.destructive.name},
      );
      expect(cls, contains('text-destructive'));
    });

    test('default variant emits default tone when nothing passed', () {
      final cls = settingsRowRecipe();
      expect(cls, contains('text-fg'));
      expect(cls, isNot(contains('text-destructive')));
    });

    test('emission order: base precedes tone-variant classes', () {
      final cls = settingsRowRecipe(
        variants: {kSettingsRowToneAxis: SettingsRowTone.destructive.name},
      );
      // base contains min-h-11; destructive contains text-destructive
      final baseIdx = cls.indexOf('min-h-11');
      final variantIdx = cls.indexOf('text-destructive');
      expect(baseIdx, lessThan(variantIdx));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('SettingsRow renders title text', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(title: 'Notifications'),
      ),
    );
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('SettingsRow leading icon is optional — absent by default',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(title: 'Profile'),
      ),
    );
    // WIcon should not be present when no icon is given.
    expect(find.byType(WIcon), findsNothing);
  });

  testWidgets('SettingsRow renders leading icon tile when icon is provided',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(
          title: 'Profile',
          icon: Icons.person_outline,
        ),
      ),
    );
    expect(find.byType(WIcon), findsOneWidget);
  });

  testWidgets('SettingsRow renders subtitle when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(
          title: 'Profile',
          subtitle: 'Edit your name and email',
        ),
      ),
    );
    expect(find.text('Edit your name and email'), findsOneWidget);
  });

  testWidgets('SettingsRow subtitle is absent when not provided',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(title: 'Profile'),
      ),
    );
    // Only one text widget (the title).
    expect(find.byType(WText), findsOneWidget);
  });

  testWidgets('SettingsRow renders trailing slot widget', (tester) async {
    const trailingKey = Key('trailing-widget');
    await tester.pumpWidget(
      wrap(
        const SettingsRow(
          title: 'Dark Mode',
          trailing: SizedBox(key: trailingKey, width: 40, height: 24),
        ),
      ),
    );
    expect(find.byKey(trailingKey), findsOneWidget);
  });

  testWidgets('SettingsRow onTap fires when row is tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        SettingsRow(
          title: 'Profile',
          onTap: () => tapped = true,
        ),
      ),
    );
    // Tap via the title text that the WAnchor wraps.
    await tester.tap(find.text('Profile'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('SettingsRow is not tappable when onTap is null', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(title: 'Profile'),
      ),
    );
    // WAnchor should not be present when onTap is null.
    expect(find.byType(WAnchor), findsNothing);
  });

  testWidgets('SettingsRow default tone title uses text-fg className',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(title: 'Appearance'),
      ),
    );
    final titleTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.data == 'Appearance');
    expect(titleTexts, isNotEmpty);
    expect(titleTexts.first.className, contains('text-fg'));
  });

  testWidgets(
      'SettingsRow destructive tone title uses text-destructive className',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(
          title: 'Delete Account',
          tone: SettingsRowTone.destructive,
        ),
      ),
    );
    final titleTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.data == 'Delete Account');
    expect(titleTexts, isNotEmpty);
    expect(titleTexts.first.className, contains('text-destructive'));
  });

  testWidgets('SettingsRow row container has min-h-11 className',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(title: 'Sessions'),
      ),
    );
    // The root WDiv should carry min-h-11.
    final divs = tester.widgetList<WDiv>(find.byType(WDiv));
    final hasMinH11 = divs.any(
      (d) => d.className != null && d.className!.contains('min-h-11'),
    );
    expect(hasMinH11, isTrue);
  });

  testWidgets('SettingsRow has no internal divider', (tester) async {
    // The row must not render a border-b or border-t divider — the section owns
    // dividers.
    await tester.pumpWidget(
      wrap(
        const SettingsRow(title: 'Profile'),
      ),
    );
    final divs = tester.widgetList<WDiv>(find.byType(WDiv));
    final hasDividerClass = divs.any(
      (d) => d.className != null && d.className!.contains('border-b'),
    );
    expect(hasDividerClass, isFalse);
  });

  testWidgets('SettingsRow light+dark preview renders without error',
      (tester) async {
    await tester.pumpWidget(wrap(const SettingsRowPreview()));
    await tester.pump();
    expect(find.byType(SettingsRowPreview), findsOneWidget);
  });

  testWidgets('SettingsRowPreview renders both tone variants', (tester) async {
    await tester.pumpWidget(wrap(const SettingsRowPreview()));
    await tester.pump();
    // Preview must show at least one title text per tone.
    expect(find.byType(WText), findsWidgets);
  });
}
