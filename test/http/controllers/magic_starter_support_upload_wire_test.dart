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
    MagicStarterSupportPageContext.resetForTesting();
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

  /// Every part name in [body].
  List<String> partNames(String body) {
    return RegExp(
      'content-disposition: form-data; name="([^"]+)"',
      caseSensitive: false,
    ).allMatches(body).map((RegExpMatch m) => m.group(1)!).toList();
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
          clientContext: <String, String>{
            'platform': 'ios',
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

    expect(partHeader(request.body, 'attachments[2]'), isNull);
    expect(partHeader(request.body, 'client_context[platform]'), isNotNull);
    expect(partHeader(request.body, 'client_context[app_version]'), isNotNull);
    expect(
      partNames(request.body),
      unorderedEquals(<String>[
        'body',
        'source',
        'attachments[0]',
        'attachments[1]',
        'client_context[platform]',
        'client_context[app_version]',
      ]),
      reason: 'no part beyond the text, files and client info is sent',
    );
    expect(request.body, contains('See the attachments'));
    expect(request.body, contains('PNGDATA'));
    expect(request.body, contains('PDFDATA'));
  });

  test('a multipart send flattens page_context on the real wire', () async {
    MagicStarter.usePageContext(
      () => const <MagicStarterSupportPageRef>[
        MagicStarterSupportPageRef(kind: 'monitor', id: '42'),
        MagicStarterSupportPageRef(kind: 'incident', id: '7'),
      ],
    );

    await controller.createConversation(
      body: 'See the attachment',
      source: 'in_app',
      attachments: <MagicFile>[file('error.png', 'image/png', 'PNGDATA')],
    );
    await controller.sendMessage(
      7,
      'And this one',
      attachments: <MagicFile>[file('invoice.pdf', 'application/pdf', 'PDF')],
    );

    expect(received, hasLength(2));

    for (final _Received request in received) {
      expect(request.contentType, startsWith('multipart/form-data'));
      expect(
        partNames(request.body),
        containsAll(<String>[
          'page_context[0][kind]',
          'page_context[0][id]',
          'page_context[1][kind]',
          'page_context[1][id]',
        ]),
      );
      expect(partNames(request.body), isNot(contains('page_context')));
      expect(request.body, contains('monitor'));
      expect(request.body, contains('incident'));
    }
  });

  test('a JSON send carries page_context as a list on the real wire', () async {
    MagicStarter.usePageContext(
      () => const <MagicStarterSupportPageRef>[
        MagicStarterSupportPageRef(kind: 'monitor', id: '42'),
      ],
    );

    await controller.createConversation(body: 'Hello', source: 'in_app');
    await controller.sendMessage(7, 'Any update?');

    expect(received, hasLength(2));
    expect(jsonDecode(received.first.body), <String, dynamic>{
      'body': 'Hello',
      'source': 'in_app',
      'page_context': <Map<String, dynamic>>[
        <String, dynamic>{'kind': 'monitor', 'id': '42'},
      ],
    });
    expect(jsonDecode(received.last.body), <String, dynamic>{
      'body': 'Any update?',
      'page_context': <Map<String, dynamic>>[
        <String, dynamic>{'kind': 'monitor', 'id': '42'},
      ],
    });
  });

  test('a throwing provider sends the message without the key', () async {
    Log.fake();
    MagicStarter.usePageContext(() => throw StateError('no route yet'));

    final MagicStarterSupportConversation? created = await controller
        .createConversation(body: 'Hello', source: 'in_app');

    expect(created, isNotNull);
    expect(jsonDecode(received.single.body), <String, dynamic>{
      'body': 'Hello',
      'source': 'in_app',
    });
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
