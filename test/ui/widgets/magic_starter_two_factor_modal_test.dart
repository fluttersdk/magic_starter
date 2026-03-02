import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Widget tests for [MagicStarterTwoFactorModal].
///
/// RED PHASE — [MagicStarterTwoFactorModal] does NOT exist yet.
/// These tests define the contract for the 2FA setup wizard modal
/// and MUST fail until Task 4 provides the implementation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mock setup data returned by the backend enable 2FA endpoint.
  /// Structure mirrors the controller test at lines 282-295 of
  /// profile_controller_two_factor_test.dart.
  const Map<String, dynamic> kSetupData = {
    'secret': 'ABCDEFGHIJK',
    'qr_url': 'otpauth://totp/app:user?secret=ABCDEFGHIJK',
    'qr_svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<rect width="100" height="100" fill="black"/>'
        '</svg>',
    'recovery_codes': [
      'code-1',
      'code-2',
      'code-3',
    ],
  };

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

  /// Wraps a widget in the minimum scaffold required by Wind UI rendering.
  Widget wrap(Widget widget) {
    final themeData = WindThemeData(
      colors: {
        'primary': Colors.indigo,
      },
    );
    return WindTheme(
      data: themeData,
      child: MaterialApp(
        theme: themeData.toThemeData(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1200,
              height: 800,
              child: widget,
            ),
          ),
        ),
      ),
    );
  }

  /// Pumps [MagicStarterTwoFactorModal] directly (not via showDialog) so
  /// that widget finders work without dialog layering.
  Future<void> pumpModal(
    WidgetTester tester, {
    Map<String, dynamic> setupData = kSetupData,
    Future<bool> Function(String code)? onConfirm,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(
        MagicStarterTwoFactorModal(
          setupData: setupData,
          onConfirm: onConfirm ?? (_) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------------
  // Test 1: Step 1 renders QR code, secret key, and code input
  // -------------------------------------------------------------------------
  testWidgets(
    'Step 1 renders QR code via WSvg with preserve-colors, secret key, and 6-digit input',
    (WidgetTester tester) async {
      await pumpModal(tester);

      // QR code must be rendered as WSvg with preserve-colors (NOT raw SvgPicture).
      expect(find.byType(WSvg), findsOneWidget);

      // Secret key text must be visible.
      expect(find.text('ABCDEFGHIJK'), findsOneWidget);

      // A 6-digit code input must be present.
      expect(find.byType(WFormInput), findsOneWidget);

      // Confirm button must be visible.
      expect(find.text('common.confirm'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // Test 2: QR code uses WSvg with preserve-colors
  // -------------------------------------------------------------------------
  testWidgets(
    'Step 1 uses WSvg with preserve-colors for QR code — ColorFilter is bypassed',
    (WidgetTester tester) async {
      await pumpModal(tester);

      // WSvg MUST be present — it bypasses ColorFilter for multi-colour SVGs.
      expect(find.byType(WSvg), findsOneWidget);

      // The WSvg className must include preserve-colors so no tint is applied.
      final wsv = tester.widget<WSvg>(find.byType(WSvg));
      expect(wsv.className, contains('preserve-colors'));
    },
  );

  // -------------------------------------------------------------------------
  // Test 3: Step 2 renders recovery codes and copy button
  // -------------------------------------------------------------------------
  testWidgets(
    'Step 2 renders recovery codes and a Copy All button after transition',
    (WidgetTester tester) async {
      // onConfirm always succeeds so the modal advances to Step 2.
      await pumpModal(
        tester,
        onConfirm: (_) async => true,
      );

      // Enter a valid-looking 6-digit code and tap confirm.
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      // Recovery codes from kSetupData must be visible.
      expect(find.text('code-1'), findsOneWidget);
      expect(find.text('code-2'), findsOneWidget);
      expect(find.text('code-3'), findsOneWidget);

      // Copy All button must be present.
      expect(
        find.text('profile.two_factor.copy_codes'),
        findsOneWidget,
      );
    },
  );

  // -------------------------------------------------------------------------
  // Test 4: Confirming valid code transitions from Step 1 to Step 2
  // -------------------------------------------------------------------------
  testWidgets(
    'Step transition: confirming a valid code moves wizard to Step 2',
    (WidgetTester tester) async {
      await pumpModal(
        tester,
        onConfirm: (_) async => true,
      );

      // Step 1 landmark: WSvg (QR) is visible.
      expect(find.byType(WSvg), findsOneWidget);

      // Simulate entering a 6-digit OTP and confirming.
      await tester.enterText(find.byType(TextField), '654321');
      await tester.pump();

      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      // Step 2 landmark: QR code is gone, recovery codes appear.
      expect(find.byType(WSvg), findsNothing);
      expect(find.text('code-1'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // Test 5: Invalid OTP shows error without closing the modal
  // -------------------------------------------------------------------------
  testWidgets(
    'Invalid OTP shows error message and keeps modal on Step 1',
    (WidgetTester tester) async {
      // onConfirm returns false to simulate a wrong OTP response.
      await pumpModal(
        tester,
        onConfirm: (_) async => false,
      );

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pump();

      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      // An error message must appear — the key returned when no
      // translations are loaded is the translation key itself.
      expect(
        find.text('profile.two_factor.invalid_code'),
        findsOneWidget,
      );

      // Modal must remain on Step 1 — QR code is still visible.
      expect(find.byType(WSvg), findsOneWidget);

      // Recovery codes must NOT be visible yet.
      expect(find.text('code-1'), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // Test 6: QR code wrapper has white background class (dark-mode safe)
  // -------------------------------------------------------------------------
  testWidgets(
    'QR code wrapper WDiv has bg-white class for dark mode scannability',
    (WidgetTester tester) async {
      await pumpModal(tester);

      // Find all WDiv widgets and locate the one whose className
      // contains 'bg-white'. In dark mode the wrapper must keep a white
      // background so the QR SVG remains scannable.
      bool foundWhiteBackground = false;
      tester.widgetList<WDiv>(find.byType(WDiv)).forEach((div) {
        final String? cls = div.className;
        if (cls != null && cls.contains('bg-white')) {
          foundWhiteBackground = true;
        }
      });

      expect(
        foundWhiteBackground,
        isTrue,
        reason: 'Expected at least one WDiv with className containing '
            "'bg-white' to wrap the QR code for dark-mode scannability.",
      );
    },
  );

  // -------------------------------------------------------------------------
  // Test 7: Modal can be shown via static show() method
  // -------------------------------------------------------------------------
  testWidgets(
    'static show() opens modal and resolves to true when wizard completes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? dialogResult;

      final themeData = WindThemeData(
        colors: {
          'primary': Colors.indigo,
        },
      );

      await tester.pumpWidget(
        WindTheme(
          data: themeData,
          child: MaterialApp(
            theme: themeData.toThemeData(),
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  onPressed: () async {
                    dialogResult = await MagicStarterTwoFactorModal.show(
                      context,
                      setupData: kSetupData,
                      onConfirm: (_) async => true,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Modal is open — QR code must be visible as WSvg.
      expect(find.byType(WSvg), findsOneWidget);

      // Enter OTP and confirm.
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      await tester.tap(find.text('common.confirm'));
      await tester.pumpAndSettle();

      // Now on Step 2 — tap Done to close.
      await tester.tap(find.text('common.done'));
      await tester.pumpAndSettle();

      // Modal resolves to true on completion.
      expect(dialogResult, isTrue);
    },
  );
}
