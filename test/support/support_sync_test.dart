import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_socket/magic_socket.dart';
import 'package:magic_starter/magic_starter.dart';

const String _channel = 'private-App.Models.User.5';
const String _event = 'support.conversation.updated';

Map<String, dynamic> conversationJson({
  int id = 7,
  bool hasUnread = false,
  int messages = 1,
}) {
  return <String, dynamic>{
    'id': id,
    'number': id + 100,
    'subject': 'Cannot add a monitor',
    'source': 'in_app',
    'status': 'open',
    'priority': 'normal',
    'last_activity_at': '2026-10-12T09:3$messages:00+00:00',
    'created_at': '2026-10-12T09:00:00+00:00',
    'has_unread': hasUnread,
    'awaiting_ai': false,
    'waiting_on_team': false,
    'messages': <Map<String, dynamic>>[
      for (var i = 1; i <= messages; i++)
        <String, dynamic>{
          'id': i,
          'sender_type': i.isEven ? 'staff' : 'customer',
          'kind': 'message',
          'body': 'Line $i',
          'created_at': '2026-10-12T09:00:00+00:00',
        },
    ],
  };
}

MagicResponse ok(Object? data) =>
    Http.response(<String, dynamic>{'data': data});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MagicStarterSupportSync sync;
  late List<String> sent;

  /// Notifications the retained surfaces received.
  late int ticks;
  void countTick() => ticks++;

  int count(String request) => sent.where((s) => s == request).length;

  /// Answers every list read with an empty page and records each request;
  /// [answers] overrides a request by `METHOD /path`.
  void fakeBackend([
    Map<String, FutureOr<MagicResponse> Function()> answers = const {},
  ]) {
    Http.fake((MagicRequest request) async {
      final String key = '${request.method} ${request.url}';
      sent.add(key);

      final answer = answers[key];
      if (answer != null) return answer();
      if (key == 'GET /support/conversations') {
        return ok(<Map<String, dynamic>>[]);
      }

      return Http.response(<String, dynamic>{}, 404);
    });
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
    setUpMagicStarterForTests();
    Auth.fake(
      user: MagicStarterAuthUser.fromMap(<String, dynamic>{
        'id': 5,
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
      }),
    );

    sent = <String>[];
    ticks = 0;
    sync = MagicStarterSupportSync.instance;
    sync.addListener(countTick);
  });

  tearDown(() {
    MagicStarterSupportSync.resetForTesting();
    Echo.unfake();
    BroadcastListeners.reset();
    Auth.unfake();
    Http.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('retain and release', () {
    testWidgets('two retains run one poll and one listener; only the last '
        'release stops them', (tester) async {
      final fake = Echo.fake();
      Config.set('broadcasting.default', 'reverb');
      fakeBackend();

      sync.retain();
      sync.retain();
      await tester.pump();
      fake.assertListening(_channel, _event);

      fake.dispatch(_channel, _event, <String, dynamic>{});
      await tester.pump();
      expect(ticks, 1, reason: 'one broadcast registration');
      expect(count('GET /support/conversations'), 1);

      await tester.pump(MagicStarterSupportSync.pollInterval);
      await tester.pump();
      expect(ticks, 2, reason: 'one poll timer');
      expect(count('GET /support/conversations'), 2);

      sync.release();
      await tester.pump(MagicStarterSupportSync.pollInterval);
      await tester.pump();
      expect(ticks, 3, reason: 'one surface still retains the poll');
      fake.assertListening(_channel, _event);

      sync.release();
      fake.assertNotListening(_channel, _event);
      await tester.pump(MagicStarterSupportSync.pollInterval * 2);
      await tester.pump();
      expect(ticks, 3);
      expect(count('GET /support/conversations'), 3);
    });

    testWidgets('a reconnect refetches once whatever the retain count', (
      tester,
    ) async {
      Echo.fake();
      Config.set('broadcasting.default', 'reverb');
      fakeBackend();

      sync.retain();
      sync.retain();
      sync.retain();
      sync.release();
      await tester.pump();

      BroadcastListeners.subscriptionForTesting('magic_starter_support')!
          .onReconnect!();
      await tester.pump();

      expect(ticks, 1);
      expect(count('GET /support/conversations'), 1);

      sync.release();
      sync.release();
      BroadcastListeners.subscriptionForTesting('magic_starter_support')!
          .onReconnect!();
      await tester.pump();

      expect(ticks, 1, reason: 'nobody retains the desk any more');
    });

    testWidgets('the null driver subscribes to nothing and the poll still '
        'runs', (tester) async {
      final fake = Echo.fake();
      Config.set('broadcasting.default', 'null');
      fakeBackend();

      sync.retain();
      await tester.pump();

      fake.assertNotSubscribed(_channel);
      expect(
        BroadcastListeners.subscriptionForTesting('magic_starter_support'),
        isNull,
      );

      await tester.pump(MagicStarterSupportSync.pollInterval);
      await tester.pump();
      expect(ticks, 1);

      sync.release();
    });
  });

  group('refresh', () {
    test('calls made before the read starts share one read', () async {
      fakeBackend();

      await Future.wait<void>([sync.refresh(), sync.refresh(), sync.refresh()]);

      expect(count('GET /support/conversations'), 1);
    });

    test('calls made while a read runs coalesce into one follow-up', () async {
      final first = Completer<MagicResponse>();
      var reads = 0;
      fakeBackend({
        'GET /support/conversations': () {
          reads++;

          return reads == 1 ? first.future : ok(<Map<String, dynamic>>[]);
        },
      });

      final running = sync.refresh();
      await pumpEventQueue();
      expect(reads, 1);

      final followUps = Future.wait<void>([
        sync.refresh(),
        sync.refresh(),
        sync.refresh(),
      ]);
      await pumpEventQueue();
      expect(reads, 1, reason: 'nothing overlaps the read in flight');

      first.complete(ok(<Map<String, dynamic>>[]));
      await running;
      await followUps;

      expect(reads, 2);
    });

    test('rereads every watched thread without moving the page', () async {
      fakeBackend({
        'GET /support/conversations/7': () => ok(conversationJson()),
        'GET /support/conversations/8': () => ok(conversationJson(id: 8)),
      });

      sync.watchThread(7);
      sync.watchThread('7');
      sync.watchThread(8);
      sync.unwatchThread(8);
      sync.unwatchThread(7);
      await sync.refresh();

      final controller = MagicStarterSupportController.instance;
      expect(count('GET /support/conversations'), 1);
      expect(count('GET /support/conversations/7'), 1);
      expect(count('GET /support/conversations/8'), 0);
      expect(controller.threadFor(7)!.id, 7);
      expect(controller.conversation, isNull);
    });
  });

  group('markSeenOnce', () {
    test('sends one receipt while in flight and none while seen', () async {
      final receipt = Completer<MagicResponse>();
      var state = conversationJson(hasUnread: true);
      fakeBackend({
        'GET /support/conversations/7': () => ok(state),
        'POST /support/conversations/7/seen': () => receipt.future,
      });
      final controller = MagicStarterSupportController.instance;
      await controller.fetchThread(7);

      final first = sync.markSeenOnce(7);
      final second = sync.markSeenOnce(7);
      receipt.complete(ok(null));

      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(count('POST /support/conversations/7/seen'), 1);
      expect(
        count('GET /support/conversations'),
        1,
        reason: 'the list is reread so its unread dot goes',
      );

      // A reread that still says unread (it raced the receipt) is the same
      // unread state, so no second receipt.
      await controller.fetchThread(7);
      expect(await sync.markSeenOnce(7), isFalse);

      state = conversationJson();
      await controller.fetchThread(7);
      expect(await sync.markSeenOnce(7), isFalse);
      expect(count('POST /support/conversations/7/seen'), 1);

      // A new staff reply is a new unread state.
      state = conversationJson(hasUnread: true, messages: 2);
      await controller.fetchThread(7);
      expect(await sync.markSeenOnce(7), isTrue);
      expect(count('POST /support/conversations/7/seen'), 2);
    });

    test('a thread that is not loaded or not unread sends nothing', () async {
      fakeBackend({
        'GET /support/conversations/8': () => ok(conversationJson(id: 8)),
      });

      expect(await sync.markSeenOnce(7), isFalse);
      await MagicStarterSupportController.instance.fetchThread(8);
      expect(await sync.markSeenOnce(8), isFalse);

      expect(sent.where((s) => s.startsWith('POST')), isEmpty);
    });

    test('a refused receipt is tried again on the next call', () async {
      var refuse = true;
      fakeBackend({
        'GET /support/conversations/7': () =>
            ok(conversationJson(hasUnread: true)),
        'POST /support/conversations/7/seen': () =>
            refuse ? Http.response(<String, dynamic>{}, 500) : ok(null),
      });
      await MagicStarterSupportController.instance.fetchThread(7);

      expect(await sync.markSeenOnce(7), isFalse);
      refuse = false;
      expect(await sync.markSeenOnce(7), isTrue);
      expect(count('POST /support/conversations/7/seen'), 2);
    });
  });

  group('session', () {
    test('resetForSession forgets which unread states were marked', () async {
      fakeBackend({
        'GET /support/conversations/7': () =>
            ok(conversationJson(hasUnread: true)),
        'POST /support/conversations/7/seen': () => ok(null),
      });
      final controller = MagicStarterSupportController.instance;
      await controller.fetchThread(7);
      expect(await sync.markSeenOnce(7), isTrue);

      await sync.resetForSession();
      await controller.fetchThread(7);

      expect(await sync.markSeenOnce(7), isTrue);
      expect(count('POST /support/conversations/7/seen'), 2);
    });

    test('a receipt answered after a reset records nothing', () async {
      final receipt = Completer<MagicResponse>();
      fakeBackend({
        'GET /support/conversations/7': () =>
            ok(conversationJson(hasUnread: true)),
        'POST /support/conversations/7/seen': () => receipt.future,
      });
      final controller = MagicStarterSupportController.instance;
      await controller.fetchThread(7);

      final stale = sync.markSeenOnce(7);
      await pumpEventQueue();
      await sync.resetForSession();
      receipt.complete(ok(null));
      expect(await stale, isFalse);

      fakeBackend({
        'GET /support/conversations/7': () =>
            ok(conversationJson(hasUnread: true)),
        'POST /support/conversations/7/seen': () => ok(null),
      });
      await controller.fetchThread(7);
      expect(await sync.markSeenOnce(7), isTrue);
    });

    testWidgets('resetForSession keeps the poll of a surface still on screen', (
      tester,
    ) async {
      fakeBackend();

      sync.retain();
      await sync.resetForSession();
      await tester.pump(MagicStarterSupportSync.pollInterval);
      await tester.pump();

      expect(ticks, 1, reason: 'a team switch keeps the page live');

      sync.release();
    });

    testWidgets('resetForTesting stops everything', (tester) async {
      final fake = Echo.fake();
      Config.set('broadcasting.default', 'reverb');
      fakeBackend();

      sync.retain();
      sync.watchThread(7);
      await tester.pump();
      fake.assertListening(_channel, _event);

      MagicStarterSupportSync.resetForTesting();

      fake.assertNotListening(_channel, _event);
      await tester.pump(MagicStarterSupportSync.pollInterval);
      await tester.pump();
      expect(ticks, 0);
      expect(sent, isEmpty);
    });
  });
}
