import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// A bridge whose sign-in never settles, so a tap is observed on its own.
class _FakeSocialAuth implements MagicStarterSocialAuth {
  final List<String> signInCalls = [];

  @override
  List<String> providers() => const ['google', 'apple'];

  @override
  String label(String provider) => provider;

  @override
  Widget icon(String provider) =>
      SizedBox.square(dimension: 16, key: Key('icon-$provider'));

  @override
  Future<Map<String, dynamic>> signIn(String provider) {
    signInCalls.add(provider);

    return Completer<Map<String, dynamic>>().future;
  }

  @override
  Future<Future<Map<String, dynamic>> Function()> beginConnect(
    String provider,
    Map<String, String> proof,
  ) => throw UnimplementedError();

  @override
  Future<String> confirm(String provider) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
  }

  group('MagicStarterRegisterView: social sign-in', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      setUpMagicStarterForTests();
      Magic.singleton('log', () => LogManager());
      Magic.put(MagicStarterAuthController());
    });

    testWidgets('shows nothing while the feature is off', (tester) async {
      MagicStarter.useSocialAuth(_FakeSocialAuth());

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      expect(find.byType(MSSocialDivider), findsNothing);
      expect(find.byType(MagicStarterSocialButtons), findsNothing);
    });

    testWidgets('shows nothing when the feature is on but no bridge is set', (
      tester,
    ) async {
      Config.set('magic_starter.features.social_login', true);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      expect(find.byType(MSSocialDivider), findsNothing);
      expect(find.byType(MagicStarterSocialButtons), findsNothing);
    });

    testWidgets('renders one button per provider and signs in on a tap', (
      tester,
    ) async {
      Config.set('magic_starter.features.social_login', true);
      final bridge = _FakeSocialAuth();
      MagicStarter.useSocialAuth(bridge);

      await tester.pumpWidget(wrap(const MagicStarterRegisterView()));

      expect(find.byType(MSSocialDivider), findsOneWidget);
      expect(find.byKey(const Key('icon-google')), findsOneWidget);
      expect(find.byKey(const Key('icon-apple')), findsOneWidget);

      final appleButton = find.ancestor(
        of: find.byKey(const Key('icon-apple')),
        matching: find.byType(MSButton),
      );
      await tester.ensureVisible(appleButton);
      await tester.tap(appleButton);
      await tester.pump();

      expect(bridge.signInCalls, ['apple']);
    });
  });
}
