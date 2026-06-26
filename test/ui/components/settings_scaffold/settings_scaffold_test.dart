import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/magic_starter_manager.dart';
import 'package:magic_starter/src/ui/components/settings_scaffold/settings_scaffold.dart';
import 'package:magic_starter/src/ui/components/settings_scaffold/settings_scaffold.recipe.dart';
import 'package:magic_starter/src/ui/components/settings_scaffold/settings_scaffold.preview.dart';

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
        child: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Recipe assertions (pure unit tests — no widget pump required)
  // -------------------------------------------------------------------------

  group('SettingsScaffoldRecipe', () {
    test('scrollable recipe emits w-full token', () {
      final cls = settingsScaffoldScrollableRecipe();
      expect(cls, contains('w-full'));
    });

    test('container recipe emits max-w-2xl token', () {
      final cls = settingsScaffoldContainerRecipe();
      expect(cls, contains('max-w-2xl'));
    });

    test('container recipe emits mx-auto token', () {
      final cls = settingsScaffoldContainerRecipe();
      expect(cls, contains('mx-auto'));
    });

    test('container recipe emits px-4 token', () {
      final cls = settingsScaffoldContainerRecipe();
      expect(cls, contains('px-4'));
    });

    test('children area recipe emits mt-6 token', () {
      final cls = settingsScaffoldChildrenAreaRecipe();
      expect(cls, contains('mt-6'));
    });

    test('children area recipe emits flex-col token', () {
      final cls = settingsScaffoldChildrenAreaRecipe();
      expect(cls, contains('flex-col'));
    });

    test('children area recipe emits gap-6 token', () {
      final cls = settingsScaffoldChildrenAreaRecipe();
      expect(cls, contains('gap-6'));
    });
  });

  // -------------------------------------------------------------------------
  // Widget tests
  // -------------------------------------------------------------------------

  testWidgets('SettingsScaffold renders title via PageHeader', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsScaffold(
          title: 'Profile',
          children: [],
        ),
      ),
    );
    // PageHeader renders the title as a WText.
    final titleTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.data == 'Profile')
        .toList();
    expect(titleTexts, isNotEmpty);
  });

  testWidgets('SettingsScaffold renders icon-only back via PageHeader',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsScaffold(
          title: 'Profile',
          backLabel: 'Settings',
          backFallback: '/settings',
          children: [],
        ),
      ),
    );
    // Icon-only back: chevron renders, parent label text is NOT shown.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('SettingsScaffold renders no back when backLabel is null',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsScaffold(
          title: 'Settings',
          children: [],
        ),
      ),
    );
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('SettingsScaffold renders child widgets', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsScaffold(
          title: 'Profile',
          children: [
            Text('Section 1'),
            Text('Section 2'),
          ],
        ),
      ),
    );
    expect(find.text('Section 1'), findsOneWidget);
    expect(find.text('Section 2'), findsOneWidget);
  });

  testWidgets('SettingsScaffold children area uses gap-6 column className',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsScaffold(
          title: 'Profile',
          children: [Text('Child')],
        ),
      ),
    );
    // The children-area WDiv must carry `gap-6` and `flex-col`.
    final childArea = tester
        .widgetList<WDiv>(find.byType(WDiv))
        .where(
          (w) =>
              w.className?.contains('gap-6') == true &&
              w.className?.contains('flex-col') == true,
        )
        .toList();
    expect(childArea, isNotEmpty);
  });

  testWidgets('SettingsScaffold outer container has max-w-2xl and mx-auto',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsScaffold(
          title: 'Profile',
          children: [],
        ),
      ),
    );
    // The centered constrained column WDiv must carry both tokens.
    final constrainedDivs = tester
        .widgetList<WDiv>(find.byType(WDiv))
        .where(
          (w) =>
              w.className?.contains('max-w-2xl') == true &&
              w.className?.contains('mx-auto') == true,
        )
        .toList();
    expect(constrainedDivs, isNotEmpty);
  });

  testWidgets('SettingsScaffold uses SingleChildScrollView with primary: false',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsScaffold(
          title: 'Profile',
          children: [],
        ),
      ),
    );
    // There must be exactly one non-primary SingleChildScrollView
    // (primary: false is required to avoid PrimaryScrollController contention).
    final scrollViews = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((sv) => sv.primary == false)
        .toList();
    expect(scrollViews, isNotEmpty);
  });

  testWidgets('SettingsScaffold renders subtitle via PageHeader when provided',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsScaffold(
          title: 'Profile',
          subtitle: 'Manage your account',
          children: [],
        ),
      ),
    );
    final subtitleTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.data == 'Manage your account')
        .toList();
    expect(subtitleTexts, isNotEmpty);
  });

  testWidgets('SettingsScaffoldPreview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScaffoldPreview()));
    await tester.pump();
    expect(find.byType(SettingsScaffoldPreview), findsOneWidget);
  });
}
