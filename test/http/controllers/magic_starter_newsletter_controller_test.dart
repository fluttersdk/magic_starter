import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver — intercepts all Http facade calls
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;

  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

  void mockResponse({
    required int statusCode,
    dynamic data,
  }) {
    nextResponse = MagicResponse(
      data: data ?? {},
      statusCode: statusCode,
    );
  }

  MagicResponse _respond(String method, String url, {dynamic data}) {
    lastMethod = method;
    lastUrl = url;
    lastData = data;
    return nextResponse ?? MagicResponse(data: {}, statusCode: 500);
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async =>
      _respond('GET', url);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _respond('INDEX', resource);

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
      _respond('UPLOAD', url, data: data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MagicStarterNewsletterController', () {
    late MockNetworkDriver mockDriver;
    late MagicStarterNewsletterController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      Magic.singleton('network', () => MockNetworkDriver());
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      Magic.singleton('magic_starter', () => MagicStarterManager());

      controller = MagicStarterNewsletterController.instance;
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    });

    tearDown(() {
      controller.dispose();
    });

    test('getNewsletterStatus — calls GET /user/newsletter', () async {
      mockDriver.mockResponse(statusCode: 200, data: {
        'subscribed': true,
        'source': 'register',
        'subscribed_at': '2025-01-01'
      });
      await controller.getNewsletterStatus();
      expect(mockDriver.lastUrl, '/user/newsletter');
      expect(mockDriver.lastMethod, 'GET');
      expect(controller.isSuccess, isTrue);
    });

    test(
        'updateNewsletterSubscription — subscribe: calls PUT with correct payload',
        () async {
      mockDriver.mockResponse(statusCode: 200, data: {'subscribed': true});
      await controller.updateNewsletterSubscription(subscribe: true);
      expect(mockDriver.lastUrl, '/user/newsletter');
      expect(mockDriver.lastMethod, 'PUT');
      expect(mockDriver.lastData?['subscribe'], isTrue);
    });

    test('updateNewsletterSubscription — unsubscribe: sends false', () async {
      mockDriver.mockResponse(statusCode: 200, data: {'subscribed': false});
      await controller.updateNewsletterSubscription(subscribe: false);
      expect(mockDriver.lastData?['subscribe'], isFalse);
    });

    test('getNewsletterStatus — API error: sets error state', () async {
      mockDriver.mockResponse(statusCode: 500, data: {'message': 'error'});
      await controller.getNewsletterStatus();
      expect(controller.isError, isTrue);
    });
  });
}
