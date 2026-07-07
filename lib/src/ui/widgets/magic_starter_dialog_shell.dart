import '../components/dialog/dialog.dart';

/// Thin backwards-compatible alias for the migrated [MSDialog] component.
///
/// `MagicStarterDialogShell` moved to the canonical atomic-component folder
/// (`lib/src/ui/components/dialog/`) under the name [MSDialog]. This subclass
/// preserves the historic `MagicStarterDialogShell` name and constructor
/// signature so existing callers, tests, and the barrel stay untouched.
/// New code should import [MSDialog] directly.
class MagicStarterDialogShell extends MSDialog {
  /// Creates a [MagicStarterDialogShell] (alias of [MSDialog]).
  const MagicStarterDialogShell({
    super.key,
    super.title,
    super.description,
    required super.body,
    super.footerBuilder,
  });
}
