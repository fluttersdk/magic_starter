import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/widgets/starter_password_confirm_dialog.dart';

void main() {
  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Magic.singleton('log', () => LogManager());
    Config.set('logging', {
      'default': 'console',
      'channels': {
        'console': {'driver': 'console', 'level': 'debug'},
      },
    });
    Config.set('wind.colors.primary', 'indigo');
  });

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

  testWidgets('MagicStarterPasswordConfirmDialog renders correctly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(wrap(const MagicStarterPasswordConfirmDialog()));
    expect(find.text('profile.confirm_password'), findsOneWidget);
    expect(find.text('profile.confirm_password_description'), findsOneWidget);
    expect(find.text('common.confirm'), findsOneWidget);
    expect(find.text('common.cancel'), findsOneWidget);
    expect(find.byType(WFormInput), findsOneWidget);
    expect(find.byType(WButton), findsOneWidget);
  });

  testWidgets('MagicStarterPasswordConfirmDialog returns null on cancel',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    String? result = 'not-null';

    await tester.pumpWidget(wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await MagicStarterPasswordConfirmDialog.show(context);
          },
          child: const Text('Show'),
        ),
      ),
    ));

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('common.cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('MagicStarterPasswordConfirmDialog returns password on confirm',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    String? result;

    await tester.pumpWidget(wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await MagicStarterPasswordConfirmDialog.show(context);
          },
          child: const Text('Show'),
        ),
      ),
    ));

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    // Find the text field inside WFormInput and enter text
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'secretpassword');
    await tester.pump();

    await tester.tap(find.text('common.confirm'));
    await tester.pumpAndSettle();

    expect(result, 'secretpassword');
  });
}
