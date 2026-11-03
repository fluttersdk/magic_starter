import 'package:flutter/material.dart'
    as m
    show Colors, Dialog, ModalBottomSheetRoute;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_theme.dart';
import '../../../facades/magic_starter.dart';
import '../bottom_sheet/bottom_sheet_panel.dart';
import 'modal_presenter.dart';
import 'modal_sections.dart';

/// A reusable dialog component providing consistent Wind UI chrome driven by
/// `MagicStarter.manager.modalTheme` tokens.
///
/// Wraps the Material dialog shell with a header (title + description), a
/// scrollable body and an optional fixed footer. The header shares the body's
/// scroll view: it stays pinned while it takes at most half of it and scrolls
/// with the body above that. Safe-area computation
/// subtracts system insets so the dialog never clips behind notches or home
/// indicators on mobile.
///
/// All classNames are read from the modal theme at build time; override via
/// `MagicStarter.useModalTheme()` before the first dialog is shown.
///
/// Built inside a bottom-sheet route, which [show] opens when the modal
/// theme's `presentation` is [MagicStarterModalPresentation.sheet], the widget
/// draws the `MSBottomSheet` panel (drag handle, full width, keyboard and
/// home-indicator insets) with the same header, body and footer instead of
/// the dialog shell.
///
/// ### Example
/// ```dart
/// await MSDialog.show(
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
class MSDialog extends StatelessWidget {
  /// Optional heading rendered in the header section.
  final String? title;

  /// Optional sub-heading rendered below [title].
  final String? description;

  /// Content widget rendered in the body area.
  final Widget body;

  /// Whether the dialog scrolls [body] for it (the default).
  ///
  /// Pass `false` for a body that owns its scrolling: it then gets the
  /// dialog's bounded height to lay out in and the dialog adds no scroll view
  /// of its own, the same contract as `MSBottomSheet.scrollable`, so a sheet
  /// presented as a dialog from a breakpoint keeps its body's layout.
  final bool scrollable;

  /// Optional builder for the sticky footer; receives the dialog's own
  /// [BuildContext] so callers can safely access
  /// `Navigator.of(dialogContext)`.
  final Widget Function(BuildContext dialogContext)? footerBuilder;

  /// Creates a [MSDialog].
  const MSDialog({
    super.key,
    this.title,
    this.description,
    required this.body,
    this.footerBuilder,
    this.scrollable = true,
  });

  /// Opens the dialog and resolves when it is dismissed.
  ///
  /// With `MagicStarterModalTheme.presentation` set to
  /// [MagicStarterModalPresentation.sheet] the same content opens as a bottom
  /// sheet instead; a scrim tap or a drag down closes it with `null`.
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? description,
    required Widget body,
    Widget Function(BuildContext dialogContext)? footerBuilder,
    bool scrollable = true,
  }) {
    return ModalPresenter.show<T>(
      context,
      builder: (_) => MSDialog(
        title: title,
        description: description,
        body: body,
        footerBuilder: footerBuilder,
        scrollable: scrollable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Inside a bottom-sheet route (the sheet presentation), draw the sheet
    //    panel rather than a dialog shell inside a sheet. The route decides,
    //    not the theme, so a dialog a host opens itself keeps its shell.
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route is m.ModalBottomSheetRoute) {
      return MSBottomSheetPanel(
        showHandle: route.enableDrag,
        title: title,
        description: description,
        body: body,
        footerBuilder: footerBuilder,
        scrollable: scrollable,
        footerKey: const Key('magic_starter_dialog_shell_footer'),
      );
    }

    final theme = MagicStarter.manager.modalTheme;

    // 2. Compute safe height, subtracting system insets.
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final safeHeight =
        (MediaQuery.sizeOf(context).height -
                viewPadding.top -
                viewPadding.bottom)
            .clamp(0.0, double.infinity);

    // 3. Build Material dialog shell with Wind UI content inside.
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
          child: ModalSections(
            scrollable: scrollable,
            // 4. Header section: title + description.
            header: title != null || description != null
                ? WDiv(
                    className: theme.headerClassName,
                    children: [
                      if (title != null)
                        WText(title!, className: theme.titleClassName),
                      if (description != null)
                        WText(
                          description!,
                          className: theme.descriptionClassName,
                        ),
                    ],
                  )
                : null,
            // 5. Body: in the scroll view it shares with the header, or the
            //    bounded height handed to a body that scrolls itself.
            body: WDiv(className: theme.bodyClassName, child: body),
            // 6. Sticky footer: Builder gives footer access to dialog
            //    context so Navigator.of(dialogContext) works correctly.
            footer: footerBuilder != null
                ? Builder(
                    builder: (dialogContext) => WDiv(
                      key: const Key('magic_starter_dialog_shell_footer'),
                      className: theme.footerClassName,
                      child: footerBuilder!(dialogContext),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
