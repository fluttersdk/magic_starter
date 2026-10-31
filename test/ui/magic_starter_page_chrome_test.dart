import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart' show Magic, MagicApp;
import 'package:magic_starter/magic_starter.dart';

/// Reports [entry] from `initState` the way a page header does, so a listener
/// that rebuilds on the chrome would be notified mid-build if the chrome did
/// not defer.
class _InitStateReporter extends StatefulWidget {
  final MagicStarterPageChrome chrome;
  final MagicStarterPageChromeEntry entry;

  const _InitStateReporter({required this.chrome, required this.entry});

  @override
  State<_InitStateReporter> createState() => _InitStateReporterState();
}

class _InitStateReporterState extends State<_InitStateReporter> {
  @override
  void initState() {
    super.initState();
    widget.chrome.report(this, widget.entry);
  }

  @override
  void dispose() {
    widget.chrome.withdraw(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A host top bar: rebuilds whenever the chrome notifies.
class _Listener extends StatefulWidget {
  final MagicStarterPageChrome chrome;

  const _Listener({required this.chrome});

  @override
  State<_Listener> createState() => _ListenerState();
}

class _ListenerState extends State<_Listener> {
  @override
  void initState() {
    super.initState();
    widget.chrome.addListener(_changed);
  }

  @override
  void dispose() {
    widget.chrome.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.chrome.current?.title ?? 'none',
      textDirection: TextDirection.ltr,
    );
  }
}

void main() {
  const MagicStarterPageChromeEntry profile = MagicStarterPageChromeEntry(
    title: 'Profile',
    subtitle: 'Your details',
    backLabel: 'Settings',
    backFallback: '/settings',
  );
  const MagicStarterPageChromeEntry sessions = MagicStarterPageChromeEntry(
    title: 'Sessions',
  );

  group('MagicStarterPageChromeEntry', () {
    test('has value equality over all four fields', () {
      expect(
        profile,
        const MagicStarterPageChromeEntry(
          title: 'Profile',
          subtitle: 'Your details',
          backLabel: 'Settings',
          backFallback: '/settings',
        ),
      );
      expect(
        profile.hashCode,
        const MagicStarterPageChromeEntry(
          title: 'Profile',
          subtitle: 'Your details',
          backLabel: 'Settings',
          backFallback: '/settings',
        ).hashCode,
      );
      expect(
        profile,
        isNot(
          const MagicStarterPageChromeEntry(
            title: 'Profile',
            subtitle: 'Your details',
            backLabel: 'Settings',
            backFallback: '/account',
          ),
        ),
      );
    });
  });

  group('MagicStarterPageChrome', () {
    late MagicStarterPageChrome chrome;
    late int notifications;

    setUp(() {
      chrome = MagicStarterPageChrome();
      notifications = 0;
      chrome.addListener(() => notifications++);
    });

    testWidgets('hostOwns is false while nothing is registered', (
      tester,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      );

      expect(chrome.hostOwns(captured), isFalse);

      chrome.ownsWhen = (BuildContext context) => true;
      expect(chrome.hostOwns(captured), isTrue);
    });

    testWidgets('current is the reported entry, null once withdrawn', (
      tester,
    ) async {
      final Object owner = Object();

      chrome.report(owner, profile);
      expect(chrome.current, profile);

      chrome.withdraw(owner);
      expect(chrome.current, isNull);
    });

    testWidgets('withdrawing the older owner leaves the newer one current', (
      tester,
    ) async {
      final Object older = Object();
      final Object newer = Object();

      chrome.report(older, profile);
      chrome.report(newer, sessions);
      expect(chrome.current, sessions);

      chrome.withdraw(older);
      expect(chrome.current, sessions);

      chrome.withdraw(newer);
      expect(chrome.current, isNull);
    });

    testWidgets('an update from the older owner does not take over', (
      tester,
    ) async {
      final Object older = Object();
      final Object newer = Object();

      chrome.report(older, profile);
      chrome.report(newer, sessions);
      chrome.report(older, const MagicStarterPageChromeEntry(title: 'Edited'));

      expect(chrome.current, sessions);
    });

    testWidgets('notifies after the frame, once per change', (tester) async {
      final Object owner = Object();

      chrome.report(owner, profile);
      expect(notifications, 0);

      await tester.pump();
      expect(notifications, 1);

      // The same entry again is no change.
      chrome.report(owner, profile);
      await tester.pump();
      expect(notifications, 1);

      chrome.report(owner, sessions);
      await tester.pump();
      expect(notifications, 2);
    });

    testWidgets('a change undone within the frame notifies nobody', (
      tester,
    ) async {
      final Object owner = Object();
      final Object other = Object();

      chrome.report(owner, profile);
      await tester.pump();
      expect(notifications, 1);

      chrome.report(other, sessions);
      chrome.withdraw(other);
      await tester.pump();

      expect(notifications, 1);
      expect(chrome.current, profile);
    });

    testWidgets('a report from initState never notifies during the build', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              _Listener(chrome: chrome),
              _InitStateReporter(chrome: chrome, entry: profile),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Profile'), findsOneWidget);

      // The withdraw from dispose is deferred the same way.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [_Listener(chrome: chrome)]),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('none'), findsOneWidget);
    });

    testWidgets('reset forgets the predicate and every entry', (tester) async {
      chrome.ownsWhen = (BuildContext context) => true;
      chrome.report(Object(), profile);

      chrome.reset();

      expect(chrome.ownsWhen, isNull);
      expect(chrome.current, isNull);
    });
  });

  group('MagicStarter facade', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('magic_starter', () => MagicStarterManager());
    });

    tearDown(() {
      MagicApp.reset();
      Magic.flush();
    });

    testWidgets('useHostPageChrome registers the predicate on pageChrome', (
      tester,
    ) async {
      double? width;
      MagicStarter.useHostPageChrome((BuildContext context) {
        width = MediaQuery.sizeOf(context).width;
        return width! < 600;
      });

      late bool owns;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (BuildContext context) {
              owns = MagicStarter.pageChrome.hostOwns(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(owns, isTrue);
      expect(width, 390);
    });

    test('the manager reset clears the predicate', () {
      MagicStarter.useHostPageChrome((BuildContext context) => true);

      MagicStarter.manager.reset();

      expect(MagicStarter.pageChrome.ownsWhen, isNull);
    });
  });
}
