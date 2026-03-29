import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Reusable dialog shell providing consistent chrome for all Magic Starter
/// dialogs — sticky header, scrollable body, and optional sticky footer.
///
/// All visual tokens (container, header, title, description, body, footer
/// classNames, and `maxWidth`) are read from
/// `MagicStarter.manager.modalTheme` at build time. Set a custom theme via
/// `MagicStarter.useModalTheme()` before the first dialog is shown.
///
/// **Parameters:**
/// - [title] — optional heading rendered in the sticky header section.
/// - [description] — optional sub-heading rendered below [title].
/// - [body] — required content widget rendered in the scrollable body area.
/// - [footerBuilder] — optional builder for the sticky footer; receives the
///   dialog's own [BuildContext] so callers can access inherited widgets
///   (e.g. navigator) scoped to the dialog tree.
///
/// **Layout caveat:** the body is wrapped in a `ListView(shrinkWrap: true)`,
/// which collapses to content height. If [body] itself contains a nested
/// `ListView`, give it an explicit height constraint to avoid unbounded layout
/// errors.
class MagicStarterDialogShell extends StatelessWidget {
  final String? title;
  final String? description;
  final Widget body;

  /// Builder for the sticky footer section. Receives the dialog's own
  /// [BuildContext] so callers can access inherited widgets (e.g. theme,
  /// navigator) scoped to the dialog tree.
  final Widget Function(BuildContext dialogContext)? footerBuilder;

  const MagicStarterDialogShell({
    super.key,
    this.title,
    this.description,
    required this.body,
    this.footerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.manager.modalTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: theme.maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: WDiv(
          className:
              '${theme.containerClassName} flex flex-col w-full overflow-hidden',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
