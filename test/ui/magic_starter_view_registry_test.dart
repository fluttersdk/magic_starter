import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarterViewRegistry', () {
    late MagicStarterViewRegistry registry;

    setUp(() {
      registry = MagicStarterViewRegistry();
    });

    // -------------------------------------------------------------------------
    // register() + has()
    // -------------------------------------------------------------------------

    group('register() + has()', () {
      test('has() returns true after registration', () {
        registry.register('login', () => const SizedBox());

        expect(registry.has('login'), isTrue);
      });

      test('has() returns false for unregistered key', () {
        expect(registry.has('non-existent'), isFalse);
      });

      test('overwrites previous builder for same key', () {
        registry.register('login', () => const SizedBox());
        registry.register('login', () => const Placeholder());

        // Should still have the key — no error on overwrite.
        expect(registry.has('login'), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // registerLayout() + hasLayout()
    // -------------------------------------------------------------------------

    group('registerLayout() + hasLayout()', () {
      test('hasLayout() returns true after registration', () {
        registry.registerLayout('guest', (child) => child);

        expect(registry.hasLayout('guest'), isTrue);
      });

      test('hasLayout() returns false for unregistered key', () {
        expect(registry.hasLayout('non-existent'), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // make()
    // -------------------------------------------------------------------------

    group('make()', () {
      test('calls the registered builder and returns the widget', () {
        const expected = SizedBox(key: Key('test-widget'));
        registry.register('login', () => expected);

        final Widget result = registry.make('login');

        expect(result, same(expected));
      });

      test('throws StateError for unregistered key', () {
        expect(
          () => registry.make('missing'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('missing'),
            ),
          ),
        );
      });
    });

    // -------------------------------------------------------------------------
    // makeLayout()
    // -------------------------------------------------------------------------

    group('makeLayout()', () {
      test('wraps child with registered layout builder', () {
        const child = SizedBox(key: Key('child'));

        registry.registerLayout('guest', (Widget child) {
          return Column(
            children: [child],
          );
        });

        final Widget result = registry.makeLayout(
          'guest',
          child: child,
        );

        expect(result, isA<Column>());
        expect((result as Column).children, contains(child));
      });

      test('throws StateError for unregistered key', () {
        expect(
          () => registry.makeLayout(
            'missing',
            child: const SizedBox(),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('missing'),
            ),
          ),
        );
      });
    });

    // -------------------------------------------------------------------------
    // clear()
    // -------------------------------------------------------------------------

    group('clear()', () {
      test('removes all builders and layouts', () {
        registry.register('login', () => const SizedBox());
        registry.register('register', () => const Placeholder());
        registry.registerLayout('guest', (child) => child);
        registry.registerLayout('app', (child) => child);

        registry.clear();

        expect(registry.has('login'), isFalse);
        expect(registry.has('register'), isFalse);
        expect(registry.hasLayout('guest'), isFalse);
        expect(registry.hasLayout('app'), isFalse);
      });

      test('make() throws after clear()', () {
        registry.register('login', () => const SizedBox());
        registry.clear();

        expect(
          () => registry.make('login'),
          throwsA(isA<StateError>()),
        );
      });

      test('makeLayout() throws after clear()', () {
        registry.registerLayout('guest', (child) => child);
        registry.clear();

        expect(
          () => registry.makeLayout(
            'guest',
            child: const SizedBox(),
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // modal registry
    // -------------------------------------------------------------------------

    group('modal registry', () {
      test(
          'registerModal() stores a builder that can be retrieved via makeModal()',
          () {
        const expected = SizedBox(key: Key('modal-widget'));
        registry.registerModal('confirm', () => expected);

        final Widget result = registry.makeModal('confirm');

        expect(result, same(expected));
      });

      test('hasModal() returns true for registered key', () {
        registry.registerModal('confirm', () => const SizedBox());

        expect(registry.hasModal('confirm'), isTrue);
      });

      test('hasModal() returns false for unregistered key', () {
        expect(registry.hasModal('non-existent'), isFalse);
      });

      test('makeModal() returns widget from registered builder', () {
        registry.registerModal('alert', () => const Placeholder());

        final Widget result = registry.makeModal('alert');

        expect(result, isA<Placeholder>());
      });

      test('makeModal() throws StateError for unregistered key', () {
        expect(
          () => registry.makeModal('missing'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('missing'),
            ),
          ),
        );
      });

      test(
          'clear() clears modal builders — hasModal() returns false after clear()',
          () {
        registry.registerModal('confirm', () => const SizedBox());
        registry.registerModal('alert', () => const Placeholder());

        registry.clear();

        expect(registry.hasModal('confirm'), isFalse);
        expect(registry.hasModal('alert'), isFalse);
      });

      test('makeModal() throws after clear()', () {
        registry.registerModal('confirm', () => const SizedBox());
        registry.clear();

        expect(
          () => registry.makeModal('confirm'),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
