import 'package:flutter/material.dart' as m show Colors, showDialog, Dialog;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';
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

/// A reusable confirm/cancel dialog built on the Material dialog shell.
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
    return m
        .showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => MSConfirmDialog(
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

    // 1. Compute safe height, subtracting system insets.
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final safeHeight =
        (MediaQuery.sizeOf(context).height -
                viewPadding.top -
                viewPadding.bottom)
            .clamp(0.0, double.infinity);

    // 2. Build dialog shell with footer carrying compact right-aligned buttons.
    return m.Dialog(
      backgroundColor: m.Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: theme.maxWidth,
          maxHeight: safeHeight * 0.85,
        ),
        child: WDiv(
          className: '${theme.containerClassName} w-full overflow-hidden',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3. Header: title + optional description.
              WDiv(
                className: theme.headerClassName,
                children: [
                  WText(widget.title, className: theme.titleClassName),
                  if (widget.description != null)
                    WText(
                      widget.description!,
                      className: theme.descriptionClassName,
                    ),
                ],
              ),
              // 4. Empty body (SizedBox.shrink keeps the slot present).
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    WDiv(
                      className: theme.bodyClassName,
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              // 5. Footer: compact right-aligned cancel + confirm buttons.
              WDiv(
                className: theme.footerClassName,
                child: WDiv(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
