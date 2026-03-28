import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Internal dialog shell — NOT exported from barrel.
/// Provides consistent Dialog chrome with sticky header/footer and scrollable body.
class MagicStarterDialogShell extends StatelessWidget {
  final String? title;
  final String? description;
  final Widget body;
  final Widget? footer;

  const MagicStarterDialogShell({
    super.key,
    this.title,
    this.description,
    required this.body,
    this.footer,
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
                child: SingleChildScrollView(
                  child: WDiv(
                    className: theme.bodyClassName,
                    child: body,
                  ),
                ),
              ),
              if (footer != null)
                WDiv(
                  key: const Key('magic_starter_dialog_shell_footer'),
                  className: theme.footerClassName,
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
