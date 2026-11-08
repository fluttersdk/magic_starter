import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:magic/magic.dart';

import '../facades/magic_starter.dart';
import 'support_page_ref.dart';

/// The references to the current screen a support message carries behind
/// `page_context`, as the host registered them with
/// `MagicStarter.usePageContext`.
///
/// Each entry is `{kind, id}`, cut to the backend's 64 characters; a cut id
/// simply does not resolve. At most [maxReferences] are kept, in the order the
/// provider gave them, and an entry with an empty kind or id is left out.
class MagicStarterSupportPageContext {
  MagicStarterSupportPageContext._();

  /// The most references the backend accepts.
  static const int maxReferences = 3;

  /// The longest `kind` or `id` the backend accepts.
  static const int maxLength = 64;

  /// Asks the registered provider what the customer is looking at right now.
  ///
  /// Empty when no provider is registered. A provider that throws is logged and
  /// read as empty: the page context never stands between a customer and
  /// support. Reference values are never logged.
  static List<Map<String, String>> collect() {
    final List<MagicStarterSupportPageRef> Function()? provider =
        MagicStarter.manager.pageContextProvider;
    if (provider == null) return const <Map<String, String>>[];

    try {
      // Cut before de-duplicating: two ids that differ only past the cut are
      // the same reference to the backend.
      final Set<MagicStarterSupportPageRef> references =
          <MagicStarterSupportPageRef>{
            for (final MagicStarterSupportPageRef ref in provider())
              if (ref.kind.isNotEmpty && ref.id.isNotEmpty)
                MagicStarterSupportPageRef(
                  kind: _limit(ref.kind),
                  id: _limit(ref.id),
                ),
          };

      return <Map<String, String>>[
        for (final MagicStarterSupportPageRef ref in references.take(
          maxReferences,
        ))
          ref.toMap(),
      ];
    } catch (error) {
      Log.warning('[MagicStarterSupportPageContext] provider failed: $error');

      return const <Map<String, String>>[];
    }
  }

  /// Forgets the registered provider, because statics outlive a test.
  @visibleForTesting
  static void resetForTesting() {
    MagicStarter.manager.pageContextProvider = null;
  }

  /// Counts characters, not UTF-16 units, as the backend does.
  static String _limit(String value) {
    return String.fromCharCodes(value.runes.take(maxLength));
  }
}
