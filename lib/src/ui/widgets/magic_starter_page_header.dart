// Thin alias — MagicStarterPageHeader is preserved for backward compatibility.
// The implementation now lives in components/page_header/page_header.dart.

export '../components/page_header/page_header.dart' show MSPageHeader;

import '../components/page_header/page_header.dart';

/// Backward-compatible alias for [MSPageHeader].
///
/// Delegates all construction to [MSPageHeader] so existing callers and the
/// test suite are unaffected. New [backLabel] and [backFallback] params are
/// forwarded to the underlying [MSPageHeader] implementation.
class MagicStarterPageHeader extends MSPageHeader {
  const MagicStarterPageHeader({
    super.key,
    required super.title,
    super.subtitle,
    super.leading,
    super.actions,
    super.titleSuffix,
    super.inlineActions,
    super.backLabel,
    super.backFallback,
  });
}
