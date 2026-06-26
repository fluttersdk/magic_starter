// Thin alias — MagicStarterPageHeader is preserved for backward compatibility.
// The implementation now lives in components/page_header/page_header.dart.

export '../components/page_header/page_header.dart' show PageHeader;

import '../components/page_header/page_header.dart';

/// Backward-compatible alias for [PageHeader].
///
/// Delegates all construction to [PageHeader] so existing callers and the
/// test suite are unaffected. New [backLabel] and [backFallback] params are
/// forwarded to the underlying [PageHeader] implementation.
class MagicStarterPageHeader extends PageHeader {
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
