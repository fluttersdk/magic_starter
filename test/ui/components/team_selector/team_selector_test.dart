import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/team_selector/team_selector.preview.dart';

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

  testWidgets('TeamSelector returns empty when no resolver registered', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSTeamSelector()));
    await tester.pump();
    // When no resolver, renders SizedBox.shrink
    expect(find.byType(WPopover), findsNothing);
  });

  testWidgets('TeamSelector renders team initial when resolver has teams', (
    tester,
  ) async {
    final teams = [
      MagicStarterTeam.fromMap({
        'id': 1,
        'name': 'Acme Corp',
        'personal_team': false,
      }),
      MagicStarterTeam.fromMap({
        'id': 2,
        'name': 'Beta Inc',
        'personal_team': false,
      }),
    ];
    MagicStarter.useTeamResolver(
      currentTeam: () => teams.first,
      allTeams: () => teams,
      onSwitch: (id) async {},
    );

    await tester.pumpWidget(wrap(const MSTeamSelector()));
    await tester.pump();

    // The first letter of 'Acme Corp' is shown as the team initial
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('TeamSelector returns empty when teams list is empty', (
    tester,
  ) async {
    MagicStarter.useTeamResolver(
      currentTeam: () => null,
      allTeams: () => [],
      onSwitch: (id) async {},
    );

    await tester.pumpWidget(wrap(const MSTeamSelector()));
    await tester.pump();

    expect(find.byType(WPopover), findsNothing);
  });

  testWidgets('TeamSelector preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const TeamSelectorPreview()));
    await tester.pump();
    expect(find.byType(TeamSelectorPreview), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Panel: corner clipping and theme-supplied colour.
  // ---------------------------------------------------------------------------

  group('panel', () {
    final teams = [
      MagicStarterTeam.fromMap({
        'id': 1,
        'name': 'Acme Corp',
        'personal_team': false,
      }),
      MagicStarterTeam.fromMap({
        'id': 2,
        'name': 'Beta Inc',
        'personal_team': false,
      }),
    ];

    /// A host palette whose every role is a distinct hex, so a resolved colour
    /// names the role it came from.
    final hostTheme = WindThemeData(
      aliases: const {
        'bg-surface': 'bg-[#101012] dark:bg-[#101012]',
        'bg-surface-container': 'bg-[#202024] dark:bg-[#202024]',
        'bg-surface-container-high': 'bg-[#303036] dark:bg-[#303036]',
        'text-fg': 'text-[#f0f0f4] dark:text-[#f0f0f4]',
        'text-fg-muted': 'text-[#a0a0a8] dark:text-[#a0a0a8]',
        'border-color-border': 'border-[#404048] dark:border-[#404048]',
        'bg-destructive-container': 'bg-[#7f1d1d] dark:bg-[#7f1d1d]',
        'text-destructive': 'text-[#dc2626] dark:text-[#dc2626]',
      },
    );

    Widget wrapWith(WindThemeData data) {
      return MaterialApp(
        home: WindTheme(
          data: data,
          child: const Scaffold(body: MSTeamSelector()),
        ),
      );
    }

    Future<void> open(WidgetTester tester, {WindThemeData? data}) async {
      MagicStarter.useTeamResolver(
        currentTeam: () => teams.first,
        allTeams: () => teams,
        onSwitch: (id) async {},
      );

      await tester.pumpWidget(
        data == null ? wrap(const MSTeamSelector()) : wrapWith(data),
      );
      await tester.pump();
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
    }

    Finder panel() => find.byWidgetPredicate(
      (widget) => widget is WDiv && (widget.className ?? '').contains('w-58'),
    );

    Finder rowOf(String label) => find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is WDiv && (widget.className ?? '').contains('py-2.5'),
          ),
        )
        .first;

    /// The [WText] that draws [label]; `find.text` lands on the inner `Text`.
    Finder wtext(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(WText)).first;

    /// Every fill painted under [owner], outermost first.
    List<Color> fillsOf(WidgetTester tester, Finder owner) => [
      for (final box in tester.widgetList<DecoratedBox>(
        find.descendant(of: owner, matching: find.byType(DecoratedBox)),
      ))
        if (box.decoration is BoxDecoration &&
            (box.decoration as BoxDecoration).color != null)
          (box.decoration as BoxDecoration).color!,
    ];

    /// Every className the selector hands to Wind, trigger and open panel.
    Iterable<String> classNames(WidgetTester tester) {
      final scopes = [find.byType(MSTeamSelector), panel()];

      return [
        for (final scope in scopes) ...[
          for (final div in tester.widgetList<WDiv>(
            find.descendant(of: scope, matching: find.byType(WDiv)),
          ))
            div.className ?? '',
          for (final text in tester.widgetList<WText>(
            find.descendant(of: scope, matching: find.byType(WText)),
          ))
            text.className ?? '',
          for (final icon in tester.widgetList<WIcon>(
            find.descendant(of: scope, matching: find.byType(WIcon)),
          ))
            icon.className ?? '',
        ],
        tester.widget<WDiv>(panel()).className ?? '',
      ];
    }

    testWidgets('clips its rows to the rounded corners', (tester) async {
      await open(tester);

      expect(
        tester.widget<WDiv>(panel()).className,
        contains('overflow-hidden'),
      );

      // The class alone proves nothing if Wind draws no clip for it.
      final clip = tester.widget<ClipRRect>(
        find.descendant(of: panel(), matching: find.byType(ClipRRect)).first,
      );
      expect(clip.borderRadius, isNot(BorderRadius.zero));
    });

    testWidgets('keeps the shipped grey panel when the host sets no theme', (
      tester,
    ) async {
      await open(tester);

      expect(
        tester.widget<WDiv>(panel()).className,
        contains(
          'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700',
        ),
      );
    });

    testWidgets('names no palette colour once the host theme supplies them', (
      tester,
    ) async {
      MagicStarter.useWindTheme(hostTheme);
      await open(tester, data: hostTheme);

      final raw = RegExp(r'(gray|blue|red)-\d|\bwhite\b');
      for (final className in classNames(tester)) {
        expect(
          raw.hasMatch(className),
          isFalse,
          reason: '"$className" hard-codes a palette colour',
        );
      }
    });

    testWidgets('reads panel, divider, row, tile and text from the theme', (
      tester,
    ) async {
      MagicStarter.useDropdownTheme(
        const MagicStarterDropdownTheme(
          panelClassName: 'bg-amber-500 border border-amber-700',
          dividerClassName: 'border-amber-300',
          itemClassName: 'hover:bg-amber-100',
          tileClassName: 'bg-amber-200',
          textClassName: 'text-amber-900',
          mutedTextClassName: 'text-amber-700',
        ),
      );
      await open(tester);

      expect(
        tester.widget<WDiv>(panel()).className,
        contains('bg-amber-500 border border-amber-700'),
      );
      expect(
        tester.widget<WDiv>(rowOf('Beta Inc')).className,
        contains('hover:bg-amber-100'),
      );
      expect(
        tester.widget<WText>(wtext('Beta Inc')).className,
        contains('text-amber-900'),
      );
      expect(
        tester
            .widget<WText>(wtext(trans('teams.team').toUpperCase()))
            .className,
        contains('text-amber-700'),
      );
      expect(
        tester
            .widgetList<WDiv>(find.byType(WDiv))
            .any((div) => (div.className ?? '').contains('bg-amber-200')),
        isTrue,
        reason: 'no glyph tile took the themed fill',
      );
      expect(
        tester
            .widgetList<WDiv>(find.byType(WDiv))
            .any((div) => (div.className ?? '').contains('border-amber-300')),
        isTrue,
        reason: 'the divider did not take the themed colour',
      );
    });

    testWidgets('paints the host palette on the panel and a hovered row', (
      tester,
    ) async {
      MagicStarter.useWindTheme(hostTheme);
      await open(tester, data: hostTheme);

      expect(fillsOf(tester, panel()).first, const Color(0xFF202024));

      final resting = fillsOf(tester, rowOf('Beta Inc'));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Beta Inc')));
      // The row animates its fill (`transition-colors`), so one frame in it is
      // still the resting colour.
      await tester.pumpAndSettle();

      // The row gains its own fill, and the tile keeps a different one so it
      // stays visible on the hovered row.
      final hovered = fillsOf(tester, rowOf('Beta Inc'));
      expect(hovered.length, resting.length + 1);
      expect(hovered.first, const Color(0xFF303036));
      expect(hovered.last, const Color(0xFF101012));
      expect(resting, [const Color(0xFF101012)]);
    });
  });
}
