import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('setUpMagicStarterForTests', () {
    test('binds a resolvable default manager when none is given', () {
      setUpMagicStarterForTests();

      expect(Magic.bound('magic_starter'), isTrue);
      expect(Magic.make<MagicStarterManager>('magic_starter'), isNotNull);
    });

    test('binds the given custom manager', () {
      final customManager = MagicStarterManager()
        ..newsletterLabel = 'Custom label';

      setUpMagicStarterForTests(manager: customManager);

      expect(
        Magic.make<MagicStarterManager>('magic_starter'),
        same(customManager),
      );
    });
  });

  group('MagicStarter.manager defensive fallback', () {
    // NOTE: the one-time warning guard is a process-wide static flag (by
    // design — see the facade), so this test MUST run before any other test
    // in this file accesses the unbound fallback, or the guard will already
    // be tripped and no warning will fire here.
    test('emits exactly one kDebugMode warning on unbound access', () {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };

      try {
        MagicStarter.manager;
        MagicStarter.manager;
        MagicStarter.manager;
      } finally {
        debugPrint = originalDebugPrint;
      }

      final warnings = logs.where(
        (m) => m.contains('MagicStarterManager not bound'),
      );
      expect(warnings.length, 1);
    });

    test('returns a shared default manager instead of throwing when unbound',
        () {
      expect(Magic.bound('magic_starter'), isFalse);

      final first = MagicStarter.manager;
      final second = MagicStarter.manager;

      expect(first, isNotNull);
      // Repeated unbound access returns the SAME cached instance.
      expect(identical(first, second), isTrue);
    });

    test('a bound manager still wins over the fallback', () {
      final boundManager = MagicStarterManager()
        ..newsletterLabel = 'Bound label';
      Magic.singleton('magic_starter', () => boundManager);

      expect(MagicStarter.manager, same(boundManager));
    });
  });
}
