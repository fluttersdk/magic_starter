import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/widgets/magic_starter_timezone_select.dart';

class MockNetworkDriver implements NetworkDriver {
  final List<MagicResponse> _responses = [];
  final List<String> requestedUrls = [];

  /// One gate per [get], in call order: each request waits on its own before
  /// answering, so a test decides the order responses LAND in.
  ///
  /// A test that needs a request to be genuinely IN FLIGHT across another
  /// interaction cannot get there by pumping: this driver answers on the
  /// microtask after the call, so by the time the test does anything else the
  /// response has already been applied and the window it meant to test never
  /// existed. A queue rather than a single gate, because the narrowest race
  /// here is two requests in flight at once whose responses come back out of
  /// order, which one gate cannot express.
  final List<Completer<void>> gates = [];

  void queueResponse({required int statusCode, dynamic data}) {
    _responses.add(MagicResponse(data: data ?? {}, statusCode: statusCode));
  }

  MagicResponse _nextResponse() {
    if (_responses.isEmpty) {
      return MagicResponse(data: {}, statusCode: 500);
    }

    return _responses.removeAt(0);
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    requestedUrls.add(url);

    if (gates.isNotEmpty) {
      await gates.removeAt(0).future;
    }

    return _nextResponse();
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _nextResponse();

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _nextResponse();

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => _nextResponse();

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async => _nextResponse();

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => _nextResponse();

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => _nextResponse();

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => _nextResponse();

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => _nextResponse();

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async => _nextResponse();
}

Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    home: WindTheme(
      data: WindThemeData(),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MagicStarterTimezoneSelect', () {
    late MockNetworkDriver mockDriver;

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      mockDriver = MockNetworkDriver();
      Magic.singleton('network', () => mockDriver);
      Magic.singleton('log', () => LogManager());
    });

    testWidgets('fetches timezone list with search and per_page parameters', (
      tester,
    ) async {
      mockDriver.queueResponse(statusCode: 200, data: {'data': []});

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(mockDriver.requestedUrls, isNotEmpty);
      expect(
        mockDriver.requestedUrls.first,
        equals('/timezones?search=&per_page=20&page=1'),
      );
    });

    testWidgets('maps API identifier to SelectOption value', (tester) async {
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final select = tester.widget<WFormSelect<String>>(
        find.byType(WFormSelect<String>),
      );

      expect(select.options, hasLength(1));
      expect(select.options.first.value, equals('Europe/Istanbul'));
      expect(select.options.first.label, equals('Istanbul (GMT+3)'));
    });

    testWidgets('handles empty timezone results gracefully', (tester) async {
      mockDriver.queueResponse(statusCode: 200, data: {'data': []});

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final select = tester.widget<WFormSelect<String>>(
        find.byType(WFormSelect<String>),
      );

      expect(select.options, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'debounces search requests — only fires API after 300ms of inactivity',
      (tester) async {
        // 1. Queue enough responses for init + debounced search result.
        mockDriver.queueResponse(statusCode: 200, data: {'data': []});
        mockDriver.queueResponse(
          statusCode: 200,
          data: {
            'data': [
              {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
            ],
          },
        );

        await tester.pumpWidget(
          wrapWithTheme(
            MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
          ),
        );
        await tester.pumpAndSettle();

        // 2. Record URL count after initialization.
        final urlCountAfterInit = mockDriver.requestedUrls.length;

        // 3. Get the onSearch callback from WFormSelect.
        final select = tester.widget<WFormSelect<String>>(
          find.byType(WFormSelect<String>),
        );
        final onSearch = select.onSearch!;

        // 4. Fire multiple rapid searches (simulates typing 'i', 'is', 'ist').
        onSearch('i');
        onSearch('is');
        onSearch('ist');

        // 5. Before 300ms — no new API calls should have fired.
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          mockDriver.requestedUrls.length,
          equals(urlCountAfterInit),
          reason: 'No API call should fire before debounce window expires',
        );

        // 6. After 300ms — only the final search ('ist') should fire.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(
          mockDriver.requestedUrls.length,
          equals(urlCountAfterInit + 1),
          reason: 'Only one API call should fire after debounce',
        );
        expect(
          mockDriver.requestedUrls.last,
          contains('search=ist'),
          reason: 'The debounced call should use the final query',
        );
      },
    );

    testWidgets('reports more pages when the server says there are', (
      tester,
    ) async {
      // Over 400 IANA identifiers exist and the endpoint pages them, so a
      // select that never reports `hasMore` shows the first 20 and hides the
      // rest behind a search box the reader has no reason to think is
      // mandatory. `WSelect` only calls `onLoadMore` when `hasMore` is true.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 22, 'total': 425},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final select = tester.widget<WFormSelect<String>>(
        find.byType(WFormSelect<String>),
      );

      expect(select.hasMore, isTrue);
      expect(select.onLoadMore, isNotNull);
    });

    testWidgets('reports no more pages on the last one', (tester) async {
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
            .hasMore,
        isFalse,
      );
    });

    testWidgets('a response with no meta is treated as the last page', (
      tester,
    ) async {
      // Guessing "there is more" would have the select ask for a page that
      // does not exist every time the reader reaches the bottom.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
            .hasMore,
        isFalse,
      );
    });

    testWidgets('loading more asks for the next page of the same query', (
      tester,
    ) async {
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 3, 'total': 60},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/London', 'label': 'London (GMT+0)'},
          ],
          'meta': {'current_page': 2, 'last_page': 3, 'total': 60},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final more = await tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onLoadMore!();
      await tester.pumpAndSettle();

      expect(
        mockDriver.requestedUrls.last,
        '/timezones?search=&per_page=20&page=2',
      );
      expect(more.single.value, 'Europe/London');
      expect(
        tester
            .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
            .hasMore,
        isTrue,
        reason: 'page 2 of 3 still has a page after it',
      );
    });

    testWidgets('a reopen puts the cursor back to the first page', (
      tester,
    ) async {
      // `WSelect` clears its search and restores `options` every time the menu
      // opens, which this widget cannot see from any other signal. Without the
      // `onOpen` reset the cursor survives it and the next scroll asks for the
      // page AFTER the one the reader can now see: open, pull page two, close,
      // reopen, and page two is unreachable without searching for it.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 3, 'total': 60},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/London', 'label': 'London (GMT+0)'},
          ],
          'meta': {'current_page': 2, 'last_page': 3, 'total': 60},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Paris', 'label': 'Paris (GMT+1)'},
          ],
          'meta': {'current_page': 2, 'last_page': 3, 'total': 60},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final select = tester.widget<WFormSelect<String>>(
        find.byType(WFormSelect<String>),
      );

      await select.onLoadMore!();
      await tester.pumpAndSettle();
      expect(mockDriver.requestedUrls.last, endsWith('page=2'));

      // What the widget sees when the menu is reopened.
      tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onOpen!();
      await tester.pumpAndSettle();

      await tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onLoadMore!();
      await tester.pumpAndSettle();

      expect(
        mockDriver.requestedUrls.last,
        endsWith('page=2'),
        reason: 'the reopened list starts at page one, so the next is two',
      );
    });

    testWidgets('a reopen after a search restores the unfiltered has-more', (
      tester,
    ) async {
      // A search that ended on its last page would otherwise leave the restored
      // full list reporting no more pages, so the reader could scroll the whole
      // unfiltered list and never reach page two again.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 3, 'total': 60},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Pacific/Fiji', 'label': 'Fiji (GMT+12)'},
          ],
          'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Fire and pump rather than await: the search resolves through a
      // debounce timer, so awaiting it before the timer runs deadlocks the
      // test. The existing debounce case does the same.
      tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onSearch!('pacif');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
            .hasMore,
        isFalse,
        reason: 'the search landed on its only page',
      );

      tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onOpen!();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
            .hasMore,
        isTrue,
        reason: 'the unfiltered list still has three pages',
      );
    });

    testWidgets('a reopen recovers from a failed empty-query search', (
      tester,
    ) async {
      // `_fetchTimezones` answers `hasMore: false` on any failure, so typing a
      // character and deleting it fires `onSearch('')`, and if THAT request
      // fails the widget is left saying the unfiltered list has no more pages.
      // A reopen guard that only checks the query and the page returns early on
      // exactly that state, and the reader then scrolls twenty rows to the
      // bottom for the life of the widget with nothing loading.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 3, 'total': 60},
        },
      );
      mockDriver.queueResponse(statusCode: 500, data: {});

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onSearch!('');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
            .hasMore,
        isFalse,
        reason: 'the failed request is what puts the widget in this state',
      );

      tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onOpen!();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
            .hasMore,
        isTrue,
        reason: 'the reopen restores what the unfiltered first page reported',
      );
    });

    testWidgets('a load-more landing after a reopen is discarded', (
      tester,
    ) async {
      // Nothing cancels the request when the menu closes, so a page three in
      // flight across a close and reopen would land on a cursor the reopen has
      // already put back to one, set it to two, and make the next scroll skip
      // page two: the same defect the reopen reset removes, one race later.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 5, 'total': 100},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/London', 'label': 'London (GMT+0)'},
          ],
          'meta': {'current_page': 2, 'last_page': 5, 'total': 100},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Paris', 'label': 'Paris (GMT+1)'},
          ],
          'meta': {'current_page': 3, 'last_page': 5, 'total': 100},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final select = tester.widget<WFormSelect<String>>(
        find.byType(WFormSelect<String>),
      );

      await select.onLoadMore!();
      await tester.pumpAndSettle();

      // Page three goes out, then the menu is reopened before it lands.
      final Future<List<SelectOption<String>>> inFlight = tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onLoadMore!();

      tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onOpen!();
      await tester.pumpAndSettle();

      expect(
        await inFlight,
        isEmpty,
        reason: 'the stale page is dropped rather than appended',
      );

      await tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onLoadMore!();
      await tester.pumpAndSettle();

      expect(
        mockDriver.requestedUrls.last,
        endsWith('page=2'),
        reason: 'the reopened list starts at page one, so the next is two',
      );
    });

    testWidgets('a debounce pending at the reopen is dropped', (tester) async {
      // Type, close the menu inside the 300ms window, reopen. The reset has
      // nothing to undo yet, because the timer has written none of the three
      // fields it reads, so a reset that only looks at state returns and lets
      // the timer fire afterwards: the cursor then names a query whose rows
      // the reader cannot see and whose search box is blank, and the next
      // scroll asks for page two of it.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 5, 'total': 100},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Pacific/Auckland', 'label': 'Auckland (GMT+12)'},
          ],
          'meta': {'current_page': 1, 'last_page': 3, 'total': 50},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final Future<List<SelectOption<String>>> pending = tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onSearch!('pacif');

      // Inside the debounce window, so no request has gone out yet.
      await tester.pump(const Duration(milliseconds: 100));

      tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onOpen!();

      // Past the window the timer would have fired in.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // `WSelect` awaits this behind its own in-flight flag and only lowers
      // that flag for a response whose query still matches, so a dropped
      // search that never answers strands the menu on a spinner.
      expect(
        await pending,
        isNotEmpty,
        reason: 'the superseded search still answers its caller',
      );

      await tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onLoadMore!();
      await tester.pumpAndSettle();

      expect(
        mockDriver.requestedUrls.last,
        contains('search=&'),
        reason: 'the cursor belongs to the unfiltered list the reader sees',
      );
      expect(mockDriver.requestedUrls.last, endsWith('page=2'));
    });

    testWidgets('a search already on the wire at the reopen is dropped', (
      tester,
    ) async {
      // Cancelling the timer covers only the 300ms it is pending. Let it fire,
      // so the request is on the wire, then close and reopen inside the round
      // trip: the reset finds the cursor already at base and returns, and the
      // response writes a query nobody can see onto a menu showing the
      // unfiltered list. The window here is network latency, so it is wider
      // than the one the cancel closes.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 5, 'total': 100},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Pacific/Auckland', 'label': 'Auckland (GMT+12)'},
          ],
          'meta': {'current_page': 1, 'last_page': 3, 'total': 50},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/London', 'label': 'London (GMT+0)'},
          ],
          'meta': {'current_page': 2, 'last_page': 5, 'total': 100},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Held open so the request is genuinely on the wire when the menu
      // reopens. Without it the driver answers on the next microtask, the
      // cursor is already written before `onOpen` fires, and the reset then
      // legitimately clears it: the test would pass against the defect.
      final onTheWire = Completer<void>();
      mockDriver.gates.add(onTheWire);

      tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onSearch!('pacif');

      // Past the debounce, so the request has left.
      await tester.pump(const Duration(milliseconds: 400));

      tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onOpen!();
      await tester.pump();

      onTheWire.complete();
      await tester.pumpAndSettle();

      await tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onLoadMore!();
      await tester.pumpAndSettle();

      expect(
        mockDriver.requestedUrls.last,
        contains('search=&'),
        reason: 'the cursor belongs to the unfiltered list the reader sees',
      );
      expect(mockDriver.requestedUrls.last, endsWith('page=2'));
    });

    testWidgets('a FIRST page in flight at the reopen is dropped too', (
      tester,
    ) async {
      // The corner the page comparison cannot see. It asks whether the page it
      // requested is still the page after the current one, and for a page two
      // requested from page one that is true both before and after a reopen
      // puts the cursor back to one. The reset also early-returns here, since
      // the cursor never left base, so nothing else catches it either: the
      // stale response sets the cursor to two while the reader is looking at
      // page one, and page two becomes unreachable for the life of the menu.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 5, 'total': 100},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/London', 'label': 'London (GMT+0)'},
          ],
          'meta': {'current_page': 2, 'last_page': 5, 'total': 100},
        },
      );
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Paris', 'label': 'Paris (GMT+1)'},
          ],
          'meta': {'current_page': 2, 'last_page': 5, 'total': 100},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Page two goes out from a cursor sitting at page one.
      final Future<List<SelectOption<String>>> inFlight = tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onLoadMore!();

      tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onOpen!();
      await tester.pumpAndSettle();

      expect(
        await inFlight,
        isEmpty,
        reason: 'the stale first page is dropped rather than appended',
      );

      await tester
          .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
          .onLoadMore!();
      await tester.pumpAndSettle();

      expect(
        mockDriver.requestedUrls.last,
        endsWith('page=2'),
        reason: 'the reader is still on page one, so the next ask is page two',
      );
    });

    testWidgets('the cursor follows the newest search, not the last to land', (
      tester,
    ) async {
      // The one race an epoch cannot see, because both requests belong to the
      // same one. Cancelling covers only a PENDING timer, so typing past the
      // debounce twice puts two searches on the wire at once, and the cursor
      // was written by whichever landed last rather than whichever was asked
      // for last. WSelect is right here and this side was wrong: it drops the
      // older response on its own query mismatch, so the visible list stays
      // the newer query's while the cursor names the older one, and the
      // asymmetry only shows on the next scroll.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 5, 'total': 100},
        },
      );
      for (var i = 0; i < 3; i++) {
        mockDriver.queueResponse(
          statusCode: 200,
          data: {
            'data': [
              {'identifier': 'Pacific/Auckland', 'label': 'Auckland (GMT+12)'},
            ],
            'meta': {'current_page': 1, 'last_page': 3, 'total': 50},
          },
        );
      }

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final older = Completer<void>();
      final newer = Completer<void>();
      mockDriver.gates.addAll([older, newer]);

      WFormSelect<String> select() =>
          tester.widget<WFormSelect<String>>(find.byType(WFormSelect<String>));

      // Both go out: the first is past its debounce before the second is typed.
      select().onSearch!('pacif');
      await tester.pump(const Duration(milliseconds: 400));
      select().onSearch!('pacifi');
      await tester.pump(const Duration(milliseconds: 400));

      // They come back the other way round, which is the whole trigger.
      newer.complete();
      await tester.pump();
      older.complete();
      await tester.pumpAndSettle();

      await select().onLoadMore!();
      await tester.pumpAndSettle();

      expect(
        mockDriver.requestedUrls.last,
        contains('search=pacifi&'),
        reason: 'the older response wrote its query over the newer cursor',
      );
    });

    testWidgets('a failed page does not end pagination for the menu', (
      tester,
    ) async {
      // `_fetchTimezones` answers `hasMore: false` on any failure, and the
      // load-more path wrote that into `_hasMore` unconditionally, so ONE
      // dropped request ended pagination for the life of the open menu: the
      // reader scrolls to the bottom and nothing more ever loads until they
      // close and reopen, which they have no reason to try. This is the same
      // trap the search path already guards with `_baseHasMore`, on the site
      // that did not get the guard.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'current_page': 1, 'last_page': 5, 'total': 100},
        },
      );
      // The dropped one.
      mockDriver.queueResponse(statusCode: 500);
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/London', 'label': 'London (GMT+0)'},
          ],
          'meta': {'current_page': 2, 'last_page': 5, 'total': 100},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      WFormSelect<String> select() =>
          tester.widget<WFormSelect<String>>(find.byType(WFormSelect<String>));

      await select().onLoadMore!();
      await tester.pumpAndSettle();

      expect(
        select().hasMore,
        isTrue,
        reason: 'one dropped request must not end the list',
      );

      // And the retry works rather than merely being offered.
      await select().onLoadMore!();
      await tester.pumpAndSettle();

      expect(mockDriver.requestedUrls.last, endsWith('page=2'));
    });

    testWidgets('a cursor response is paged through links.next', (
      tester,
    ) async {
      // `last_page` is a `LengthAwarePaginator` field. A `SimplePaginator` or a
      // cursor paginator sends a `meta` without it, and reading only that key
      // answered "no more" on page one and reverted this widget to the
      // single-page behaviour it exists to fix, with nothing anywhere saying
      // so. The endpoint is length-aware today, so this is about the shape
      // changing rather than about the shape now.
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {'identifier': 'Europe/Istanbul', 'label': 'Istanbul (GMT+3)'},
          ],
          'meta': {'per_page': 20},
          'links': {'next': 'https://example.test/timezones?page=2'},
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(value: null, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<WFormSelect<String>>(find.byType(WFormSelect<String>))
            .hasMore,
        isTrue,
        reason: 'a next link is a next page, whatever the meta calls it',
      );
    });
  });
}
