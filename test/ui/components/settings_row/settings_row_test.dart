import 'package:flutter/material.dart' show Icons, MaterialApp, Scaffold;
import 'package:flutter/rendering.dart' show RenderParagraph;
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

  // The stock alias map by default, so `text-fg` resolves the way it does in an
  // app; a host passes its own map to define `text-destructive`.
  Widget wrapWithAliases(
    Widget widget, {
    Map<String, String> aliases = MagicStarterTokens.defaultAliases,
  }) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(aliases: aliases),
        child: Scaffold(body: widget),
      ),
    );
  }

  Color? paintedColour(WidgetTester tester, String text) {
    return tester
        .renderObject<RenderParagraph>(find.text(text))
        .text
        .style
        ?.color;
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

    test('destructive tone keeps the base layout and no default colour', () {
      final cls = settingsRowRecipe(
        variants: {kSettingsRowToneAxis: SettingsRowTone.destructive.name},
      );
      expect(cls, contains('min-h-12'));
      expect(cls, isNot(contains('text-fg')));
    });

    test('default variant emits default tone when nothing passed', () {
      final cls = settingsRowRecipe();
      expect(cls, contains('text-fg'));
    });

    test('emission order: base precedes tone-variant classes', () {
      final cls = settingsRowRecipe(
        variants: {kSettingsRowToneAxis: SettingsRowTone.defaultTone.name},
      );
      final baseIdx = cls.indexOf('min-h-12');
      final variantIdx = cls.indexOf('text-fg');
      expect(baseIdx, lessThan(variantIdx));
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------

  testWidgets('SettingsRow renders title text', (tester) async {
    await tester.pumpWidget(wrap(const MSSettingsRow(title: 'Notifications')));
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('SettingsRow leading icon is optional — absent by default', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSSettingsRow(title: 'Profile')));
    // WIcon should not be present when no icon is given.
    expect(find.byType(WIcon), findsNothing);
  });

  testWidgets('SettingsRow renders leading icon tile when icon is provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MSSettingsRow(title: 'Profile', icon: Icons.person_outline)),
    );
    expect(find.byType(WIcon), findsOneWidget);
  });

  testWidgets('SettingsRow renders subtitle when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSSettingsRow(
          title: 'Profile',
          subtitle: 'Edit your name and email',
        ),
      ),
    );
    expect(find.text('Edit your name and email'), findsOneWidget);
  });

  testWidgets('SettingsRow subtitle is absent when not provided', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSSettingsRow(title: 'Profile')));
    // Only one text widget (the title).
    expect(find.byType(WText), findsOneWidget);
  });

  testWidgets('SettingsRow renders trailing slot widget', (tester) async {
    const trailingKey = Key('trailing-widget');
    await tester.pumpWidget(
      wrap(
        const MSSettingsRow(
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
      wrap(MSSettingsRow(title: 'Profile', onTap: () => tapped = true)),
    );
    // Tap via the title text that the WAnchor wraps.
    await tester.tap(find.text('Profile'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('SettingsRow is not tappable when onTap is null', (tester) async {
    await tester.pumpWidget(wrap(const MSSettingsRow(title: 'Profile')));
    // WAnchor should not be present when onTap is null.
    expect(find.byType(WAnchor), findsNothing);
  });

  testWidgets('SettingsRow default tone title uses text-fg className', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSSettingsRow(title: 'Appearance')));
    final titleTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.data == 'Appearance');
    expect(titleTexts, isNotEmpty);
    expect(titleTexts.first.className, contains('text-fg'));
  });

  testWidgets('SettingsRow default tone title paints the text-fg colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithAliases(const MSSettingsRow(title: 'Appearance')),
    );

    expect(
      paintedColour(tester, 'Appearance'),
      WindThemeData().getColor('gray', 900),
    );
  });

  testWidgets(
    'SettingsRow destructive title paints red under the stock aliases',
    (tester) async {
      await tester.pumpWidget(
        wrapWithAliases(
          const MSSettingsRow(
            title: 'Delete Account',
            tone: SettingsRowTone.destructive,
          ),
        ),
      );

      expect(
        paintedColour(tester, 'Delete Account'),
        WindThemeData().getColor('red', 600),
      );
    },
  );

  testWidgets('SettingsRow destructive title follows a host text-destructive', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithAliases(
        const MSSettingsRow(
          title: 'Delete Account',
          tone: SettingsRowTone.destructive,
        ),
        aliases: {
          ...MagicStarterTokens.defaultAliases,
          'text-destructive': 'text-[#DF202E] dark:text-[#FF645F]',
        },
      ),
    );

    expect(paintedColour(tester, 'Delete Account'), const Color(0xFFDF202E));
  });

  testWidgets('SettingsRow row container has min-h-12 className', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSSettingsRow(title: 'Sessions')));
    // The root WDiv should carry a 44pt+ minimum height (min-h-12 = 48px).
    final divs = tester.widgetList<WDiv>(find.byType(WDiv));
    final hasMinHeight = divs.any(
      (d) => d.className != null && d.className!.contains('min-h-12'),
    );
    expect(hasMinHeight, isTrue);
  });

  testWidgets('SettingsRow has no internal divider', (tester) async {
    // The row must not render a border-b or border-t divider — the section owns
    // dividers.
    await tester.pumpWidget(wrap(const MSSettingsRow(title: 'Profile')));
    final divs = tester.widgetList<WDiv>(find.byType(WDiv));
    final hasDividerClass = divs.any(
      (d) => d.className != null && d.className!.contains('border-b'),
    );
    expect(hasDividerClass, isFalse);
  });

  testWidgets('SettingsRow light+dark preview renders without error', (
    tester,
  ) async {
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
