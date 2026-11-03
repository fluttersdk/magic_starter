import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Stands in for what an app's facade driver carries: an interceptor that
/// writes the open session's bearer, the way magic's `AuthInterceptor` does,
/// and records every request it sees, the way a devtools recorder does.
class _SessionInterceptor extends MagicNetworkInterceptor {
  final List<String> seen = [];

  @override
  dynamic onRequest(MagicRequest request) {
    seen.add(request.url);
    request.headers['Authorization'] = 'Bearer open-session-token';

    return request;
  }
}

/// Real sockets to a loopback server, so this file never initialises the test
/// binding: its `HttpClient` override answers every request with a canned 400.
void main() {
  late HttpServer api;
  late List<HttpHeaders> received;

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    setUpMagicStarterForTests();
    Log.fake();
    Auth.fake(user: MagicStarter.createUser({'id': 'user-bob', 'name': 'Bob'}));

    received = [];
    api = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    api.listen((HttpRequest request) async {
      received.add(request.headers);
      await utf8.decoder.bind(request).join();
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'data': {
              'token': '42|handed',
              'user': {'id': 'user-ada', 'name': 'Ada'},
            },
          }),
        );
      await request.response.close();
    });
  });

  tearDown(() async {
    await api.close(force: true);
    Auth.unfake();
    Log.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  test('copies the facade driver and leaves its interceptors behind', () async {
    // 1. The facade driver an app boots with: its origin, timeout and default
    //    headers, the User-Agent included, plus the app's interceptors.
    final DioNetworkDriver facade = DioNetworkDriver(
      baseUrl: 'http://${api.address.address}:${api.port}',
      timeout: 5000,
      defaultHeaders: {
        'Accept': 'application/json',
        'User-Agent': 'Acme (Flutter; iOS)',
      },
    );
    final _SessionInterceptor interceptor = _SessionInterceptor();
    facade.addInterceptor(interceptor);
    Magic.singleton('network', () => facade);

    // 2. The exchange, from a controller on its default driver.
    final MagicStarterHandoffController controller =
        MagicStarterHandoffController();
    await controller.handOff(code: 'hnd_code');

    // 3. It reached the facade's origin with its headers, and nothing the
    //    interceptors add.
    expect(received, hasLength(1));
    expect(received.single.value('user-agent'), 'Acme (Flutter; iOS)');
    expect(received.single.value('accept'), 'application/json');
    expect(received.single.value('authorization'), isNull);
    expect(interceptor.seen, isEmpty);
    expect(controller.isConfirming, isTrue);
  });
}
