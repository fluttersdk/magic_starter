import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/magic_starter_manager.dart';
import 'package:magic_starter/src/ui/components/settings_section/settings_section.dart';
import 'package:magic_starter/src/ui/components/settings_section/settings_section.recipe.dart';
import 'package:magic_starter/src/ui/components/settings_section/settings_section.preview.dart';

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

  group('SettingsSectionRecipe', () {
    test('container recipe emits bg-surface-container token', () {
      final cls = settingsSectionContainerRecipe();
      expect(cls, contains('bg-surface-container'));
    });

    test('container recipe emits rounded-lg token', () {
      final cls = settingsSectionContainerRecipe();
      expect(cls, contains('rounded-lg'));
    });

    test('container recipe emits border-color-border-subtle token', () {
      final cls = settingsSectionContainerRecipe();
      expect(cls, contains('border-color-border-subtle'));
    });

    test('container recipe emits overflow-hidden token', () {
      final cls = settingsSectionContainerRecipe();
      expect(cls, contains('overflow-hidden'));
    });

    test('caption recipe emits text-xs token', () {
      final cls = settingsSectionCaptionRecipe();
      expect(cls, contains('text-xs'));
    });

    test('caption recipe emits uppercase token', () {
      final cls = settingsSectionCaptionRecipe();
      expect(cls, contains('uppercase'));
    });

    test('caption recipe emits text-fg-muted token', () {
      final cls = settingsSectionCaptionRecipe();
      expect(cls, contains('text-fg-muted'));
    });

    test('divider recipe emits border-color-border-subtle token', () {
      final cls = settingsSectionDividerRecipe();
      expect(cls, contains('border-color-border-subtle'));
    });

    test('emission order: base precedes variant classes in container recipe',
        () {
      final cls = settingsSectionContainerRecipe();
      final baseIdx = cls.indexOf('bg-surface-container');
      final roundedIdx = cls.indexOf('rounded-lg');
      expect(baseIdx, lessThan(roundedIdx));
    });
  });

  // -------------------------------------------------------------------------
  // Widget tests
  // -------------------------------------------------------------------------

  testWidgets('SettingsSection renders a single child', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSection(
          children: [
            Text('Row 1'),
          ],
        ),
      ),
    );
    expect(find.text('Row 1'), findsOneWidget);
  });

  testWidgets('SettingsSection renders header caption when provided',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSection(
          header: 'Account',
          children: [Text('Row 1')],
        ),
      ),
    );
    // Wind applies the `uppercase` CSS token at the style layer — the Flutter
    // RichText/Text widget receives the source string unchanged; find by the
    // original value rather than the CSS-transformed display string.
    final headerTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.data == 'Account')
        .toList();
    expect(headerTexts, isNotEmpty);
  });

  testWidgets('SettingsSection does not render header when omitted',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSection(
          children: [Text('Row 1')],
        ),
      ),
    );
    // No WText carrying the caption className should be present.
    final captionTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.className?.contains('uppercase') == true)
        .toList();
    expect(captionTexts, isEmpty);
  });

  testWidgets('SettingsSection renders footer caption when provided',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSection(
          footer: 'Manage your personal information.',
          children: [Text('Row 1')],
        ),
      ),
    );
    final footerTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.data == 'Manage your personal information.')
        .toList();
    expect(footerTexts, isNotEmpty);
  });

  testWidgets('SettingsSection renders N children', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSection(
          children: [
            Text('Row 1'),
            Text('Row 2'),
            Text('Row 3'),
          ],
        ),
      ),
    );
    expect(find.text('Row 1'), findsOneWidget);
    expect(find.text('Row 2'), findsOneWidget);
    expect(find.text('Row 3'), findsOneWidget);
  });

  testWidgets('SettingsSection inserts N-1 dividers between N children',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSection(
          children: [
            Text('Row 1'),
            Text('Row 2'),
            Text('Row 3'),
          ],
        ),
      ),
    );
    // 3 children => 2 dividers. Dividers carry `border-t border-color-border-subtle`
    // as their full className (the container carries more classes including it, so
    // we filter by the `border-t` token which is unique to divider WDivs).
    final dividers = tester
        .widgetList<WDiv>(find.byType(WDiv))
        .where((w) => w.className?.contains('border-t') == true)
        .toList();
    expect(dividers.length, equals(2));
  });

  testWidgets('SettingsSection with single child has no dividers',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSection(
          children: [Text('Only row')],
        ),
      ),
    );
    final dividers = tester
        .widgetList<WDiv>(find.byType(WDiv))
        .where((w) => w.className?.contains('border-t') == true)
        .toList();
    expect(dividers.length, equals(0));
  });

  testWidgets('SettingsSection container uses bg-surface-container className',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSection(
          children: [Text('Row 1')],
        ),
      ),
    );
    // The container WDiv should carry the bg-surface-container token.
    final containers = tester
        .widgetList<WDiv>(find.byType(WDiv))
        .where((w) => w.className?.contains('bg-surface-container') == true)
        .toList();
    expect(containers, isNotEmpty);
  });

  testWidgets('SettingsSection header WText carries uppercase token',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSection(
          header: 'Security',
          children: [Text('Row 1')],
        ),
      ),
    );
    final headerTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.className?.contains('uppercase') == true)
        .toList();
    expect(headerTexts, isNotEmpty);
  });

  testWidgets('SettingsSection light+dark tokens present in container',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsSection(
          header: 'Preferences',
          footer: 'Choose your preferences.',
          children: [Text('Row 1'), Text('Row 2')],
        ),
      ),
    );
    // Semantic alias tokens (bg-surface-container, text-fg-muted,
    // border-color-border-subtle) handle dark mode automatically — confirm
    // they appear in the widget tree.
    final containerDivs = tester
        .widgetList<WDiv>(find.byType(WDiv))
        .where((w) => w.className?.contains('bg-surface-container') == true)
        .toList();
    expect(containerDivs, isNotEmpty);

    final captionTexts = tester
        .widgetList<WText>(find.byType(WText))
        .where((w) => w.className?.contains('text-fg-muted') == true)
        .toList();
    expect(captionTexts, isNotEmpty);
  });

  testWidgets('SettingsSectionPreview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const SettingsSectionPreview()));
    await tester.pump();
    expect(find.byType(SettingsSectionPreview), findsOneWidget);
  });
}
