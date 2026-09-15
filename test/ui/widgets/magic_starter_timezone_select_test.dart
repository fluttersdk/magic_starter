import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/widgets/magic_starter_timezone_select.dart';

class MockNetworkDriver implements NetworkDriver {
  final List<MagicResponse> _responses = [];
  final List<String> requestedUrls = [];

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
  });
}
