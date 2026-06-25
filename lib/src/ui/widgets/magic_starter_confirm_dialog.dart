import 'package:flutter/material.dart' as m show BuildContext, showDialog;

import '../components/confirm_dialog/confirm_dialog.dart';

export '../components/confirm_dialog/confirm_dialog.dart'
    show ConfirmDialogVariant;

/// Thin backwards-compatible alias for the migrated [ConfirmDialog] component.
///
/// The confirm dialog moved to the canonical atomic-component folder
/// (`lib/src/ui/components/confirm_dialog/`) as part of the design-system
/// migration. This subclass preserves the historic `MagicStarterConfirmDialog`
/// name, constructor signature, [show] factory, and barrel export path so
/// existing callers and the widget test suite stay untouched. New code should
/// import [ConfirmDialog] directly.
class MagicStarterConfirmDialog extends ConfirmDialog {
  /// Creates a [MagicStarterConfirmDialog] (alias of [ConfirmDialog]).
  const MagicStarterConfirmDialog({
    super.key,
    required super.title,
    super.description,
    super.confirmLabel,
    super.cancelLabel,
    super.variant,
    super.onConfirm,
  });

  /// Opens a [MagicStarterConfirmDialog] and returns `true` if confirmed,
  /// `false` if cancelled.
  ///
  /// Overrides [ConfirmDialog.show] to create a [MagicStarterConfirmDialog]
  /// instance so `find.byType(MagicStarterConfirmDialog)` works in existing
  /// tests and callers.
  static Future<bool> show(
    m.BuildContext context, {
    required String title,
    String? description,
    String? confirmLabel,
    String? cancelLabel,
    ConfirmDialogVariant variant = ConfirmDialogVariant.primary,
    Future<void> Function()? onConfirm,
  }) {
    return m
        .showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => MagicStarterConfirmDialog(
            title: title,
            description: description,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            variant: variant,
            onConfirm: onConfirm,
          ),
        )
        .then((v) => v ?? false);
  }
}
