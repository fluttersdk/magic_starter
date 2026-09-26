import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/support/magic_starter_onboarding.dart';

void main() {
  setUp(() {
    Vault.fake();
    MagicStarterOnboarding.resetForTesting();
  });

  tearDown(() {
    Vault.unfake();
    MagicStarterOnboarding.resetForTesting();
  });

  test('a step is not completed by default before any load', () {
    expect(MagicStarterOnboarding.isCompleted('locale'), isFalse);
  });

  test(
    'markCompleted flips the flag and persists it under the step-scoped key',
    () async {
      final fake = Vault.fake();

      await MagicStarterOnboarding.markCompleted('locale');

      expect(MagicStarterOnboarding.isCompleted('locale'), isTrue);
      fake.assertWritten('onboarding_locale_done');
      expect(await Vault.get('onboarding_locale_done'), isNotNull);
    },
  );

  test(
    'load resolves completed for a step whose vault flag is present',
    () async {
      Vault.fake({'onboarding_locale_done': '1'});

      await MagicStarterOnboarding.load(['locale']);

      expect(MagicStarterOnboarding.isCompleted('locale'), isTrue);
    },
  );

  test(
    'load resolves not-completed for a step whose vault flag is absent',
    () async {
      await MagicStarterOnboarding.load(['locale']);

      expect(MagicStarterOnboarding.isCompleted('locale'), isFalse);
    },
  );

  test('load persists per-step results across multiple steps', () async {
    Vault.fake({'onboarding_locale_done': '1'});

    await MagicStarterOnboarding.load(['locale', 'welcome']);

    expect(MagicStarterOnboarding.isCompleted('locale'), isTrue);
    expect(MagicStarterOnboarding.isCompleted('welcome'), isFalse);
  });

  test('a vault read failure during load reads as not completed', () async {
    final fake = Vault.fake();
    fake.throwOnGet();

    await MagicStarterOnboarding.load(['locale']);

    expect(MagicStarterOnboarding.isCompleted('locale'), isFalse);
  });
}
