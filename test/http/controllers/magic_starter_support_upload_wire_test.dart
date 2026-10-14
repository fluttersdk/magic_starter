import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// What the loopback server saw of one request.
class _Received {
  final String path;
  final String contentType;

  /// The multipart body decoded byte for byte as latin1, so a part header and
  /// its filename can be matched as text while the payload stays untouched.
  final String body;

  const _Received(this.path, this.contentType, this.body);
}

/// Pins the multipart shape on the real wire.
///
/// `Http.fake` merges `files` into `data` (fake_network_driver.dart), so a fake
/// cannot tell one part per key from anything else. This drives the real
/// [DioNetworkDriver] against a loopback [HttpServer] and reads what arrives.
void main() {
  late HttpServer server;
  late MagicStarterSupportController controller;
  late List<_Received> received;

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    setUpMagicStarterForTests();

    received = <_Received>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest request) async {
      final BytesBuilder bytes = BytesBuilder();
      await request.forEach(bytes.add);

      received.add(
        _Received(
          request.uri.path,
          request.headers.contentType?.toString() ?? '',
          latin1.decode(bytes.takeBytes()),
        ),
      );

      request.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'id': 7,
              'number': 107,
              'subject': 'Cannot add a monitor',
              'source': 'in_app',
              'status': 'open',
              'priority': 'normal',
              'last_activity_at': null,
              'created_at': '2026-10-12T09:00:00+00:00',
              'has_unread': false,
            },
          }),
        );
      await request.response.close();
    });

    Magic.app.setInstance(
      'network',
      DioNetworkDriver(baseUrl: 'http://127.0.0.1:${server.port}'),
    );

    controller = MagicStarterSupportController();
  });

  tearDown(() async {
    controller.dispose();
    Http.unfake();
    await server.close(force: true);
    MagicApp.reset();
    Magic.flush();
  });

  MagicFile file(String name, String mimeType, String content) {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(content));

    return MagicFile(
      name: name,
      size: bytes.length,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  /// The header block of the part named [field], or null when it is absent.
  String? partHeader(String body, String field) {
    final RegExp header = RegExp(
      'content-disposition: form-data; name="${RegExp.escape(field)}"'
      '[^\\r]*\\r\\n(?:[^\\r\\n]+\\r\\n)*',
      caseSensitive: false,
    );

    return header.firstMatch(body)?.group(0);
  }

  test('createConversation sends one part per file on the real wire', () async {
    final MagicStarterSupportConversation? created = await controller
        .createConversation(
          body: 'See the attachments',
          source: 'in_app',
          attachments: <MagicFile>[
            file('error.png', 'image/png', 'PNGDATA'),
            file('invoice.pdf', 'application/pdf', 'PDFDATA'),
          ],
          screenshot: file('screenshot.png', 'image/png', 'SHOTDATA'),
          clientContext: <String, String>{
            'route': '/monitors',
            'app_version': '1.4.0',
          },
        );

    expect(created, isNotNull);
    expect(received, hasLength(1));

    final _Received request = received.single;
    expect(request.path, '/support/conversations');
    expect(request.contentType, startsWith('multipart/form-data'));

    final String? first = partHeader(request.body, 'attachments[0]');
    expect(first, isNotNull, reason: 'attachments[0] part is missing');
    expect(first, contains('filename="error.png"'));
    expect(first!.toLowerCase(), contains('content-type: image/png'));

    final String? second = partHeader(request.body, 'attachments[1]');
    expect(second, isNotNull, reason: 'attachments[1] part is missing');
    expect(second, contains('filename="invoice.pdf"'));
    expect(second!.toLowerCase(), contains('content-type: application/pdf'));

    final String? screenshot = partHeader(request.body, 'screenshot');
    expect(screenshot, isNotNull, reason: 'screenshot part is missing');
    expect(screenshot, contains('filename="screenshot.png"'));
    expect(screenshot!.toLowerCase(), contains('content-type: image/png'));

    expect(partHeader(request.body, 'attachments[2]'), isNull);
    expect(partHeader(request.body, 'client_context[route]'), isNotNull);
    expect(partHeader(request.body, 'client_context[app_version]'), isNotNull);
    expect(request.body, contains('/monitors'));
    expect(request.body, contains('See the attachments'));
    expect(request.body, contains('PNGDATA'));
    expect(request.body, contains('PDFDATA'));
  });

  test('a send without files stays JSON on the real wire', () async {
    final MagicStarterSupportConversation? created = await controller
        .createConversation(body: 'Hello', source: 'in_app');

    expect(created, isNotNull);
    expect(received.single.contentType, startsWith('application/json'));
    expect(jsonDecode(received.single.body), <String, dynamic>{
      'body': 'Hello',
      'source': 'in_app',
    });
  });
}
