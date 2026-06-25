import 'package:flutter/material.dart' as m show Colors, showDialog, Dialog;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';

/// A reusable dialog component providing consistent Wind UI chrome driven by
/// `MagicStarter.manager.modalTheme` tokens.
///
/// Wraps the Material dialog shell with a sticky header (title + description),
/// a scrollable body, and an optional sticky footer. Safe-area computation
/// subtracts system insets so the dialog never clips behind notches or home
/// indicators on mobile.
///
/// All classNames are read from the modal theme at build time; override via
/// `MagicStarter.useModalTheme()` before the first dialog is shown.
///
/// ### Example
/// ```dart
/// await Dialog.show(
///   context,
///   title: 'Confirm deletion',
///   body: const WText('This cannot be undone.'),
///   footerBuilder: (ctx) => WButton(
///     onTap: () => Navigator.of(ctx).pop(),
///     child: const WText('OK'),
///   ),
/// );
/// ```
@immutable
class Dialog extends StatelessWidget {
  /// Optional heading rendered in the sticky header section.
  final String? title;

  /// Optional sub-heading rendered below [title].
  final String? description;

  /// Content widget rendered in the scrollable body area.
  final Widget body;

  /// Optional builder for the sticky footer; receives the dialog's own
  /// [BuildContext] so callers can safely access
  /// `Navigator.of(dialogContext)`.
  final Widget Function(BuildContext dialogContext)? footerBuilder;

  /// Creates a [Dialog].
  const Dialog({
    super.key,
    this.title,
    this.description,
    required this.body,
    this.footerBuilder,
  });

  /// Opens the dialog and resolves when it is dismissed.
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? description,
    required Widget body,
    Widget Function(BuildContext dialogContext)? footerBuilder,
  }) {
    return m.showDialog<T>(
      context: context,
      builder: (_) => Dialog(
        title: title,
        description: description,
        body: body,
        footerBuilder: footerBuilder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.manager.modalTheme;

    // 1. Compute safe height, subtracting system insets.
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final safeHeight = (MediaQuery.sizeOf(context).height -
            viewPadding.top -
            viewPadding.bottom)
        .clamp(0.0, double.infinity);

    // 2. Build Material dialog shell with Wind UI content inside.
    return m.Dialog(
      backgroundColor: m.Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
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
              // 3. Header section: title + description.
              if (title != null || description != null)
                WDiv(
                  className: theme.headerClassName,
                  children: [
                    if (title != null)
                      WText(
                        title!,
                        className: theme.titleClassName,
                      ),
                    if (description != null)
                      WText(
                        description!,
                        className: theme.descriptionClassName,
                      ),
                  ],
                ),
              // 4. Scrollable body: ListView collapses to content height.
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    WDiv(
                      className: theme.bodyClassName,
                      child: body,
                    ),
                  ],
                ),
              ),
              // 5. Sticky footer: Builder gives footer access to dialog
              //    context so Navigator.of(dialogContext) works correctly.
              if (footerBuilder != null)
                Builder(
                  builder: (dialogContext) => WDiv(
                    key: const Key('magic_starter_dialog_shell_footer'),
                    className: theme.footerClassName,
                    child: footerBuilder!(dialogContext),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
