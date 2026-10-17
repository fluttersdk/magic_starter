import 'dart:convert';
import 'dart:js_interop';

import 'package:magic/magic.dart';
import 'package:web/web.dart' as web;

/// The `build_number` of the `version.json` the server is serving now, or
/// `null` when it cannot be read.
///
/// Fetched straight from the page's own origin (never through the Http facade,
/// which would prefix the API base url and attach the bearer token), with a
/// cache buster and `no-store` so a CDN or the browser cannot answer with the
/// bundle the page already runs. A non-ok status, an unreadable body or a
/// missing or empty `build_number` is logged and answers `null`: a failed
/// check is never a reason to bother the customer.
///
/// [url] replaces the default location; it is a test seam.
Future<String?> fetchDeployedBuildNumber({Uri? url}) async {
  final Uri target = url ?? _versionUrl();

  try {
    final web.Response response = await web.window
        .fetch(target.toString().toJS, web.RequestInit(cache: 'no-store'))
        .toDart;

    if (!response.ok) {
      Log.warning(
        '[web_deploy] version.json answered status ${response.status}',
      );

      return null;
    }

    final String body = (await response.text().toDart).toDart;
    final Object? decoded = jsonDecode(body);
    final Object? build = decoded is Map<String, dynamic>
        ? decoded['build_number']
        : null;

    return build is String && build.isNotEmpty ? build : null;
  } catch (error) {
    Log.warning('[web_deploy] version.json unreadable: $error');

    return null;
  }
}

/// Reloads the page, which fetches the newly deployed bundle.
void reloadPage() => web.window.location.reload();

Uri _versionUrl() {
  return Uri.base
      .resolve('version.json')
      .replace(
        queryParameters: <String, String>{
          'cb': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
}
