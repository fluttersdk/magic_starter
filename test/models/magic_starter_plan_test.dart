import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarterPlan', () {
    // ---------------------------------------------------------------------
    // fromMap — a real uptizm catalogue row (the "pro" tier, copied verbatim
    // from uptizm/backend/config/plans.php). A hand-written minimal map
    // agrees with whatever the decoder happens to read and cannot catch a
    // field the decoder drops; this fixture can.
    //
    // `limits.regions` is `count(MonitorRegion::cases())` in the PHP source,
    // which resolves to 5 for the 5 cases MonitorRegion currently declares
    // (us-east, us-west, eu-west, eu-central, ap); the fixture below inlines
    // that resolved value since PHP's `count()` call has no Dart literal form.
    // ---------------------------------------------------------------------

    final Map<String, dynamic> uptizmProTier = <String, dynamic>{
      'id': 'pro',
      'name': 'Pro',
      'tagline': 'Startups and small teams that page.',
      'monthly': 34,
      'annual': 29,
      'currency': 'usd',
      'ai_line':
          'Full AI incident analysis: evidence, confidence, citations, drafted updates.',
      'features': <String>[
        '50 monitors · 30-second checks',
        '3 status pages · 1,000 subscribers',
        '3 responders · on-call schedules & escalation policies',
        'SLO targets & error budgets',
      ],
      'responder_add_on': r'+$9/mo per extra responder',
      'recommended': true,
      'limits': <String, dynamic>{
        'monitors': 50,
        'check_interval_sec': 30,
        'status_pages': 3,
        'subscribers': 1000,
        'responders': 3,
        'regions': 5,
        'ai': 'analysis',
        'white_label': false,
        'private_pages': false,
        'sso': false,
      },
    };

    group('fromMap — typed fields', () {
      test('decodes all eight typed fields from the real pro tier', () {
        final plan = MagicStarterPlan.fromMap(uptizmProTier);

        expect(plan.id, equals('pro'));
        expect(plan.name, equals('Pro'));
        expect(plan.tagline, equals('Startups and small teams that page.'));
        expect(plan.monthly, equals(34));
        expect(plan.annual, equals(29));
        expect(plan.currency, equals('usd'));
        expect(
          plan.features,
          equals(<String>[
            '50 monitors · 30-second checks',
            '3 status pages · 1,000 subscribers',
            '3 responders · on-call schedules & escalation policies',
            'SLO targets & error budgets',
          ]),
        );
        expect(plan.recommended, isTrue);
      });
    });

    group('fromMap — raw carries the opaque keys', () {
      test('raw[ai_line] survives verbatim', () {
        final plan = MagicStarterPlan.fromMap(uptizmProTier);

        expect(
          plan.raw['ai_line'],
          equals(
            'Full AI incident analysis: evidence, confidence, citations, drafted updates.',
          ),
        );
      });

      test('raw[responder_add_on] survives verbatim', () {
        final plan = MagicStarterPlan.fromMap(uptizmProTier);

        expect(plan.raw['responder_add_on'],
            equals(r'+$9/mo per extra responder'));
      });

      test('raw[limits] is reachable and its nested values survive', () {
        final plan = MagicStarterPlan.fromMap(uptizmProTier);
        final Map<String, dynamic> limits =
            plan.raw['limits'] as Map<String, dynamic>;

        expect(limits['monitors'], equals(50));
        expect(limits['check_interval_sec'], equals(30));
        expect(limits['ai'], equals('analysis'));
        expect(limits['white_label'], isFalse);
      });
    });

    group('fromMap — tolerant decoding', () {
      test('a missing features key decodes to an empty list', () {
        final plan = MagicStarterPlan.fromMap(<String, dynamic>{
          'id': 'free',
          'name': 'Free',
        });

        expect(plan.features, isEmpty);
      });

      test('a missing recommended key decodes to false', () {
        final plan = MagicStarterPlan.fromMap(<String, dynamic>{
          'id': 'free',
          'name': 'Free',
        });

        expect(plan.recommended, isFalse);
      });

      test('monthly arriving as a JSON double still decodes to an int', () {
        final plan = MagicStarterPlan.fromMap(<String, dynamic>{
          'id': 'pro',
          'name': 'Pro',
          'monthly': 34.0,
          'annual': 29.0,
        });

        expect(plan.monthly, equals(34));
        expect(plan.annual, equals(29));
      });

      test(
          'a null monthly/annual (the enterprise "contact us" case) stays null',
          () {
        final plan = MagicStarterPlan.fromMap(<String, dynamic>{
          'id': 'enterprise',
          'name': 'Enterprise',
          'monthly': null,
          'annual': null,
        });

        expect(plan.monthly, isNull);
        expect(plan.annual, isNull);
      });
    });

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    group('constructor', () {
      test('creates a plan from already-decoded fields', () {
        const plan = MagicStarterPlan(
          id: 'free',
          name: 'Free',
          tagline: 'Kick the tires.',
          monthly: 0,
          annual: 0,
          currency: 'usd',
          features: <String>['1 monitor'],
          recommended: false,
          raw: <String, dynamic>{'id': 'free'},
        );

        expect(plan.id, equals('free'));
        expect(plan.name, equals('Free'));
        expect(plan.tagline, equals('Kick the tires.'));
        expect(plan.monthly, equals(0));
        expect(plan.annual, equals(0));
        expect(plan.currency, equals('usd'));
        expect(plan.features, equals(<String>['1 monitor']));
        expect(plan.recommended, isFalse);
        expect(plan.raw, equals(<String, dynamic>{'id': 'free'}));
      });
    });
  });
}
