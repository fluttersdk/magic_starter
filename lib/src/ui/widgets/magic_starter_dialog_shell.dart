import '../components/dialog/dialog.dart';

/// Thin backwards-compatible alias for the migrated [Dialog] component.
///
/// `MagicStarterDialogShell` moved to the canonical atomic-component folder
/// (`lib/src/ui/components/dialog/`) under the name [Dialog]. This subclass
/// preserves the historic `MagicStarterDialogShell` name and constructor
/// signature so existing callers, tests, and the barrel stay untouched.
/// New code should import [Dialog] directly.
class MagicStarterDialogShell extends Dialog {
  /// Creates a [MagicStarterDialogShell] (alias of [Dialog]).
  const MagicStarterDialogShell({
    super.key,
    super.title,
    super.description,
    required super.body,
    super.footerBuilder,
  });
}
