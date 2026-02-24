import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarter facade', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('magic_starter', () => MagicStarterManager());
    });

    group('social login', () {
      test('hasSocialLogin returns false when not configured', () {
        expect(MagicStarter.hasSocialLogin, isFalse);
      });

      test('socialLoginBuilder returns null when not configured', () {
        expect(MagicStarter.socialLoginBuilder, isNull);
      });

      test('useSocialLogin() sets the builder on the manager', () {
        Widget testBuilder(BuildContext context, bool isLoading) {
          return const SizedBox();
        }

        MagicStarter.useSocialLogin(testBuilder);

        expect(MagicStarter.manager.socialLoginBuilder, equals(testBuilder));
      });

      test('hasSocialLogin returns true after useSocialLogin()', () {
        MagicStarter.useSocialLogin((_, __) => const SizedBox());

        expect(MagicStarter.hasSocialLogin, isTrue);
      });

      test('socialLoginBuilder returns the registered builder', () {
        Widget testBuilder(BuildContext context, bool isLoading) {
          return const SizedBox();
        }

        MagicStarter.useSocialLogin(testBuilder);

        expect(MagicStarter.socialLoginBuilder, equals(testBuilder));
      });
    });
  });
}
