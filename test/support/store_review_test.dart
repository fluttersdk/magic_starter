import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The method channel `in_app_review` talks to. Faking it here, rather than
/// swapping the platform interface, keeps the test off a package this one does
/// not depend on directly, and exercises the real plugin call path.
const MethodChannel _channel = MethodChannel('dev.britannio.in_app_review');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  int requests() => calls.where((c) => c.method == 'requestReview').length;

  void signIn({required int ageDays, bool guest = false}) {
    Auth.fake(
      user: MagicStarterAuthUser.fromMap(<String, dynamic>{
        'id': 5,
        'name': 'Ada Lovelace',
        'is_guest': guest,
        'created_at': DateTime.now()
            .subtract(Duration(days: ageDays))
            .toUtc()
            .toIso8601String(),
      }),
    );
  }

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('log', () => LogManager());
    Config.set('logging', <String, dynamic>{
      'default': 'console',
      'channels': <String, dynamic>{
        'console': <String, dynamic>{'driver': 'console', 'level': 'debug'},
      },
    });
    Config.set('magic_starter.features.store_review', true);

    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);

          return call.method == 'isAvailable' ? true : null;
        });

    Vault.fake();
    MagicStarterStoreReview.resetForTesting();
    MagicStarterStoreReview.debugIsWebOverride = false;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    MagicStarterStoreReview.resetForTesting();
    Vault.unfake();
    Auth.unfake();
    Http.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('maybeRequest', () {
    test('asks an account older than a week and records when', () async {
      signIn(ageDays: 30);

      final asked = await MagicStarterStoreReview.maybeRequest();

      expect(asked, isTrue);
      expect(requests(), 1);
      final stored = await Vault.get(MagicStarterStoreReview.lastPromptKey);
      expect(DateTime.tryParse(stored ?? ''), isNotNull);
    });

    test('does nothing on the web', () async {
      signIn(ageDays: 30);
      MagicStarterStoreReview.debugIsWebOverride = true;

      expect(await MagicStarterStoreReview.maybeRequest(), isFalse);
      expect(requests(), 0);
    });

    test('does nothing before the account is 7 days old', () async {
      signIn(ageDays: 6);

      expect(await MagicStarterStoreReview.maybeRequest(), isFalse);
      expect(requests(), 0);
    });

    test('does nothing within 120 days of the last prompt', () async {
      signIn(ageDays: 400);
      Vault.fake(<String, String>{
        MagicStarterStoreReview.lastPromptKey: DateTime.now()
            .subtract(const Duration(days: 119))
            .toUtc()
            .toIso8601String(),
      });

      expect(await MagicStarterStoreReview.maybeRequest(), isFalse);
      expect(requests(), 0);
    });

    test('asks again once 120 days have passed', () async {
      signIn(ageDays: 400);
      Vault.fake(<String, String>{
        MagicStarterStoreReview.lastPromptKey: DateTime.now()
            .subtract(const Duration(days: 121))
            .toUtc()
            .toIso8601String(),
      });

      expect(await MagicStarterStoreReview.maybeRequest(), isTrue);
      expect(requests(), 1);
    });

    test(
      'does nothing in a session where the feedback card was shown',
      () async {
        signIn(ageDays: 30);
        MagicStarterStoreReview.noteFeedbackCardShown();

        expect(await MagicStarterStoreReview.maybeRequest(), isFalse);
        expect(requests(), 0);
      },
    );

    test('does nothing for a guest', () async {
      signIn(ageDays: 30, guest: true);

      expect(await MagicStarterStoreReview.maybeRequest(), isFalse);
      expect(requests(), 0);
    });

    test('does nothing while the feature is off', () async {
      signIn(ageDays: 30);
      Config.set('magic_starter.features.store_review', false);

      expect(await MagicStarterStoreReview.maybeRequest(), isFalse);
      expect(requests(), 0);
    });

    test('a second call right after the first does not ask twice', () async {
      signIn(ageDays: 30);

      await Future.wait(<Future<bool>>[
        MagicStarterStoreReview.maybeRequest(),
        MagicStarterStoreReview.maybeRequest(),
      ]);

      expect(requests(), 1);
    });
  });

  group('beside the feedback card', () {
    setUp(() => Config.set('magic_starter.features.support_feedback', true));

    test('waits for the card eligibility and stays quiet when due', () async {
      signIn(ageDays: 30);
      final answer = Completer<MagicResponse>();
      Http.fake((MagicRequest request) async => answer.future);

      final asked = MagicStarterStoreReview.maybeRequest();
      await Future<void>.delayed(Duration.zero);
      answer.complete(Http.response(<String, dynamic>{'eligible': true}));

      expect(await asked, isFalse);
      expect(requests(), 0);
      expect(MagicStarterStoreReview.feedbackCardShown, isTrue);
    });

    test('still asks when the card is not due', () async {
      signIn(ageDays: 30);
      final answer = Completer<MagicResponse>();
      Http.fake((MagicRequest request) async => answer.future);

      final asked = MagicStarterStoreReview.maybeRequest();
      await Future<void>.delayed(Duration.zero);
      answer.complete(Http.response(<String, dynamic>{'eligible': false}));

      expect(await asked, isTrue);
      expect(requests(), 1);
    });

    test('shares one eligibility read with the card', () async {
      signIn(ageDays: 30);
      final fake = Http.fake((request) {
        return Http.response(<String, dynamic>{'eligible': false});
      });

      await Future.wait(<Future<void>>[
        MagicStarterFeedbackController.instance.loadEligibility(),
        MagicStarterStoreReview.maybeRequest(),
      ]);

      fake.assertSentCount(1);
    });

    test('does not read eligibility for an account too young to ask', () async {
      signIn(ageDays: 2);
      final fake = Http.fake((request) {
        return Http.response(<String, dynamic>{'eligible': true});
      });

      expect(await MagicStarterStoreReview.maybeRequest(), isFalse);

      fake.assertSentCount(0);
    });
  });

  group('the store listing', () {
    test('is offered on a device and not on the web', () {
      expect(MagicStarterStoreReview.canOpenStoreListing, isTrue);

      MagicStarterStoreReview.debugIsWebOverride = true;
      expect(MagicStarterStoreReview.canOpenStoreListing, isFalse);
    });

    test('needs the App Store id on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(MagicStarterStoreReview.canOpenStoreListing, isFalse);

      Config.set('magic_starter.store_review.app_store_id', '1234567890');
      expect(MagicStarterStoreReview.canOpenStoreListing, isTrue);
    });

    test('is not offered while the feature is off', () {
      Config.set('magic_starter.features.store_review', false);

      expect(MagicStarterStoreReview.canOpenStoreListing, isFalse);
    });
  });
}
