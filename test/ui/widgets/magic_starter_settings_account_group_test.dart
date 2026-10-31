import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: widget),
      ),
    );
  }

  List<MSSettingsNavRow> navRows(WidgetTester tester) {
    return tester
        .widgetList<MSSettingsNavRow>(find.byType(MSSettingsNavRow))
        .toList();
  }

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    setUpMagicStarterForTests();
    Auth.fake(
      user: MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Test User',
        'email': 'test@example.com',
      }),
    );
    Gate.flush();
    Gate.define('starter.delete-account', (user, [_]) => true);
  });

  tearDown(() {
    Gate.flush();
    Auth.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('MagicStarterSettingsAccountGroup', () {
    testWidgets('an account gets the Profile row alone, under its header', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterSettingsAccountGroup()));

      final List<MSSettingsNavRow> rows = navRows(tester);
      expect(rows.map((row) => row.to), [MagicStarterConfig.profileRoute()]);
      expect(rows.single.title, trans('profile.profile_information'));
      expect(rows.single.subtitle, 'Test User · test@example.com');
      expect(
        tester.widget<MSSettingsSection>(find.byType(MSSettingsSection)).header,
        trans('magic_starter.settings.account_section'),
      );
    });

    testWidgets('a guest also gets the upgrade and the sign-in rows', (
      tester,
    ) async {
      Gate.define('starter.delete-account', (user, [_]) => false);

      await tester.pumpWidget(wrap(const MagicStarterSettingsAccountGroup()));

      final List<MSSettingsNavRow> rows = navRows(tester);
      expect(rows.map((row) => row.to), [
        MagicStarterConfig.profileRoute(),
        MagicStarterConfig.profileRoute(),
        MagicStarterConfig.loginRoute(),
      ]);
      expect(rows[1].title, trans('magic_starter.guest_upgrade.title'));
      expect(rows[2].title, trans('auth.sign_in'));
    });

    testWidgets('the Profile subtitle drops a missing identity field', (
      tester,
    ) async {
      Auth.fake(user: MagicStarterAuthUser.fromMap({'id': 2, 'name': 'Ada'}));

      await tester.pumpWidget(wrap(const MagicStarterSettingsAccountGroup()));

      expect(navRows(tester).single.subtitle, 'Ada');
    });
  });
}
