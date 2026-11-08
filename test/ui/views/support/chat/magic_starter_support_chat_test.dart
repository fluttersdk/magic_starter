import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// The fixtures and the fake backend are the views test's own, so a payload
// the panel reads is the payload the pages read.
import '../magic_starter_support_views_test.dart'
    show
        SentRequest,
        conversationJson,
        count,
        fakeBackend,
        lastMessageJson,
        messageJson,
        ok,
        pageJson;

class _ShippedLoader implements TranslationLoader {
  const _ShippedLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final File stub = File(
      '${Directory.current.path}/assets/stubs/install/en.stub',
    );

    return _flatten(
      jsonDecode(stub.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final Map<String, dynamic> result = <String, dynamic>{};

    for (final MapEntry<String, dynamic> entry in json.entries) {
      final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';

      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }

    return result;
  }
}

const ValueKey<String> _launcher = ValueKey<String>('support-chat-launcher');
const ValueKey<String> _unread = ValueKey<String>('support-chat-unread');
const ValueKey<String> _panel = ValueKey<String>('support-chat-panel');
const ValueKey<String> _back = ValueKey<String>('support-chat-back');
const ValueKey<String> _close = ValueKey<String>('support-chat-close');
const ValueKey<String> _fullPage = ValueKey<String>('support-chat-full-page');
const ValueKey<String> _newConversation = ValueKey<String>('support-chat-new');
const ValueKey<String> _outside = ValueKey<String>('page-outside');
const ValueKey<String> _send = ValueKey<String>('support-send');

const String _list = '/support/conversations';

ValueKey<String> _row(int id) => ValueKey<String>('support-chat-row-$id');

MagicResponse _page(List<Map<String, dynamic>> rows) =>
    Http.response(pageJson(rows, page: 1, lastPage: 1));

Map<String, dynamic> _row7() => conversationJson(
  id: 7,
  subject: 'Cannot add a monitor',
  hasUnread: true,
  lastMessage: lastMessageJson(bodyPreview: 'On it'),
);

Map<String, dynamic> _row8() => conversationJson(
  id: 8,
  subject: 'Invoice address',
  status: 'resolved',
  lastMessage: lastMessageJson(bodyPreview: 'Fixed'),
);

Map<String, dynamic> _thread(int id, String line) => conversationJson(
  id: id,
  subject: 'Thread $id',
  messages: <Map<String, dynamic>>[messageJson(id: id * 10, body: line)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MagicStarterSupportController controller;

  /// How often the page around the launcher was tapped.
  late int outsideTaps;

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    MagicStarterSupportSync.resetForTesting();
    MagicStarterSupportChatState.resetForTesting();

    Magic.singleton('log', () => LogManager());
    Config.set('logging', <String, dynamic>{
      'default': 'console',
      'channels': <String, dynamic>{
        'console': <String, dynamic>{'driver': 'console', 'level': 'debug'},
      },
    });

    Config.set('magic_starter.features.support', true);
    Config.set('magic_starter.features.support_chat', true);
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Auth.fake(
      user: MagicStarterAuthUser.fromMap(<String, dynamic>{
        'id': 5,
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
      }),
    );

    Translator.instance.setLoader(const _ShippedLoader());
    await Translator.instance.setLocale(const Locale('en'));

    controller = Magic.put(MagicStarterSupportController());
    outsideTaps = 0;
  });

  tearDown(() {
    MagicStarterSupportSync.resetForTesting();
    MagicStarterSupportChatState.resetForTesting();
    Config.set('magic_starter.features.support_chat', false);
    Auth.unfake();
    Http.unfake();
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  /// Mounts a page with the launcher at its bottom left, the way a sidebar
  /// holds it (or at its bottom right with [launcherAtRight]), and a button of
  /// the page's own far from the panel.
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
    bool launcherAtRight = false,
    double? margin,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    MagicRoute.page(
      '/',
      () => Scaffold(
        body: Stack(
          children: [
            Positioned(
              right: 16,
              top: 16,
              child: TextButton(
                key: _outside,
                onPressed: () => outsideTaps++,
                child: const Text('Outside'),
              ),
            ),
            Positioned(
              left: launcherAtRight ? null : 0,
              right: launcherAtRight ? 0 : null,
              bottom: 0,
              child: SizedBox(
                width: 200,
                child: margin != null
                    ? MagicStarterSupportChatLauncher(margin: margin)
                    : MagicStarter.view.has('support.chat')
                    ? MagicStarter.view.make('support.chat')
                    : const MagicStarterSupportChatLauncher(),
              ),
            ),
          ],
        ),
      ),
    );
    MagicRoute.page(
      MagicStarterConfig.supportRoute(),
      () => const Scaffold(body: Text('The full support page')),
    );
    MagicRouter.instance.setInitialLocation('/');

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: MagicRouter.instance.routerConfig,
        builder: (context, child) =>
            WindTheme(data: WindThemeData(), child: child!),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(_launcher));
    await tester.pumpAndSettle();
  }

  /// Lets one 30 second poll tick fire and its reads answer.
  Future<void> elapsePoll(WidgetTester tester) async {
    await tester.pump(MagicStarterSupportSync.pollInterval);
    await tester.pumpAndSettle();
  }

  group('the launcher gate', () {
    testWidgets('renders nothing and reads nothing with support_chat off', (
      tester,
    ) async {
      Config.set('magic_starter.features.support_chat', false);
      final List<SentRequest> sent = fakeBackend({});

      await mount(tester);

      expect(find.byKey(_launcher), findsNothing);
      expect(sent, isEmpty);
      expect(MagicStarter.view.has('support.chat'), isFalse);
      expect(MagicStarter.view.has('support.chat_panel'), isFalse);
    });

    testWidgets('does not need Auth bound while support_chat is off', (
      tester,
    ) async {
      Config.set('magic_starter.features.support_chat', false);
      Auth.unfake();
      Magic.flush();
      final List<SentRequest> sent = fakeBackend({});

      await mount(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(_launcher), findsNothing);
      expect(sent, isEmpty);
    });

    testWidgets(
      'renders nothing with support off, whatever support_chat says',
      (tester) async {
        Config.set('magic_starter.features.support', false);
        final List<SentRequest> sent = fakeBackend({});

        await mount(tester);

        expect(MagicStarterConfig.hasSupportChatFeatures(), isFalse);
        expect(find.byKey(_launcher), findsNothing);
        expect(sent, isEmpty);
      },
    );

    testWidgets('renders nothing for a signed-out visitor', (tester) async {
      Auth.fake();
      final List<SentRequest> sent = fakeBackend({});

      await mount(tester);

      expect(find.byKey(_launcher), findsNothing);
      expect(sent, isEmpty);
    });

    testWidgets('renders nothing for a guest', (tester) async {
      Auth.fake(
        user: MagicStarterAuthUser.fromMap(<String, dynamic>{
          'id': 6,
          'name': 'Guest',
          'is_guest': true,
        }),
      );
      final List<SentRequest> sent = fakeBackend({});

      await mount(tester);

      expect(find.byKey(_launcher), findsNothing);
      expect(sent, isEmpty);
    });

    testWidgets('registers both views and resolves the launcher through them', (
      tester,
    ) async {
      fakeBackend({'GET $_list': (_) => _page(<Map<String, dynamic>>[])});

      await mount(tester);

      expect(
        MagicStarter.view.make('support.chat'),
        isA<MagicStarterSupportChatLauncher>(),
      );
      expect(
        MagicStarter.view.make('support.chat_panel'),
        isA<MagicStarterSupportChatPanel>(),
      );
      expect(find.byKey(_launcher), findsOneWidget);
    });
  });

  group('the launcher', () {
    testWidgets('counts the unread conversations and reads the list once '
        'while closed', (tester) async {
      final List<SentRequest> sent = fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[
          _row7(),
          conversationJson(id: 9, hasUnread: true),
          _row8(),
        ]),
      });

      await mount(tester);

      expect(
        find.descendant(of: find.byKey(_unread), matching: find.text('2')),
        findsOneWidget,
      );
      expect(count(sent, 'GET', _list), 1);

      await elapsePoll(tester);

      expect(
        count(sent, 'GET', _list),
        1,
        reason: 'a closed launcher holds no poll',
      );
    });

    testWidgets('shows no badge when nothing is unread', (tester) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row8()]),
      });

      await mount(tester);

      expect(find.byKey(_unread), findsNothing);
    });

    testWidgets('a tap opens the panel and Escape closes it, focus back on '
        'the launcher', (tester) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
      });
      final SemanticsHandle semantics = tester.ensureSemantics();
      await mount(tester);

      await openPanel(tester);

      expect(find.byKey(_panel), findsOneWidget);
      expect(MagicStarterSupportChatState.instance.isOpen, isTrue);
      expect(
        tester.getSemantics(
          find
              .ancestor(
                of: find.byKey(_panel),
                matching: find.byType(Semantics),
              )
              .first,
        ),
        isSemantics(
          label: trans('magic_starter.support.index_title'),
          isHeader: false,
        ),
      );
      semantics.dispose();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(_panel), findsNothing);
      expect(MagicStarterSupportChatState.instance.isOpen, isFalse);
      final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
      expect(
        focused
            ?.findAncestorWidgetOfExactType<MagicStarterSupportChatLauncher>(),
        isNotNull,
        reason: 'closing hands focus back to the launcher',
      );
    });

    testWidgets('a tap outside leaves the panel open and reaches the page', (
      tester,
    ) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
      });
      await mount(tester);
      await openPanel(tester);

      await tester.tap(find.byKey(_outside));
      await tester.pumpAndSettle();

      expect(outsideTaps, 1, reason: 'the page stays interactive');
      expect(find.byKey(_panel), findsOneWidget);
    });

    testWidgets('the close control closes it', (tester) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
      });
      await mount(tester);
      await openPanel(tester);

      await tester.tap(find.byKey(_close));
      await tester.pumpAndSettle();

      expect(find.byKey(_panel), findsNothing);
    });

    testWidgets('signing out closes the panel and hides the launcher', (
      tester,
    ) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
      });
      await mount(tester);
      await openPanel(tester);

      await Auth.logout();
      await tester.pumpAndSettle();

      expect(find.byKey(_panel), findsNothing);
      expect(find.byKey(_launcher), findsNothing);
      expect(MagicStarterSupportChatState.instance.isOpen, isFalse);
    });

    testWidgets('open full page goes to the support route and closes', (
      tester,
    ) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
      });
      await mount(tester);
      await openPanel(tester);

      await tester.tap(find.byKey(_fullPage));
      await tester.pumpAndSettle();

      expect(find.text('The full support page'), findsOneWidget);
      expect(MagicStarterSupportChatState.instance.isOpen, isFalse);
      expect(find.byKey(_panel), findsNothing);
    });
  });

  group('the panel modes', () {
    testWidgets('lists the conversations with their preview and status', (
      tester,
    ) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7(), _row8()]),
      });
      await mount(tester);
      await openPanel(tester);

      final Finder panel = find.byKey(_panel);
      expect(
        find.descendant(of: panel, matching: find.text('Cannot add a monitor')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('Ayse: On it')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_row(8)),
          matching: find.text(trans('magic_starter.support.status.resolved')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_row(7)),
          matching: find.byKey(const ValueKey<String>('support-unread-7')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(_newConversation), findsOneWidget);
    });

    testWidgets('an empty list opens the create form at once', (tester) async {
      fakeBackend({'GET $_list': (_) => _page(<Map<String, dynamic>>[])});
      await mount(tester);

      await openPanel(tester);

      expect(
        MagicStarterSupportChatState.instance.mode,
        MagicStarterSupportChatMode.create,
      );
      expect(
        find.descendant(
          of: find.byKey(_panel),
          matching: find.byType(MagicStarterSupportCreateForm),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a created conversation opens as the thread', (tester) async {
      final List<SentRequest> sent = fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[]),
        'POST $_list': (_) => ok(conversationJson(id: 12)),
        'GET $_list/12': (_) => ok(_thread(12, 'Our AI is on it')),
      });
      await mount(tester);
      await openPanel(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(_panel),
          matching: find.byType(EditableText),
        ),
        'The monitor form will not save',
      );
      await tester.pump();
      await tester.tap(find.text(trans('magic_starter.support.create_submit')));
      await tester.pumpAndSettle();

      expect(count(sent, 'POST', _list), 1);
      expect(MagicStarterSupportChatState.instance.activeThreadId, 12);
      expect(
        MagicStarterSupportChatState.instance.mode,
        MagicStarterSupportChatMode.thread,
      );
      expect(find.byType(MagicStarterSupportThreadBody), findsOneWidget);
      expect(find.text('Our AI is on it'), findsOneWidget);
    });

    testWidgets('a row opens its thread and back returns to the list', (
      tester,
    ) async {
      final List<SentRequest> sent = fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7(), _row8()]),
        'GET $_list/7': (_) => ok(_thread(7, 'Thread seven line')),
      });
      await mount(tester);
      await openPanel(tester);

      await tester.tap(find.byKey(_row(7)));
      await tester.pumpAndSettle();

      expect(find.text('Thread seven line'), findsOneWidget);
      expect(count(sent, 'GET', '$_list/7'), 1);

      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();

      expect(
        MagicStarterSupportChatState.instance.mode,
        MagicStarterSupportChatMode.list,
      );
      expect(find.byKey(_row(7)), findsOneWidget);
      expect(find.text('Thread seven line'), findsNothing);
    });

    testWidgets('a thread the backend answers 404 for says not found and '
        'goes back', (tester) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
      });
      await mount(tester);
      await openPanel(tester);

      await tester.tap(find.byKey(_row(7)));
      await tester.pumpAndSettle();

      expect(
        find.text(trans('magic_starter.support.not_found_title')),
        findsOneWidget,
      );

      await tester.tap(find.text(trans('magic_starter.support.back_to_list')));
      await tester.pumpAndSettle();

      expect(find.byKey(_row(7)), findsOneWidget);
    });

    testWidgets('an open thread is marked seen once', (tester) async {
      final List<SentRequest> sent = fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
        'GET $_list/7': (_) => ok(
          conversationJson(
            id: 7,
            hasUnread: true,
            messages: <Map<String, dynamic>>[messageJson(id: 1)],
          ),
        ),
        'POST $_list/7/seen': (_) => ok(null),
      });
      await mount(tester);
      await openPanel(tester);

      await tester.tap(find.byKey(_row(7)));
      await tester.pumpAndSettle();

      expect(count(sent, 'POST', '$_list/7/seen'), 1);
    });
  });

  group('the panel and the page together', () {
    testWidgets('the panel holds the shared sync while open, once', (
      tester,
    ) async {
      final List<SentRequest> sent = fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
      });
      final MagicStarterSupportSync sync = MagicStarterSupportSync.instance;
      await mount(tester);

      // 1. Open alone: the panel's retain starts the poll.
      await openPanel(tester);
      final int opened = count(sent, 'GET', _list);
      await elapsePoll(tester);
      expect(count(sent, 'GET', _list), opened + 1);

      // 2. A page retains alongside; closing the panel must leave the page's
      // poll running, which a second release would stop.
      sync.retain();
      await tester.tap(find.byKey(_close));
      await tester.pumpAndSettle();
      final int closed = count(sent, 'GET', _list);
      await elapsePoll(tester);
      expect(count(sent, 'GET', _list), closed + 1);

      // 3. The page leaves: nothing may still hold the poll, which a second
      // retain by the panel would.
      sync.release();
      final int released = count(sent, 'GET', _list);
      await elapsePoll(tester);
      expect(count(sent, 'GET', _list), released);
    });

    testWidgets('the panel on thread A leaves the page on thread B', (
      tester,
    ) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7(), _row8()]),
        'GET $_list/7': (_) => ok(_thread(7, 'Thread seven line')),
        'GET $_list/8': (_) => ok(_thread(8, 'Thread eight line')),
      });
      await controller.loadConversation(8);
      await mount(tester);
      await openPanel(tester);

      await tester.tap(find.byKey(_row(7)));
      await tester.pumpAndSettle();

      expect(find.text('Thread seven line'), findsOneWidget);
      expect(controller.conversation!.id, 8);
      expect(
        controller.conversation!.messages.single.body,
        'Thread eight line',
      );
    });

    testWidgets('a panel reply goes out while a page write is in flight', (
      tester,
    ) async {
      final Completer<MagicResponse> pageWrite = Completer<MagicResponse>();
      final List<String> posts = <String>[];
      Http.fake((MagicRequest request) {
        if (request.method == 'POST') {
          posts.add(request.url);
          if (request.url == '$_list/8/rating') return pageWrite.future;

          return Future<MagicResponse>.value(ok(messageJson(id: 99)));
        }
        if (request.url == '$_list/7') {
          return Future<MagicResponse>.value(ok(_thread(7, 'Seven')));
        }

        return Future<MagicResponse>.value(
          _page(<Map<String, dynamic>>[_row7(), _row8()]),
        );
      });
      await mount(tester);
      await openPanel(tester);
      await tester.tap(find.byKey(_row(7)));
      await tester.pumpAndSettle();

      unawaited(controller.rate(8, 'up'));
      await tester.pump();
      expect(controller.isSubmittingFor('page'), isTrue);

      await tester.enterText(
        find.descendant(
          of: find.byKey(_panel),
          matching: find.byType(EditableText),
        ),
        'Still there?',
      );
      await tester.pump();
      await tester.tap(find.byKey(_send));
      await tester.pump();
      await tester.pump();

      expect(posts, contains('$_list/7/messages'));

      pageWrite.complete(Http.response(<String, dynamic>{}));
      await tester.pumpAndSettle();
    });

    testWidgets('disposing the launcher with the panel open lets go of the '
        'sync, and a remount reopens the panel', (tester) async {
      final List<SentRequest> sent = fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
      });
      await mount(tester);
      await openPanel(tester);
      expect(find.byKey(_panel), findsOneWidget);

      // 1. The tree goes away with the chat still open.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(_panel), findsNothing);
      expect(MagicStarterSupportChatState.instance.isOpen, isTrue);
      final int disposed = count(sent, 'GET', _list);
      await elapsePoll(tester);
      expect(count(sent, 'GET', _list), disposed, reason: 'the poll stopped');

      // 2. A launcher mounted again finds the chat open and shows the panel.
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              WindTheme(data: WindThemeData(), child: child!),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: 200,
                child: MagicStarterSupportChatLauncher(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(_panel), findsOneWidget);
      final int remounted = count(sent, 'GET', _list);
      await elapsePoll(tester);
      expect(count(sent, 'GET', _list), remounted + 1);
    });

    testWidgets('resetForSession closes the panel and lets go of the sync', (
      tester,
    ) async {
      final List<SentRequest> sent = fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
        'GET $_list/7': (_) => ok(_thread(7, 'Seven')),
      });
      await mount(tester);
      await openPanel(tester);
      await tester.tap(find.byKey(_row(7)));
      await tester.pumpAndSettle();

      await MagicStarterSupportChatState.instance.resetForSession();
      await tester.pumpAndSettle();

      final MagicStarterSupportChatState state =
          MagicStarterSupportChatState.instance;
      expect(find.byKey(_panel), findsNothing);
      expect(state.isOpen, isFalse);
      expect(state.mode, MagicStarterSupportChatMode.list);
      expect(state.activeThreadId, isNull);

      final int before = count(sent, 'GET', _list);
      await elapsePoll(tester);
      expect(count(sent, 'GET', _list), before);
    });
  });

  group('the panel geometry', () {
    testWidgets('is 400 by 520 in the bottom right corner of a desktop', (
      tester,
    ) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7(), _row8()]),
      });
      await mount(tester);
      await openPanel(tester);

      final Rect panel = tester.getRect(find.byKey(_panel));
      expect(panel.size, const Size(400, 520));
      expect(panel.right, 1440 - 16);
      expect(panel.bottom, 900 - 16);
      expect(tester.takeException(), isNull);
    });

    for (final bool launcherAtRight in const <bool>[false, true]) {
      testWidgets('stays in the corner with the launcher at the '
          '${launcherAtRight ? 'right' : 'left'} edge', (tester) async {
        fakeBackend({
          'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7(), _row8()]),
        });
        await mount(tester, launcherAtRight: launcherAtRight);
        await openPanel(tester);

        final Rect panel = tester.getRect(find.byKey(_panel));
        expect(panel.size, const Size(400, 520));
        expect(panel.right, 1440 - 16);
        expect(panel.bottom, 900 - 16);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('honours a custom margin', (tester) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7(), _row8()]),
      });
      await mount(tester, margin: 24);
      await openPanel(tester);

      final Rect panel = tester.getRect(find.byKey(_panel));
      expect(panel.size, const Size(400, 520));
      expect(panel.right, 1440 - 24);
      expect(panel.bottom, 900 - 24);
      expect(tester.takeException(), isNull);
    });

    for (final Size size in const <Size>[Size(1440, 900), Size(360, 640)]) {
      testWidgets('lays out every mode without overflow at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        fakeBackend({
          'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7(), _row8()]),
          'GET $_list/7': (_) => ok(_thread(7, 'Seven')),
        });
        await mount(tester, size: size);
        await openPanel(tester);
        expect(tester.takeException(), isNull);

        final Rect list = tester.getRect(find.byKey(_panel));
        expect(list.left, greaterThanOrEqualTo(0));
        expect(list.top, greaterThanOrEqualTo(0));
        expect(list.right, lessThanOrEqualTo(size.width));
        expect(list.bottom, lessThanOrEqualTo(size.height));

        await tester.tap(find.byKey(_row(7)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(_back));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_newConversation));
        await tester.pumpAndSettle();
        expect(find.byType(MagicStarterSupportCreateForm), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'keeps Send pinned in the create form while the fields scroll',
      (tester) async {
        fakeBackend({
          'GET $_list': (_) => _page(<Map<String, dynamic>>[]),
          'GET /support/articles': (_) => ok(<Map<String, dynamic>>[
            for (final String slug in <String>['a', 'b', 'c'])
              <String, dynamic>{
                'id': slug,
                'slug': slug,
                'question': 'Question $slug',
                'excerpt': 'Excerpt $slug',
                'url': null,
              },
          ]),
        });
        await mount(tester);
        await openPanel(tester);

        final Finder panel = find.byKey(_panel);
        await tester.enterText(
          find.descendant(of: panel, matching: find.byType(EditableText)),
          'My monitor will not save',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        final Finder send = find.ancestor(
          of: find.text(trans('magic_starter.support.create_submit')),
          matching: find.byType(MSButton),
        );
        final Finder chip = find.byKey(
          ValueKey<String>(
            'support-topic-${MagicStarterConfig.supportTopics().first}',
          ),
        );
        expect(
          find.byKey(const ValueKey<String>('support-article-c')),
          findsOneWidget,
        );

        final Rect box = tester.getRect(panel);
        final Rect button = tester.getRect(send);
        expect(box.size, const Size(400, 520));
        expect(button.top, greaterThanOrEqualTo(box.top));
        expect(button.bottom, lessThanOrEqualTo(box.bottom));

        final Rect chipBefore = tester.getRect(chip);
        await tester.drag(
          find.descendant(
            of: panel,
            matching: find.byType(SingleChildScrollView),
          ),
          const Offset(0, -300),
        );
        await tester.pump();

        expect(tester.getRect(chip).top, lessThan(chipBefore.top));
        expect(tester.getRect(send), button);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shrinks above the keyboard on a phone', (tester) async {
      fakeBackend({
        'GET $_list': (_) => _page(<Map<String, dynamic>>[_row7()]),
        'GET $_list/7': (_) => ok(_thread(7, 'Seven')),
      });
      await mount(tester, size: const Size(360, 640));
      await openPanel(tester);
      await tester.tap(find.byKey(_row(7)));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(_panel)).height, 520);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final Rect panel = tester.getRect(find.byKey(_panel));
      expect(panel.height, lessThan(520));
      expect(panel.top, greaterThanOrEqualTo(0));
      expect(panel.bottom, lessThanOrEqualTo(640 - 300));
      expect(tester.takeException(), isNull);
    });
  });
}
