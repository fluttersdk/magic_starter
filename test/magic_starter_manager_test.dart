import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarterManager', () {
    late MagicStarterManager manager;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('magic_starter', () => MagicStarterManager());
      manager = Magic.make<MagicStarterManager>('magic_starter');
    });

    group('socialLoginBuilder', () {
      test('is null by default', () {
        expect(manager.socialLoginBuilder, isNull);
      });

      test('can be set and read back', () {
        Widget testBuilder(BuildContext context, bool isLoading) {
          return const SizedBox();
        }

        manager.socialLoginBuilder = testBuilder;

        expect(manager.socialLoginBuilder, equals(testBuilder));
      });

      test('reset() clears socialLoginBuilder', () {
        manager.socialLoginBuilder = (_, __) => const SizedBox();

        manager.reset();

        expect(manager.socialLoginBuilder, isNull);
      });
    });
  });
}
