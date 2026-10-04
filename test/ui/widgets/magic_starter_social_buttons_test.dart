import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class _CopyLoader implements TranslationLoader {
  const _CopyLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async => {
    'social.continue_with': 'Continue with :provider',
  };
}

class _FakeSocialAuth implements MagicStarterSocialAuth {
  @override
  List<String> providers() => const ['google', 'github'];

  @override
  String label(String provider) => provider;

  @override
  Widget icon(String provider) =>
      SizedBox.square(dimension: 16, key: Key('icon-$provider'));

  @override
  Future<Map<String, dynamic>> signIn(String provider) =>
      throw UnimplementedError();

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
  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    setUpMagicStarterForTests();
    Translator.instance.setLoader(const _CopyLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  Future<void> mount(
    WidgetTester tester, {
    bool isLoading = false,
    String? busyProvider,
    required List<String> selected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(),
          child: Scaffold(
            body: MagicStarterSocialButtons(
              socialAuth: _FakeSocialAuth(),
              isLoading: isLoading,
              busyProvider: busyProvider,
              onSelected: selected.add,
            ),
          ),
        ),
      ),
    );
  }

  MSButton buttonOf(WidgetTester tester, String provider) =>
      tester.widget<MSButton>(
        find.ancestor(
          of: find.text('Continue with $provider'),
          matching: find.byType(MSButton),
        ),
      );

  group('MagicStarterSocialButtons', () {
    testWidgets('isLoading disables every button', (tester) async {
      await mount(tester, isLoading: true, selected: []);

      expect(buttonOf(tester, 'google').disabled, isTrue);
      expect(buttonOf(tester, 'github').disabled, isTrue);
    });

    testWidgets('busyProvider spins only that button and keeps all tappable', (
      tester,
    ) async {
      final selected = <String>[];
      await mount(tester, busyProvider: 'github', selected: selected);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('icon-github')), findsNothing);
      expect(find.byKey(const Key('icon-google')), findsOneWidget);
      expect(buttonOf(tester, 'github').disabled, isFalse);

      // A newer tap supersedes a pending flow (a web popup the user closed
      // never reports back), so the busy provider must stay tappable.
      await tester.tap(find.text('Continue with github'));
      expect(selected, ['github']);
    });
  });
}
