import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MagicStarterFeedbackController controller;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    setUpMagicStarterForTests();

    controller = MagicStarterFeedbackController();
  });

  tearDown(() {
    controller.dispose();
    Http.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('MagicStarterFeedbackController', () {
    test('is not eligible before anything is read', () {
      expect(controller.eligible, isFalse);
      expect(controller.conversationId, isNull);
    });

    test('loadEligibility reads GET /support/feedback', () async {
      final fake = Http.fake((request) {
        expect(request.method, 'GET');
        expect(request.url, '/support/feedback');

        return Http.response(<String, dynamic>{'eligible': true});
      });

      await controller.loadEligibility();

      fake.assertSentCount(1);
      expect(controller.eligible, isTrue);
    });

    test('loadEligibility reads an ineligible answer', () async {
      Http.fake((request) {
        return Http.response(<String, dynamic>{'eligible': false});
      });

      await controller.loadEligibility();

      expect(controller.eligible, isFalse);
    });

    test('a guest or unverified 403 reads as not eligible, quietly', () async {
      Http.fake((request) => Http.response(<String, dynamic>{}, 403));

      await controller.loadEligibility();

      expect(controller.eligible, isFalse);
      expect(controller.writeError, isNull);
    });

    test('a server error reads as not eligible and is logged', () async {
      final logs = Log.fake();
      addTearDown(Log.unfake);
      Http.fake((request) => Http.response(<String, dynamic>{}, 500));

      await controller.loadEligibility();

      expect(controller.eligible, isFalse);
      expect(logs.entries.where((e) => e.level == 'warning'), hasLength(1));
    });

    test('submit posts the score and the comment', () async {
      Http.fake((request) {
        if (request.method == 'GET') {
          return Http.response(<String, dynamic>{'eligible': true});
        }

        expect(request.method, 'POST');
        expect(request.url, '/support/feedback');
        expect(request.data, <String, dynamic>{
          'score': 3,
          'comment': 'Alerts arrive late',
        });

        return Http.response(<String, dynamic>{'conversation_id': 'c-9'});
      });

      await controller.loadEligibility();
      final sent = await controller.submit(3, comment: 'Alerts arrive late');

      expect(sent, isTrue);
      expect(controller.conversationId, 'c-9');
      expect(controller.eligible, isFalse);
    });

    test('submit leaves the comment out when there is none', () async {
      Http.fake((request) {
        expect(request.data, <String, dynamic>{'score': 9});

        return Http.response(<String, dynamic>{'conversation_id': null});
      });

      expect(await controller.submit(9), isTrue);
      expect(controller.conversationId, isNull);
    });

    test('submit(null) posts a dismissal', () async {
      final fake = Http.fake((request) {
        expect(request.method, 'POST');
        expect(request.url, '/support/feedback');
        expect(request.data, <String, dynamic>{'score': null});

        return Http.response(<String, dynamic>{'conversation_id': null});
      });

      expect(await controller.submit(null), isTrue);

      fake.assertSentCount(1);
    });

    test('dismiss is a dismissal that also hides the card', () async {
      Http.fake((request) {
        if (request.method == 'GET') {
          return Http.response(<String, dynamic>{'eligible': true});
        }

        expect(request.data, <String, dynamic>{'score': null});

        return Http.response(<String, dynamic>{'conversation_id': null});
      });

      await controller.loadEligibility();
      await controller.dismiss();

      expect(controller.eligible, isFalse);
    });

    test('a failed dismissal still hides the card for the session', () async {
      Http.fake((request) {
        if (request.method == 'GET') {
          return Http.response(<String, dynamic>{'eligible': true});
        }

        return Http.response(<String, dynamic>{}, 500);
      });

      await controller.loadEligibility();
      await controller.dismiss();

      expect(controller.eligible, isFalse);
    });

    test('a refused submit answers false and keeps the field errors', () async {
      Http.fake((request) {
        return Http.response(<String, dynamic>{
          'message': 'The comment is too long.',
          'errors': <String, dynamic>{
            'comment': <String>['The comment is too long.'],
          },
        }, 422);
      });

      final sent = await controller.submit(2, comment: 'x');

      expect(sent, isFalse);
      expect(controller.getError('comment'), 'The comment is too long.');
    });

    test('a refused submit that is not validation sets writeError', () async {
      Http.fake((request) => Http.response(<String, dynamic>{}, 500));

      final sent = await controller.submit(2);

      expect(sent, isFalse);
      expect(controller.writeError, isNotNull);
    });

    test('resetForSession drops the previous user eligibility', () async {
      Http.fake((request) {
        if (request.method == 'GET') {
          return Http.response(<String, dynamic>{'eligible': true});
        }

        return Http.response(<String, dynamic>{'conversation_id': 'c-1'});
      });

      await controller.loadEligibility();
      await controller.submit(2);

      // The next user's answer is not in yet.
      Http.fake((request) => Http.response(<String, dynamic>{}, 403));
      await controller.resetForSession();

      expect(controller.eligible, isFalse);
      expect(controller.conversationId, isNull);
    });

    test(
      'an eligibility answer from before a session reset is dropped',
      () async {
        final answer = Completer<MagicResponse>();
        Http.fake((MagicRequest request) async => answer.future);

        final read = controller.loadEligibility();

        Http.fake((request) => Http.response(<String, dynamic>{}, 403));
        await controller.resetForSession();
        answer.complete(Http.response(<String, dynamic>{'eligible': true}));
        await read;

        expect(controller.eligible, isFalse);
      },
    );
  });
}
