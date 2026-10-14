import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:magic/magic.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The client info a new support conversation carries behind
/// `support_diagnostics`: where the customer was, which build they run, on
/// what, and in which language and timezone.
///
/// Keys match the backend's `client_context[...]` fields. Each value is cut to
/// the backend's 120 characters, and a value the device cannot tell is left
/// out rather than sent empty.
class MagicStarterSupportClientContext {
  MagicStarterSupportClientContext._();

  /// The longest value the backend stores.
  static const int maxLength = 120;

  /// Collects the client info for a conversation opened after [route].
  ///
  /// [route] loses its query and fragment here; a query can carry a token. The
  /// app version is read from the platform, and an unreadable one is logged
  /// and left out: diagnostics never stand between a customer and support.
  static Future<Map<String, String>> collect({required String route}) async {
    final PackageInfo? package = await _packageInfo();

    final Map<String, String?> context = <String, String?>{
      'route': Uri.parse(route).path,
      'app_version': package?.version,
      'build_number': package?.buildNumber,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'os_version': kIsWeb ? null : Platform.operatingSystemVersion,
      'locale': Lang.current.toLanguageTag(),
      'timezone':
          DateManager.instance.detectTimezone() ?? DateTime.now().timeZoneName,
    };

    return <String, String>{
      for (final MapEntry<String, String?> field in context.entries)
        if (field.value != null && field.value!.isNotEmpty)
          field.key: _limit(field.value!),
    };
  }

  static Future<PackageInfo?> _packageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (error) {
      Log.warning('[MagicStarterSupportClientContext] package info: $error');

      return null;
    }
  }

  static String _limit(String value) {
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }
}
