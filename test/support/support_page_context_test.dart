import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLogManager logs;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    setUpMagicStarterForTests();
    logs = Log.fake();

    MagicStarterSupportPageContext.resetForTesting();
  });

  tearDown(() {
    MagicStarterSupportPageContext.resetForTesting();
    Log.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('MagicStarterSupportPageRef', () {
    test('toMap carries the kind and the id', () {
      const ref = MagicStarterSupportPageRef(kind: 'monitor', id: '42');

      expect(ref.toMap(), <String, String>{'kind': 'monitor', 'id': '42'});
    });

    test('equal kind and id are equal and share a hash code', () {
      const a = MagicStarterSupportPageRef(kind: 'monitor', id: '42');
      const b = MagicStarterSupportPageRef(kind: 'monitor', id: '42');
      const c = MagicStarterSupportPageRef(kind: 'incident', id: '42');
      const d = MagicStarterSupportPageRef(kind: 'monitor', id: '43');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, isNot(d));
    });
  });

  group('MagicStarterSupportPageContext.collect', () {
    test('is empty without a registered provider', () {
      expect(MagicStarterSupportPageContext.collect(), isEmpty);
    });

    test('keeps the references in the order the provider gave them', () {
      MagicStarter.usePageContext(
        () => const <MagicStarterSupportPageRef>[
          MagicStarterSupportPageRef(kind: 'monitor', id: '9'),
          MagicStarterSupportPageRef(kind: 'incident', id: '3'),
        ],
      );

      expect(MagicStarterSupportPageContext.collect(), <Map<String, String>>[
        <String, String>{'kind': 'monitor', 'id': '9'},
        <String, String>{'kind': 'incident', 'id': '3'},
      ]);
    });

    test('reads the provider on every call, not once at registration', () {
      var id = 1;
      MagicStarter.usePageContext(
        () => <MagicStarterSupportPageRef>[
          MagicStarterSupportPageRef(kind: 'monitor', id: '${id++}'),
        ],
      );

      expect(MagicStarterSupportPageContext.collect().single['id'], '1');
      expect(MagicStarterSupportPageContext.collect().single['id'], '2');
    });

    test('drops a duplicate and keeps the first occurrence', () {
      MagicStarter.usePageContext(
        () => const <MagicStarterSupportPageRef>[
          MagicStarterSupportPageRef(kind: 'monitor', id: '9'),
          MagicStarterSupportPageRef(kind: 'incident', id: '3'),
          MagicStarterSupportPageRef(kind: 'monitor', id: '9'),
        ],
      );

      expect(MagicStarterSupportPageContext.collect(), <Map<String, String>>[
        <String, String>{'kind': 'monitor', 'id': '9'},
        <String, String>{'kind': 'incident', 'id': '3'},
      ]);
    });

    test('keeps at most three references, the first three', () {
      MagicStarter.usePageContext(
        () => <MagicStarterSupportPageRef>[
          for (var i = 1; i <= 5; i++)
            MagicStarterSupportPageRef(kind: 'monitor', id: '$i'),
        ],
      );

      final List<Map<String, String>> context =
          MagicStarterSupportPageContext.collect();

      expect(context.map((ref) => ref['id']), <String>['1', '2', '3']);
    });

    test('cuts kind and id to 64 characters', () {
      MagicStarter.usePageContext(
        () => <MagicStarterSupportPageRef>[
          MagicStarterSupportPageRef(kind: 'k' * 100, id: 'i' * 100),
        ],
      );

      expect(MagicStarterSupportPageContext.collect(), <Map<String, String>>[
        <String, String>{'kind': 'k' * 64, 'id': 'i' * 64},
      ]);
    });

    test('two references that differ only past the cut count as one', () {
      MagicStarter.usePageContext(
        () => <MagicStarterSupportPageRef>[
          MagicStarterSupportPageRef(kind: 'monitor', id: '${'i' * 64}a'),
          MagicStarterSupportPageRef(kind: 'monitor', id: '${'i' * 64}b'),
        ],
      );

      expect(MagicStarterSupportPageContext.collect(), hasLength(1));
    });

    test('drops a reference with an empty kind or an empty id', () {
      MagicStarter.usePageContext(
        () => const <MagicStarterSupportPageRef>[
          MagicStarterSupportPageRef(kind: '', id: '1'),
          MagicStarterSupportPageRef(kind: 'monitor', id: ''),
          MagicStarterSupportPageRef(kind: 'monitor', id: '2'),
        ],
      );

      expect(MagicStarterSupportPageContext.collect(), <Map<String, String>>[
        <String, String>{'kind': 'monitor', 'id': '2'},
      ]);
    });

    test('a throwing provider answers empty and logs a warning', () {
      MagicStarter.usePageContext(() => throw StateError('no route yet'));

      expect(MagicStarterSupportPageContext.collect(), isEmpty);
      expect(
        logs.entries.where((entry) => entry.level == 'warning').single.message,
        startsWith('[MagicStarterSupportPageContext] provider failed: '),
      );
    });

    test('a second usePageContext replaces the first', () {
      MagicStarter.usePageContext(
        () => const <MagicStarterSupportPageRef>[
          MagicStarterSupportPageRef(kind: 'monitor', id: '1'),
        ],
      );
      MagicStarter.usePageContext(
        () => const <MagicStarterSupportPageRef>[
          MagicStarterSupportPageRef(kind: 'incident', id: '2'),
        ],
      );

      expect(MagicStarterSupportPageContext.collect(), <Map<String, String>>[
        <String, String>{'kind': 'incident', 'id': '2'},
      ]);
    });

    test('resetForTesting forgets the registered provider', () {
      MagicStarter.usePageContext(
        () => const <MagicStarterSupportPageRef>[
          MagicStarterSupportPageRef(kind: 'monitor', id: '1'),
        ],
      );

      MagicStarterSupportPageContext.resetForTesting();

      expect(MagicStarterSupportPageContext.collect(), isEmpty);
    });
  });
}
