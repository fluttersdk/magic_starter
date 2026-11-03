import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';
import '../dialog/dialog.dart';
import '../dialog/modal_presenter.dart';
import 'confirm_dialog.recipe.dart';

/// Visual style variants for [MSConfirmDialog].
///
/// - [primary] — Default confirmation: primary-colored confirm button.
/// - [danger] — Destructive action: red confirm button.
/// - [warning] — Cautionary action: amber confirm button.
enum ConfirmDialogVariant {
  /// Default confirmation with primary-colored button.
  primary,

  /// Destructive action with red button.
  danger,

  /// Cautionary action with amber button.
  warning,
}

/// A reusable confirm/cancel dialog built on the [MSDialog] shell, so it is a
/// bottom sheet in the modal theme's sheet presentation.
///
/// Supports three visual variants ([ConfirmDialogVariant]) and an optional
/// async [onConfirm] callback with double-click protection via `_isLoading`.
///
/// Returns `true` on confirm, `false` on cancel.
///
/// ### Example
/// ```dart
/// final confirmed = await MSConfirmDialog.show(
///   context,
///   title: 'Delete team?',
///   description: 'This cannot be undone.',
///   variant: ConfirmDialogVariant.danger,
///   onConfirm: () async => controller.deleteTeam(),
/// );
/// ```
class MSConfirmDialog extends StatefulWidget {
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

  /// Creates a [MSConfirmDialog].
  const MSConfirmDialog({
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
    return ModalPresenter.show<bool>(
      context,
      dismissible: false,
      builder: (_) => MSConfirmDialog(
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
  State<MSConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<MSConfirmDialog> {
  bool _isLoading = false;

  Future<void> _onConfirm() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await widget.onConfirm?.call();
    } catch (e, stackTrace) {
      Log.error('[ConfirmDialog._onConfirm] $e\n$stackTrace');
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

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.manager.modalTheme;
    final confirmLabel = widget.confirmLabel ?? trans('common.confirm');
    final cancelLabel = widget.cancelLabel ?? trans('common.cancel');
    final confirmClassName = resolveConfirmButtonClassName(
      widget.variant,
      theme,
    );

    // On the shared MSDialog shell, so the sheet presentation draws the sheet
    // panel here too. The empty body keeps the slot (and its padding) present.
    return MSDialog(
      title: widget.title,
      description: widget.description,
      body: const SizedBox.shrink(),
      footerBuilder: (_) => WDiv(
        className: 'flex flex-row justify-end gap-2 wrap',
        children: [
          WAnchor(
            onTap: _isLoading ? null : _onCancel,
            child: WDiv(
              className: theme.secondaryButtonClassName,
              child: WText(cancelLabel),
            ),
          ),
          WButton(
            onTap: _isLoading ? null : _onConfirm,
            isLoading: _isLoading,
            className: confirmClassName,
            child: WText(confirmLabel),
          ),
        ],
      ),
    );
  }
}
