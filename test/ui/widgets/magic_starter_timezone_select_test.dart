import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/widgets/magic_starter_timezone_select.dart';

class MockNetworkDriver implements NetworkDriver {
  final List<MagicResponse> _responses = [];
  final List<String> requestedUrls = [];

  void queueResponse({
    required int statusCode,
    dynamic data,
  }) {
    _responses.add(
      MagicResponse(
        data: data ?? {},
        statusCode: statusCode,
      ),
    );
  }

  MagicResponse _nextResponse() {
    if (_responses.isEmpty) {
      return MagicResponse(
        data: {},
        statusCode: 500,
      );
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
  }) async =>
      _nextResponse();

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _nextResponse();

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      _nextResponse();

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _nextResponse();

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _nextResponse();

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _nextResponse();

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _nextResponse();

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _nextResponse();

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
      _nextResponse();
}

Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    home: WindTheme(
      data: WindThemeData(),
      child: Scaffold(
        body: child,
      ),
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
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [],
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(mockDriver.requestedUrls, isNotEmpty);
      expect(
        mockDriver.requestedUrls.first,
        equals('/timezones?search=&per_page=20'),
      );
    });

    testWidgets('maps API identifier to SelectOption value', (tester) async {
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [
            {
              'identifier': 'Europe/Istanbul',
              'label': 'Istanbul (GMT+3)',
            },
          ],
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(
            value: null,
            onChanged: (_) {},
          ),
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
      mockDriver.queueResponse(
        statusCode: 200,
        data: {
          'data': [],
        },
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MagicStarterTimezoneSelect(
            value: null,
            onChanged: (_) {},
          ),
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
  });
}
