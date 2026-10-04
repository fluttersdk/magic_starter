import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The package's shipped social copy, so the asserted copy is the copy a host
/// installs.
class _ShippedCatalogueLoader implements TranslationLoader {
  const _ShippedCatalogueLoader();

  /// The stub's `social` section under the dotted keys `trans()` reads; the
  /// translator does not flatten a loader's nested maps.
  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final stub =
        jsonDecode(File('assets/stubs/install/en.stub').readAsStringSync())
            as Map<String, dynamic>;
    final social = stub['social'] as Map<String, dynamic>;

    return {
      for (final entry in social.entries) 'social.${entry.key}': entry.value,
    };
  }
}

/// A bridge offering two providers whose sign-in never settles, so a tap is
/// observed without the case depending on what completion does next.
class _FakeSocialAuth implements MagicStarterSocialAuth {
  final List<String> signInCalls = [];

  @override
  List<String> providers() => const ['google', 'github'];

  @override
  String label(String provider) => provider == 'google' ? 'Google' : 'GitHub';

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

  group('MagicStarterLoginView: social sign-in', () {
    setUp(() async {
      MagicApp.reset();
      Magic.flush();
      setUpMagicStarterForTests();
      Magic.singleton('log', () => LogManager());
      Magic.put(MagicStarterAuthController());
      Translator.instance.setLoader(const _ShippedCatalogueLoader());
      await Translator.instance.setLocale(const Locale('en'));
    });

    testWidgets('shows nothing while the feature is off', (tester) async {
      MagicStarter.useSocialAuth(_FakeSocialAuth());

      await tester.pumpWidget(wrap(const MagicStarterLoginView()));

      expect(find.byType(MSSocialDivider), findsNothing);
      expect(find.byType(MagicStarterSocialButtons), findsNothing);
    });

    testWidgets('shows nothing when the feature is on but no bridge is set', (
      tester,
    ) async {
      Config.set('magic_starter.features.social_login', true);

      await tester.pumpWidget(wrap(const MagicStarterLoginView()));

      expect(find.byType(MSSocialDivider), findsNothing);
      expect(find.byType(MagicStarterSocialButtons), findsNothing);
    });

    testWidgets('renders one button per provider with its icon and label', (
      tester,
    ) async {
      Config.set('magic_starter.features.social_login', true);
      MagicStarter.useSocialAuth(_FakeSocialAuth());

      await tester.pumpWidget(wrap(const MagicStarterLoginView()));

      expect(find.byType(MSSocialDivider), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with GitHub'), findsOneWidget);
      expect(find.byKey(const Key('icon-google')), findsOneWidget);
      expect(find.byKey(const Key('icon-github')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MagicStarterSocialButtons),
          matching: find.byType(MSButton),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('tapping Google calls signIn(google) once', (tester) async {
      Config.set('magic_starter.features.social_login', true);
      final bridge = _FakeSocialAuth();
      MagicStarter.useSocialAuth(bridge);

      await tester.pumpWidget(wrap(const MagicStarterLoginView()));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(bridge.signInCalls, ['google']);
    });

    testWidgets('the tapped provider shows busy while the others stay usable', (
      tester,
    ) async {
      Config.set('magic_starter.features.social_login', true);
      MagicStarter.useSocialAuth(_FakeSocialAuth());

      await tester.pumpWidget(wrap(const MagicStarterLoginView()));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      final spinner = find.descendant(
        of: find.byType(MagicStarterSocialButtons),
        matching: find.byType(CircularProgressIndicator),
      );

      expect(spinner, findsOneWidget);
      expect(find.byKey(const Key('icon-google')), findsNothing);
      expect(find.byKey(const Key('icon-github')), findsOneWidget);
    });
  });
}
