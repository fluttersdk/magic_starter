import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarterAuthUser', () {
    setUp(() {
      MagicApp.reset();
    });

    // ---------------------------------------------------------------------
    // fromMap — empty map
    // ---------------------------------------------------------------------

    group('fromMap with empty map', () {
      test('creates instance with exists = false', () {
        final user = MagicStarterAuthUser.fromMap({});

        expect(user.exists, isFalse);
      });

      test('all typed getters return null', () {
        final user = MagicStarterAuthUser.fromMap({});

        expect(user.id, isNull);
        expect(user.name, isNull);
        expect(user.email, isNull);
        expect(user.profilePhotoUrl, isNull);
      });
    });

    // ---------------------------------------------------------------------
    // fromMap — populated map
    // ---------------------------------------------------------------------

    group('fromMap with populated data', () {
      test('sets typed getters correctly', () {
        final user = MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Alice',
          'email': 'a@b.com',
        });

        expect(user.id, equals('1'));
        expect(user.name, equals('Alice'));
        expect(user.email, equals('a@b.com'));
      });

      test('sets exists = true when id is present', () {
        final user = MagicStarterAuthUser.fromMap({'id': 1});

        expect(user.exists, isTrue);
      });

      test('id returns string representation', () {
        final user = MagicStarterAuthUser.fromMap({'id': 42});

        expect(user.id, equals('42'));
      });
    });

    // ---------------------------------------------------------------------
    // profilePhotoUrl
    // ---------------------------------------------------------------------

    group('profilePhotoUrl', () {
      test('returns null when not in map', () {
        final user = MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Alice',
        });

        expect(user.profilePhotoUrl, isNull);
      });

      test('returns URL string when present', () {
        final user = MagicStarterAuthUser.fromMap({
          'id': 1,
          'profile_photo_url': 'https://example.com/photo.jpg',
        });

        expect(
          user.profilePhotoUrl,
          equals('https://example.com/photo.jpg'),
        );
      });
    });

    // ---------------------------------------------------------------------
    // Model metadata
    // ---------------------------------------------------------------------

    group('model metadata', () {
      test('table is users', () {
        final user = MagicStarterAuthUser.fromMap({});

        expect(user.table, equals('users'));
      });

      test('resource is users', () {
        final user = MagicStarterAuthUser.fromMap({});

        expect(user.resource, equals('users'));
      });

      test('fillable contains name and email', () {
        final user = MagicStarterAuthUser.fromMap({});

        expect(user.fillable, containsAll(['name', 'email']));
      });
    });

    // ---------------------------------------------------------------------
    // Authenticatable mixin
    // ---------------------------------------------------------------------

    group('Authenticatable mixin', () {
      test('authIdentifier returns the id attribute', () {
        final user = MagicStarterAuthUser.fromMap({'id': 99});

        expect(user.authIdentifier, equals(99));
      });
    });
  });
}
