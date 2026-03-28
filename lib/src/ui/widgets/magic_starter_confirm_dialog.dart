import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';
import 'magic_starter_dialog_shell.dart';

/// Visual style variants for [MagicStarterConfirmDialog].
enum ConfirmDialogVariant {
  /// Default confirmation with primary-colored button.
  primary,

  /// Destructive action with red button.
  danger,

  /// Cautionary action with amber button.
  warning,
}

/// A reusable confirm/cancel dialog built on [MagicStarterDialogShell].
///
/// Supports three visual variants ([ConfirmDialogVariant]) and an optional
/// async [onConfirm] callback with double-click protection via [_isLoading].
///
/// Returns `true` on confirm, `false` on cancel.
class MagicStarterConfirmDialog extends StatefulWidget {
  /// Dialog heading text.
  final String title;

  /// Optional supporting text rendered below the title.
  final String? description;

  /// Label for the confirm button. Defaults to `trans('common.confirm')`.
  final String? confirmLabel;

  /// Label for the cancel button. Defaults to `trans('common.cancel')`.
  final String? cancelLabel;

  /// Visual variant that controls the confirm button colour.
  final ConfirmDialogVariant variant;

  /// Optional async callback invoked when the user taps the confirm button.
  final Future<void> Function()? onConfirm;

  const MagicStarterConfirmDialog({
    super.key,
    required this.title,
    this.description,
    this.confirmLabel,
    this.cancelLabel,
    this.variant = ConfirmDialogVariant.primary,
    this.onConfirm,
  });

  /// Opens the dialog and returns `true` if confirmed, `false` if cancelled.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? description,
    String? confirmLabel,
    String? cancelLabel,
    ConfirmDialogVariant variant = ConfirmDialogVariant.primary,
    Future<void> Function()? onConfirm,
  }) {
    return showDialog<bool>(
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
    ).then((v) => v ?? false);
  }

  @override
  State<MagicStarterConfirmDialog> createState() =>
      _MagicStarterConfirmDialogState();
}

class _MagicStarterConfirmDialogState extends State<MagicStarterConfirmDialog> {
  bool _isLoading = false;

  Future<void> _onConfirm() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await widget.onConfirm?.call();
    } catch (e, stackTrace) {
      Log.error('[MagicStarterConfirmDialog._onConfirm] $e\n$stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  void _onCancel() {
    if (_isLoading) return;
    Navigator.of(context).pop(false);
  }

  String _resolveConfirmClassName() {
    final theme = MagicStarter.manager.modalTheme;

    return switch (widget.variant) {
      ConfirmDialogVariant.primary => theme.primaryButtonClassName,
      ConfirmDialogVariant.danger => theme.dangerButtonClassName,
      ConfirmDialogVariant.warning => theme.warningButtonClassName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.manager.modalTheme;
    final confirmLabel = widget.confirmLabel ?? trans('common.confirm');
    final cancelLabel = widget.cancelLabel ?? trans('common.cancel');

    return MagicStarterDialogShell(
      title: widget.title,
      description: widget.description,
      body: const SizedBox.shrink(),
      footer: WDiv(
        className: 'flex flex-row gap-2 w-full',
        children: [
          WDiv(
            className: 'flex-1',
            child: WAnchor(
              onTap: _isLoading ? null : _onCancel,
              child: WDiv(
                className: theme.secondaryButtonClassName,
                child: WText(cancelLabel),
              ),
            ),
          ),
          WDiv(
            className: 'flex-1',
            child: WButton(
              onTap: _isLoading ? null : _onConfirm,
              isLoading: _isLoading,
              className: 'w-full ${_resolveConfirmClassName()}',
              child: WText(confirmLabel),
            ),
          ),
        ],
      ),
    );
  }
}
