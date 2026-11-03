import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/bottom_sheet/bottom_sheet_panel.dart';
import 'package:magic_starter/src/ui/components/confirm_dialog/index.dart';

/// `MagicStarterModalTheme.presentation`: every modal the starter opens is a
/// dialog by default and the same bottom sheet in `sheet` mode, with the same
/// return values, and the openers that refuse a scrim tap refuse a drag too.

/// One opener under test: how to open it, how to confirm and cancel it, and
/// what each path resolves to.
class _Opener {
  final String name;
  final Future<Object?> Function(BuildContext context) open;
  final Future<void> Function(WidgetTester tester) confirm;
  final Object? confirmed;
  final Object? cancelled;

  /// What a scrim tap resolves to, or null when the opener is not dismissible.
  final Object? Function()? dismissedValue;

  const _Opener({
    required this.name,
    required this.open,
    required this.confirm,
    required this.confirmed,
    required this.cancelled,
    required this.dismissedValue,
  });

  bool get dismissible => dismissedValue != null;
}

const Map<String, dynamic> _setupData = {
  'secret': 'ABCDEFGHIJK',
  'recovery_codes': ['code-1', 'code-2'],
};

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> _typeAndConfirm(WidgetTester tester, String value) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(WFormInput),
      matching: find.byType(EditableText),
    ),
    value,
  );
  await _tapText(tester, 'common.confirm');
}

final List<_Opener> _openers = [
  _Opener(
    name: 'MSDialog.show',
    open: (context) => MSDialog.show<String>(
      context,
      title: 'Plain',
      body: const Text('plain body'),
      footerBuilder: (dialogContext) => Wrap(
        children: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('done'),
            child: const Text('common.confirm'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('common.cancel'),
          ),
        ],
      ),
    ),
    confirm: (tester) => _tapText(tester, 'common.confirm'),
    confirmed: 'done',
    cancelled: null,
    dismissedValue: () => null,
  ),
  _Opener(
    name: 'MSConfirmDialog.show',
    open: (context) => MSConfirmDialog.show(context, title: 'Confirm'),
    confirm: (tester) => _tapText(tester, 'common.confirm'),
    confirmed: true,
    cancelled: false,
    dismissedValue: null,
  ),
  _Opener(
    name: 'MagicStarterConfirmDialog.show',
    open: (context) =>
        MagicStarterConfirmDialog.show(context, title: 'Confirm alias'),
    confirm: (tester) => _tapText(tester, 'common.confirm'),
    confirmed: true,
    cancelled: false,
    dismissedValue: null,
  ),
  _Opener(
    name: 'MagicStarterPasswordConfirmDialog.show',
    open: (context) => MagicStarterPasswordConfirmDialog.show(
      context,
      onConfirm: (_) async => null,
    ),
    confirm: (tester) => _typeAndConfirm(tester, 'secret'),
    confirmed: true,
    cancelled: false,
    dismissedValue: null,
  ),
  _Opener(
    name: 'MagicStarterStepUpDialog.show',
    open: (context) => MagicStarterStepUpDialog.show(
      context,
      accepts: ValueNotifier<List<String>?>(const ['code']),
    ),
    confirm: (tester) => _typeAndConfirm(tester, '123456'),
    confirmed: const {'code': '123456'},
    cancelled: null,
    dismissedValue: null,
  ),
  _Opener(
    name: 'MagicStarterTwoFactorModal.show',
    open: (context) => MagicStarterTwoFactorModal.show(
      context,
      setupData: _setupData,
      onConfirm: (_) async => true,
    ),
    confirm: (tester) async {
      await _typeAndConfirm(tester, '123456');
      await _tapText(tester, 'common.done');
    },
    confirmed: true,
    cancelled: false,
    dismissedValue: () => false,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('log', () => LogManager());
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Config.set('logging', {
      'default': 'console',
      'channels': {
        'console': {'driver': 'console', 'level': 'debug'},
      },
    });
    Config.set('wind.colors.primary', 'indigo');
  });

  void usePresentation(MagicStarterModalPresentation presentation) {
    MagicStarter.useModalTheme(
      MagicStarter.manager.modalTheme.copyWith(presentation: presentation),
    );
  }

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Pumps a button that opens [open] and hands its result to [onResult].
  Future<void> pumpOpener(
    WidgetTester tester,
    Future<Object?> Function(BuildContext context) open,
    ValueChanged<Object?> onResult,
  ) async {
    final themeData = WindThemeData(colors: {'primary': Colors.indigo});
    await tester.pumpWidget(
      WindTheme(
        data: themeData,
        child: MaterialApp(
          theme: themeData.toThemeData(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => onResult(await open(context)),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  void expectSheet() {
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Dialog),
      ),
      findsNothing,
    );
    expect(find.byType(Dialog), findsNothing);
  }

  void expectDialog() {
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  }

  for (final presentation in MagicStarterModalPresentation.values) {
    final bool sheet = presentation == MagicStarterModalPresentation.sheet;

    group('${presentation.name} presentation', () {
      for (final opener in _openers) {
        group(opener.name, () {
          testWidgets('opens as a ${sheet ? 'sheet' : 'dialog'}', (
            tester,
          ) async {
            setSize(tester, const Size(400, 900));
            usePresentation(presentation);

            await pumpOpener(tester, opener.open, (_) {});

            sheet ? expectSheet() : expectDialog();
          });

          testWidgets('resolves the confirm value', (tester) async {
            setSize(tester, const Size(400, 900));
            usePresentation(presentation);
            Object? result = #unset;

            await pumpOpener(tester, opener.open, (v) => result = v);
            await opener.confirm(tester);

            expect(result, opener.confirmed);
            expect(find.byType(BottomSheet), findsNothing);
            expect(find.byType(Dialog), findsNothing);
          });

          testWidgets('resolves the cancel value', (tester) async {
            setSize(tester, const Size(400, 900));
            usePresentation(presentation);
            Object? result = #unset;

            await pumpOpener(tester, opener.open, (v) => result = v);
            await _tapText(tester, 'common.cancel');

            expect(result, opener.cancelled);
          });

          testWidgets(
            opener.dismissible
                ? 'a scrim tap closes it'
                : 'a scrim tap leaves it open',
            (tester) async {
              setSize(tester, const Size(400, 900));
              usePresentation(presentation);
              Object? result = #unset;

              await pumpOpener(tester, opener.open, (v) => result = v);
              await tester.tapAt(const Offset(8, 8));
              await tester.pumpAndSettle();

              if (opener.dismissible) {
                expect(result, opener.dismissedValue!());
                expect(find.byType(BottomSheet), findsNothing);
                expect(find.byType(Dialog), findsNothing);
              } else {
                expect(result, #unset);
                sheet ? expectSheet() : expectDialog();
              }
            },
          );

          if (sheet) {
            testWidgets(
              opener.dismissible
                  ? 'a drag down closes it'
                  : 'a drag down leaves it open',
              (tester) async {
                setSize(tester, const Size(400, 900));
                usePresentation(presentation);
                Object? result = #unset;

                await pumpOpener(tester, opener.open, (v) => result = v);
                // On the drag handle: the body is a scroll view that takes a
                // vertical drag for itself.
                final Rect panel = tester.getRect(
                  find.byType(MSBottomSheetPanel),
                );
                await tester.flingFrom(
                  Offset(panel.center.dx, panel.top + 8),
                  const Offset(0, 600),
                  3000,
                );
                await tester.pumpAndSettle();

                if (opener.dismissible) {
                  expect(result, opener.dismissedValue!());
                  expect(find.byType(BottomSheet), findsNothing);
                } else {
                  expect(result, #unset);
                  expectSheet();
                }
              },
            );
          }
        });
      }
    });
  }

  group('MSBottomSheet.show(dialogBreakpoint:)', () {
    Future<Object?> openWithBreakpoint(BuildContext context) {
      return MSBottomSheet.show<void>(
        context,
        title: 'Move',
        body: const Text('sheet body'),
        dialogBreakpoint: 'lg',
      );
    }

    testWidgets('stays a sheet at 1440 px in sheet presentation', (
      tester,
    ) async {
      setSize(tester, const Size(1440, 900));
      usePresentation(MagicStarterModalPresentation.sheet);

      await pumpOpener(tester, openWithBreakpoint, (_) {});

      expectSheet();
      expect(find.byType(MSBottomSheet), findsOneWidget);
      expect(find.byType(MSDialog), findsNothing);
    });

    testWidgets('swaps to a dialog at 1440 px in dialog presentation', (
      tester,
    ) async {
      setSize(tester, const Size(1440, 900));
      usePresentation(MagicStarterModalPresentation.dialog);

      await pumpOpener(tester, openWithBreakpoint, (_) {});

      expectDialog();
      expect(find.byType(MSDialog), findsOneWidget);
    });
  });

  group('sheet width', () {
    for (final opener in _openers) {
      testWidgets('${opener.name} is at most 640 px wide at 1440 px', (
        tester,
      ) async {
        setSize(tester, const Size(1440, 900));
        usePresentation(MagicStarterModalPresentation.sheet);

        await pumpOpener(tester, opener.open, (_) {});

        final Rect panel = tester.getRect(find.byType(MSBottomSheetPanel));
        expect(panel.width, lessThanOrEqualTo(640));
        expect(panel.width, greaterThan(400));
        expect(panel.bottom, 900);
      });
    }
  });

  group('MagicStarterHideBottomNav', () {
    for (final presentation in MagicStarterModalPresentation.values) {
      testWidgets('keeps the bar hidden under a ${presentation.name} route', (
        tester,
      ) async {
        setSize(tester, const Size(400, 900));
        usePresentation(presentation);
        final List<double> seen = [];

        await tester.pumpWidget(
          WindTheme(
            data: WindThemeData(),
            child: MaterialApp(
              builder: (context, child) => MagicStarterBottomNavScope(
                child: Column(
                  children: [
                    Expanded(child: child!),
                    Builder(
                      builder: (context) {
                        seen.add(
                          MagicStarterBottomNavScope.visibilityOf(context),
                        );

                        return const SizedBox(height: 1);
                      },
                    ),
                  ],
                ),
              ),
              home: MagicStarterHideBottomNav(
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => MSDialog.show<void>(
                      context,
                      body: const Text('over the page'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(seen.last, 0);
        seen.clear();

        await tester.tap(find.text('Open'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(find.text('over the page'), findsOneWidget);
        expect(seen.every((v) => v == 0), isTrue, reason: '$seen');
      });
    }
  });

  // A phone in landscape with the keyboard up leaves about 190 px: the old
  // dialogs scrolled the whole card there, the shell scrolls only its body.
  group('a short surface with the keyboard up', () {
    final Map<String, Future<Object?> Function(BuildContext)> forms = {
      'MagicStarterPasswordConfirmDialog': (context) =>
          MagicStarterPasswordConfirmDialog.show(context),
      'MagicStarterTwoFactorModal': (context) =>
          MagicStarterTwoFactorModal.show(
            context,
            setupData: _setupData,
            onConfirm: (_) async => true,
          ),
    };

    for (final presentation in MagicStarterModalPresentation.values) {
      for (final entry in forms.entries) {
        testWidgets(
          '${presentation.name}: ${entry.key} keeps Confirm reachable',
          (tester) async {
            setSize(tester, const Size(844, 390));
            usePresentation(presentation);

            await pumpOpener(tester, entry.value, (_) {});
            tester.view.viewInsets = const FakeViewPadding(bottom: 200);
            addTearDown(tester.view.resetViewInsets);
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.text('common.confirm').hitTestable(), findsOneWidget);
          },
        );
      }
    }
  });

  // The keyboard rising on a landscape phone takes a modal from roomy to
  // short. The body must stay mounted through that, or its field loses focus
  // and the keyboard drops again.
  group('the keyboard rising on a short surface', () {
    final Finder field = find.descendant(
      of: find.byType(WFormInput),
      matching: find.byType(EditableText),
    );

    /// How far [title] moves when the shared scroll view is moved by 20 px:
    /// 0 while the header is pinned, 20 once it scrolls with the body. The
    /// position is put back, so the caller's state is unchanged.
    Future<double> headerTravel(WidgetTester tester, String title) async {
      final ScrollPosition position = tester
          .state<ScrollableState>(
            find.ancestor(
              of: find.text(title),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      final double start = position.pixels;
      final double top = tester.getRect(find.text(title)).top;
      position.jumpTo(start + 20);
      await tester.pump();
      final double travel = top - tester.getRect(find.text(title)).top;
      position.jumpTo(start);
      await tester.pump();

      return travel;
    }

    // (title, opener, whether the body overflows before the keyboard, so the
    // pinned state can be seen before the flip as well as after it).
    final Map<String, (String, Future<Object?> Function(BuildContext), bool)>
    forms = {
      'MSDialog with a field': (
        'Rename',
        (context) => MSDialog.show<void>(
          context,
          title: 'Rename',
          body: Column(
            children: [
              WFormInput(controller: TextEditingController()),
              for (int i = 0; i < 20; i++) Text('row $i'),
            ],
          ),
        ),
        true,
      ),
      'MagicStarterPasswordConfirmDialog': (
        'profile.confirm_password',
        (context) => MagicStarterPasswordConfirmDialog.show(context),
        false,
      ),
    };

    for (final presentation in MagicStarterModalPresentation.values) {
      for (final entry in forms.entries) {
        final (String title, open, bool overflowsBefore) = entry.value;

        testWidgets(
          '${presentation.name}: ${entry.key} keeps its focused field',
          (tester) async {
            setSize(tester, const Size(844, 390));
            usePresentation(presentation);

            await pumpOpener(tester, open, (_) {});
            await tester.showKeyboard(field);
            await tester.pumpAndSettle();
            if (overflowsBefore) {
              expect(await headerTravel(tester, title), 0);
            }
            final EditableTextState before = tester.state(field);
            final FocusNode? focus = FocusManager.instance.primaryFocus;
            expect(before.widget.focusNode.hasFocus, isTrue);

            tester.view.viewInsets = const FakeViewPadding(bottom: 200);
            addTearDown(tester.view.resetViewInsets);
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(await headerTravel(tester, title), 20);
            expect(identical(tester.state(field), before), isTrue);
            expect(FocusManager.instance.primaryFocus, same(focus));
            expect(before.widget.focusNode.hasFocus, isTrue);
          },
        );
      }

      testWidgets('${presentation.name}: a long body keeps its scroll offset', (
        tester,
      ) async {
        setSize(tester, const Size(844, 390));
        usePresentation(presentation);

        await pumpOpener(
          tester,
          (context) => MSDialog.show<void>(
            context,
            title: 'Long',
            body: Column(
              children: [for (int i = 0; i < 40; i++) Text('row $i')],
            ),
          ),
          (_) {},
        );
        final Finder scrollable = find.ancestor(
          of: find.text('row 0'),
          matching: find.byType(Scrollable),
        );
        await tester.drag(find.text('row 5'), const Offset(0, -60));
        await tester.pumpAndSettle();
        final ScrollPosition position = tester
            .state<ScrollableState>(scrollable)
            .position;
        final double before = position.pixels;
        expect(before, greaterThan(0));
        expect(await headerTravel(tester, 'Long'), 0);

        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(await headerTravel(tester, 'Long'), 20);
        expect(
          tester.state<ScrollableState>(scrollable).position,
          same(position),
        );
        expect(position.pixels, before);
      });
    }
  });

  // A large text size grows the header and footer past any fixed threshold;
  // the header is measured, so it scrolls away and the actions stay.
  group('a short surface at twice the text size', () {
    const String longDescription =
        'This explains at length what happens next, so that a header at a '
        'large text size wraps over several lines on a landscape phone.';

    final Map<String, Future<Object?> Function(BuildContext)> forms = {
      'MSDialog': (context) => MSDialog.show<void>(
        context,
        title: 'Rename',
        description: longDescription,
        body: const Text('body'),
        footerBuilder: (dialogContext) => TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('common.confirm'),
        ),
      ),
      'MagicStarterPasswordConfirmDialog': (context) =>
          MagicStarterPasswordConfirmDialog.show(
            context,
            description: longDescription,
          ),
    };

    for (final presentation in MagicStarterModalPresentation.values) {
      for (final entry in forms.entries) {
        testWidgets(
          '${presentation.name}: ${entry.key} keeps Confirm reachable',
          (tester) async {
            setSize(tester, const Size(844, 400));
            tester.platformDispatcher.textScaleFactorTestValue = 2;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            usePresentation(presentation);

            await pumpOpener(tester, entry.value, (_) {});

            expect(tester.takeException(), isNull);
            expect(find.text('common.confirm').hitTestable(), findsOneWidget);
          },
        );
      }
    }
  });

  group('back and Escape on the non-dismissible openers', () {
    for (final presentation in MagicStarterModalPresentation.values) {
      final bool sheet = presentation == MagicStarterModalPresentation.sheet;

      for (final opener in _openers.where((o) => !o.dismissible)) {
        // Idle, back acts as Cancel, as it always has: `barrierDismissible:
        // false` never blocked it.
        testWidgets(
          '${presentation.name}: back cancels an idle ${opener.name}',
          (tester) async {
            setSize(tester, const Size(400, 900));
            usePresentation(presentation);
            Object? result = #unset;

            await pumpOpener(tester, opener.open, (v) => result = v);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();

            expect(result, opener.cancelled);
            expect(find.byType(BottomSheet), findsNothing);
            expect(find.byType(Dialog), findsNothing);
          },
        );

        testWidgets(
          '${presentation.name}: Escape leaves an idle ${opener.name} open',
          (tester) async {
            setSize(tester, const Size(400, 900));
            usePresentation(presentation);
            Object? result = #unset;

            await pumpOpener(tester, opener.open, (v) => result = v);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();

            expect(result, #unset);
            sheet ? expectSheet() : expectDialog();
          },
        );
      }
    }
  });

  // While a request is in flight the widget's Cancel is off, and so are every
  // other way out: a scrim tap, a drag, back and Escape.
  group('a non-dismissible opener while its request is in flight', () {
    final Map<String, Future<void> Function(WidgetTester)> attempts = {
      'Cancel': (tester) async {
        await tester.tap(find.text('common.cancel').last);
        await tester.pump();
      },
      'a scrim tap': (tester) async {
        await tester.tapAt(const Offset(8, 8));
        await tester.pump();
      },
      'back': (tester) async {
        await tester.binding.handlePopRoute();
        await tester.pump();
      },
      'Escape': (tester) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
      },
    };

    for (final presentation in MagicStarterModalPresentation.values) {
      final bool sheet = presentation == MagicStarterModalPresentation.sheet;
      final Map<String, Future<void> Function(WidgetTester)> all = {
        ...attempts,
        if (sheet)
          'a drag down': (tester) async {
            final Rect panel = tester.getRect(find.byType(MSBottomSheetPanel));
            await tester.flingFrom(
              Offset(panel.center.dx, panel.top + 8),
              const Offset(0, 600),
              3000,
            );
            await tester.pump(const Duration(milliseconds: 500));
          },
      };

      final Map<String, Future<Object?> Function(BuildContext, Completer<void>)>
      openers = {
        'MagicStarterPasswordConfirmDialog': (context, pending) =>
            MagicStarterPasswordConfirmDialog.show(
              context,
              onConfirm: (_) async {
                await pending.future;

                return null;
              },
            ),
        'MagicStarterStepUpDialog': (context, pending) =>
            MagicStarterStepUpDialog.show(
              context,
              accepts: ValueNotifier<List<String>?>(const ['code']),
              onProof: (_) async {
                await pending.future;

                return null;
              },
            ),
      };

      for (final opener in openers.entries) {
        for (final attempt in all.entries) {
          testWidgets('${presentation.name}: ${attempt.key} leaves a busy '
              '${opener.key} open', (tester) async {
            setSize(tester, const Size(400, 900));
            usePresentation(presentation);
            final pending = Completer<void>();
            Object? result = #unset;

            await pumpOpener(
              tester,
              (context) => opener.value(context, pending),
              (v) => result = v,
            );
            await tester.enterText(
              find.descendant(
                of: find.byType(WFormInput),
                matching: find.byType(EditableText),
              ),
              '123456',
            );
            await tester.tap(find.text('common.confirm').last);
            await tester.pump();

            await attempt.value(tester);

            expect(result, #unset);
            sheet ? expectSheet() : expectDialog();

            pending.complete();
            await tester.pumpAndSettle();
            expect(result, isNot(#unset));
            expect(result, isNot(isNull));
          });
        }
      }
    }
  });

  // The header lives in the body's scroll view, so on a body that overflows
  // a drag from the title is the content's, not the sheet's.
  group('dragging an MSBottomSheet down', () {
    Future<void> openSheet(WidgetTester tester, {required int rows}) async {
      await pumpOpener(
        tester,
        (context) => MSBottomSheet.show<void>(
          context,
          title: 'Move',
          body: Column(
            children: [for (int i = 0; i < rows; i++) Text('row $i')],
          ),
        ),
        (_) {},
      );
    }

    Future<void> flingFrom(WidgetTester tester, Offset start) async {
      await tester.flingFrom(start, const Offset(0, 600), 3000);
      await tester.pumpAndSettle();
    }

    testWidgets('from the title of an overflowing body leaves it open', (
      tester,
    ) async {
      setSize(tester, const Size(400, 900));
      await openSheet(tester, rows: 80);

      await flingFrom(tester, tester.getCenter(find.text('Move')));

      expect(find.byType(MSBottomSheet), findsOneWidget);
    });

    testWidgets('from the handle of an overflowing body closes it', (
      tester,
    ) async {
      setSize(tester, const Size(400, 900));
      await openSheet(tester, rows: 80);

      final Rect panel = tester.getRect(find.byType(MSBottomSheetPanel));
      await flingFrom(tester, Offset(panel.center.dx, panel.top + 8));

      expect(find.byType(MSBottomSheet), findsNothing);
    });

    testWidgets('from the title of a body that fits closes it', (tester) async {
      setSize(tester, const Size(400, 900));
      await openSheet(tester, rows: 3);

      await flingFrom(tester, tester.getCenter(find.text('Move')));

      expect(find.byType(MSBottomSheet), findsNothing);
    });
  });

  // A pinned header has no background of its own (`headerClassName` carries
  // padding only), so a body scrolled under it must be clipped, or its
  // content shows through the title. Checked by pixels, not finders.
  group('a body scrolled under the pinned header', () {
    const Color marker = Color(0xFFFF00FF);
    final GlobalKey boundary = GlobalKey();

    Future<void> pumpBoundary(
      WidgetTester tester,
      Future<Object?> Function(BuildContext) open,
    ) async {
      final themeData = WindThemeData(colors: {'primary': Colors.indigo});
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: WindTheme(
            data: themeData,
            child: MaterialApp(
              theme: themeData.toThemeData(),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => open(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    /// Marker pixels inside [rect], read off the rendered frame.
    Future<int> markerPixels(WidgetTester tester, Rect rect) async {
      final RenderRepaintBoundary render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ByteData bytes = (await tester.runAsync<ByteData?>(() async {
        final image = await render.toImage();
        final ByteData? data = await image.toByteData();
        image.dispose();

        return data;
      }))!;
      final int width = render.size.width.toInt();
      int count = 0;
      for (int y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
        for (int x = rect.left.ceil(); x < rect.right.floor(); x++) {
          final int i = (y * width + x) * 4;
          if (bytes.getUint8(i) > 200 &&
              bytes.getUint8(i + 1) < 60 &&
              bytes.getUint8(i + 2) > 200) {
            count++;
          }
        }
      }

      return count;
    }

    Widget body() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ColoredBox(color: marker, child: SizedBox(height: 60)),
        for (int i = 0; i < 40; i++) Text('row $i'),
      ],
    );

    final Map<String, Future<Object?> Function(BuildContext)> openers = {
      'MSDialog.show': (context) =>
          MSDialog.show<void>(context, title: 'Header', body: body()),
      'MSBottomSheet.show': (context) =>
          MSBottomSheet.show<void>(context, title: 'Header', body: body()),
    };

    /// The header block: the padded box around the title.
    Rect headerRect(WidgetTester tester) => tester.getRect(
      find.ancestor(of: find.text('Header'), matching: find.byType(WDiv)).first,
    );

    Future<void> scrollBy(WidgetTester tester, double pixels) async {
      tester
          .state<ScrollableState>(
            find.ancestor(
              of: find.text('row 0'),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .jumpTo(pixels);
      await tester.pump();
    }

    for (final presentation in MagicStarterModalPresentation.values) {
      for (final entry in openers.entries) {
        testWidgets(
          '${presentation.name}: ${entry.key} hides the body under the header',
          (tester) async {
            setSize(tester, const Size(400, 900));
            usePresentation(presentation);
            await pumpBoundary(tester, entry.value);
            final Rect header = headerRect(tester);
            expect(await markerPixels(tester, header), 0);

            await scrollBy(tester, 40);

            expect(headerRect(tester), header, reason: 'the header is pinned');
            expect(await markerPixels(tester, header), 0);
            expect(
              await markerPixels(
                tester,
                Rect.fromLTRB(
                  header.left,
                  header.bottom,
                  header.right,
                  header.bottom + 15,
                ),
              ),
              greaterThan(0),
              reason: 'the marker shows right under the header',
            );
          },
        );
      }
    }

    for (final presentation in MagicStarterModalPresentation.values) {
      testWidgets(
        '${presentation.name}: focusing a field under the header reveals it',
        (tester) async {
          setSize(tester, const Size(400, 900));
          usePresentation(presentation);
          await pumpBoundary(
            tester,
            (context) => MSDialog.show<void>(
              context,
              title: 'Header',
              body: Column(
                children: [
                  WFormInput(controller: TextEditingController()),
                  for (int i = 0; i < 40; i++) Text('row $i'),
                ],
              ),
            ),
          );
          await scrollBy(tester, 30);
          final Finder field = find.descendant(
            of: find.byType(WFormInput),
            matching: find.byType(EditableText),
          );
          expect(
            tester.getRect(field).top,
            lessThan(headerRect(tester).bottom),
          );

          await tester.showKeyboard(field);
          await tester.pumpAndSettle();

          expect(
            tester.getRect(field).top,
            greaterThanOrEqualTo(headerRect(tester).bottom - 0.5),
          );
        },
      );
    }

    testWidgets('an unpinned header scrolls away and shows the body', (
      tester,
    ) async {
      setSize(tester, const Size(844, 390));
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await pumpBoundary(tester, openers['MSDialog.show']!);
      final Rect header = headerRect(tester);

      await scrollBy(tester, 40);

      expect(headerRect(tester).top, header.top - 40);
      expect(await markerPixels(tester, header), greaterThan(0));
    });
  });

  group('sheet drag handle', () {
    final Finder handle = find.byWidgetPredicate(
      (widget) =>
          widget is WDiv && (widget.className?.startsWith('w-9 h-1') ?? false),
    );

    for (final opener in _openers) {
      testWidgets(
        '${opener.name} ${opener.dismissible ? 'shows' : 'hides'} the handle',
        (tester) async {
          setSize(tester, const Size(400, 900));
          usePresentation(MagicStarterModalPresentation.sheet);

          await pumpOpener(tester, opener.open, (_) {});

          expect(handle, opener.dismissible ? findsOneWidget : findsNothing);
        },
      );
    }

    testWidgets('MSBottomSheet.show keeps the handle', (tester) async {
      setSize(tester, const Size(400, 900));

      await pumpOpener(
        tester,
        (context) => MSBottomSheet.show<void>(context, body: const Text('x')),
        (_) {},
      );

      expect(handle, findsOneWidget);
    });
  });

  // While the code is being checked the server may enable two-factor at any
  // moment. Cancel, a scrim tap and back are off then; a drag down on a sheet
  // pops the route directly, so `show` waits for the check before answering.
  group('MagicStarterTwoFactorModal while the code is checked', () {
    Future<Completer<bool>> openAndSubmit(
      WidgetTester tester,
      ValueChanged<Object?> onResult,
    ) async {
      final pending = Completer<bool>();
      await pumpOpener(
        tester,
        (context) => MagicStarterTwoFactorModal.show(
          context,
          setupData: _setupData,
          onConfirm: (_) => pending.future,
        ),
        onResult,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(WFormInput),
          matching: find.byType(EditableText),
        ),
        '123456',
      );
      await tester.tap(find.text('common.confirm').last);
      await tester.pump();

      return pending;
    }

    final Map<String, Future<void> Function(WidgetTester)> blocked = {
      'Cancel': (tester) async {
        await tester.tap(find.text('common.cancel').last);
        await tester.pump();
      },
      'a scrim tap': (tester) async {
        await tester.tapAt(const Offset(8, 8));
        await tester.pump(const Duration(milliseconds: 500));
      },
      'back': (tester) async {
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 500));
      },
    };

    for (final presentation in MagicStarterModalPresentation.values) {
      for (final attempt in blocked.entries) {
        testWidgets(
          '${presentation.name}: ${attempt.key} leaves it open while busy',
          (tester) async {
            setSize(tester, const Size(400, 900));
            usePresentation(presentation);
            Object? result = #unset;

            final pending = await openAndSubmit(tester, (v) => result = v);
            await attempt.value(tester);

            expect(find.byType(MagicStarterTwoFactorModal), findsOneWidget);
            expect(result, #unset);

            pending.complete(true);
            await tester.pumpAndSettle();
            expect(find.text('common.done'), findsOneWidget);
          },
        );
      }
    }

    final Map<String, void Function(Completer<bool>)> outcomes = {
      'accepted': (pending) => pending.complete(true),
      'refused': (pending) => pending.complete(false),
      'failing': (pending) => pending.completeError(StateError('offline')),
    };

    for (final outcome in outcomes.entries) {
      testWidgets(
        'sheet: a drag down while busy waits for the ${outcome.key} check',
        (tester) async {
          setSize(tester, const Size(400, 900));
          usePresentation(MagicStarterModalPresentation.sheet);
          Object? result = #unset;

          final pending = await openAndSubmit(tester, (v) => result = v);
          final Rect panel = tester.getRect(find.byType(MSBottomSheetPanel));
          await tester.flingFrom(
            Offset(panel.center.dx, panel.top + 8),
            const Offset(0, 600),
            3000,
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(MagicStarterTwoFactorModal), findsNothing);
          expect(result, #unset);

          outcome.value(pending);
          await tester.pumpAndSettle();

          expect(result, outcome.key == 'accepted');
        },
      );
    }
  });

  // The server enables two-factor when the code is confirmed, before the
  // recovery codes step. A close other than Done used to resolve `false`, so
  // the screen kept saying "off" for an account that had it on.
  group('MagicStarterTwoFactorModal after a confirmed code', () {
    Future<Object?> openTwoFactor(BuildContext context, {bool accepts = true}) {
      return MagicStarterTwoFactorModal.show(
        context,
        setupData: _setupData,
        onConfirm: (_) async => accepts,
      );
    }

    Future<void> confirmCode(WidgetTester tester) async {
      await _typeAndConfirm(tester, '123456');
      expect(find.text('common.done'), findsOneWidget);
    }

    Future<void> dragDown(WidgetTester tester) async {
      final Rect panel = tester.getRect(find.byType(MSBottomSheetPanel));
      await tester.flingFrom(
        Offset(panel.center.dx, panel.top + 8),
        const Offset(0, 600),
        3000,
      );
      await tester.pumpAndSettle();
    }

    Future<void> scrimTap(WidgetTester tester) async {
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
    }

    Future<void> back(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    for (final presentation in MagicStarterModalPresentation.values) {
      final bool sheet = presentation == MagicStarterModalPresentation.sheet;
      final closes = <String, Future<void> Function(WidgetTester)>{
        'a scrim tap': scrimTap,
        'back': back,
        if (sheet) 'a drag down': dragDown,
      };

      for (final entry in closes.entries) {
        testWidgets(
          '${presentation.name}: ${entry.key} on the codes step resolves true',
          (tester) async {
            setSize(tester, const Size(400, 900));
            usePresentation(presentation);
            Object? result = #unset;

            await pumpOpener(tester, openTwoFactor, (v) => result = v);
            await confirmCode(tester);
            await entry.value(tester);

            expect(find.byType(MagicStarterTwoFactorModal), findsNothing);
            expect(result, isTrue);
          },
        );

        testWidgets(
          '${presentation.name}: ${entry.key} before a confirmed code '
          'resolves false',
          (tester) async {
            setSize(tester, const Size(400, 900));
            usePresentation(presentation);
            Object? result = #unset;

            await pumpOpener(
              tester,
              (context) => openTwoFactor(context, accepts: false),
              (v) => result = v,
            );
            await _typeAndConfirm(tester, '000000');
            await entry.value(tester);

            expect(find.byType(MagicStarterTwoFactorModal), findsNothing);
            expect(result, isFalse);
          },
        );
      }
    }
  });
}
