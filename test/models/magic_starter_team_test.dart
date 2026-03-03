import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarterTeam', () {
    // ---------------------------------------------------------------------
    // fromMap — basic parsing
    // ---------------------------------------------------------------------

    group('fromMap', () {
      test('parses id and name correctly', () {
        final team = MagicStarterTeam.fromMap({
          'id': 1,
          'name': 'Acme',
        });

        expect(team.id, equals(1));
        expect(team.name, equals('Acme'));
      });

      test('id preserves dynamic type (string)', () {
        final team = MagicStarterTeam.fromMap({
          'id': 'uuid-abc',
          'name': 'Acme',
        });

        expect(team.id, equals('uuid-abc'));
      });

      test('name is null when missing', () {
        final team = MagicStarterTeam.fromMap({'id': 1});

        expect(team.name, isNull);
      });
    });

    // ---------------------------------------------------------------------
    // isPersonalTeam
    // ---------------------------------------------------------------------

    group('isPersonalTeam', () {
      test('is false by default', () {
        final team = MagicStarterTeam.fromMap({
          'id': 1,
          'name': 'Acme',
        });

        expect(team.isPersonalTeam, isFalse);
      });

      test('is true when personal_team is true (bool)', () {
        final team = MagicStarterTeam.fromMap({
          'id': 1,
          'name': 'Acme',
          'personal_team': true,
        });

        expect(team.isPersonalTeam, isTrue);
      });

      test('is true when personal_team is 1 (int)', () {
        final team = MagicStarterTeam.fromMap({
          'id': 1,
          'name': 'Acme',
          'personal_team': 1,
        });

        expect(team.isPersonalTeam, isTrue);
      });

      test('is false when personal_team is false', () {
        final team = MagicStarterTeam.fromMap({
          'id': 1,
          'name': 'Acme',
          'personal_team': false,
        });

        expect(team.isPersonalTeam, isFalse);
      });

      test('is false when personal_team is 0', () {
        final team = MagicStarterTeam.fromMap({
          'id': 1,
          'name': 'Acme',
          'personal_team': 0,
        });

        expect(team.isPersonalTeam, isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // photoUrl
    // ---------------------------------------------------------------------

    group('photoUrl', () {
      test('is null when profile_photo_url is missing', () {
        final team = MagicStarterTeam.fromMap({
          'id': 1,
          'name': 'Acme',
        });

        expect(team.photoUrl, isNull);
      });

      test('returns URL when profile_photo_url is present', () {
        final team = MagicStarterTeam.fromMap({
          'id': 1,
          'name': 'Acme',
          'profile_photo_url': 'https://example.com/team.jpg',
        });

        expect(
          team.photoUrl,
          equals('https://example.com/team.jpg'),
        );
      });
    });

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    group('constructor', () {
      test('creates team with required and optional params', () {
        const team = MagicStarterTeam(
          id: 5,
          name: 'Test Team',
          photoUrl: 'https://test.com/photo.png',
          isPersonalTeam: true,
        );

        expect(team.id, equals(5));
        expect(team.name, equals('Test Team'));
        expect(team.photoUrl, equals('https://test.com/photo.png'));
        expect(team.isPersonalTeam, isTrue);
      });

      test('defaults isPersonalTeam to false', () {
        const team = MagicStarterTeam(id: 1);

        expect(team.isPersonalTeam, isFalse);
        expect(team.name, isNull);
        expect(team.photoUrl, isNull);
      });
    });
  });
}
