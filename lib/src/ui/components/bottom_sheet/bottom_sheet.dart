import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../configuration/magic_starter_theme.dart';
import '../../../facades/magic_starter.dart';
import '../../theme/magic_starter_breakpoints.dart';
import '../dialog/dialog.dart';
import '../dialog/modal_presenter.dart';
import 'bottom_sheet_panel.dart';

/// A reusable bottom-sheet component with Wind UI chrome driven by
/// `MagicStarter.manager.modalTheme` tokens.
///
/// Provides an optional header (title + description), a body (scrolled by the
/// sheet unless [scrollable] is false), and an optional sticky footer. The
/// bottom sheet slides up from the screen edge with a rounded top radius.
///
/// All classNames are read from the modal theme at build time; override via
/// `MagicStarter.useModalTheme()` before the first bottom sheet is shown.
///
/// ### Adaptive presentation
///
/// A sheet rises from the bottom edge of a phone; on a desktop window that
/// edge is a long way from the pointer. Pass `dialogBreakpoint` to [show] and,
/// from that Wind breakpoint up, the same call presents an [MSDialog] with the
/// same title, description, body, footer and [scrollable] contract instead.
/// With `MagicStarterModalTheme.presentation` set to
/// [MagicStarterModalPresentation.sheet] the argument is ignored: the app has
/// chosen a sheet at every width.
///
/// ### Example
/// ```dart
/// await MSBottomSheet.show(
///   context,
///   title: 'Select action',
///   body: Column(children: [...]),
///   dialogBreakpoint: 'lg', // a dialog from 1024 px, a sheet below
/// );
/// ```
@immutable
class MSBottomSheet extends StatelessWidget {
  /// Optional heading rendered at the top of the sheet.
  final String? title;

  /// Optional sub-heading rendered below [title].
  final String? description;

  /// Content widget rendered in the body area.
  final Widget body;

  /// Whether the sheet scrolls [body] for it (the default).
  ///
  /// Pass `false` for a body that owns its scrolling, such as a fixed summary
  /// above a paged list: the body then gets the sheet's bounded height to lay
  /// out in (an `Expanded` list fills what is left), and the sheet adds no
  /// scroll view of its own, so there is one scrollbar rather than one inside
  /// another. Such a body must fit, or scroll, within that height itself.
  final bool scrollable;

  /// Optional builder for the sticky footer; receives the sheet's own
  /// [BuildContext].
  final Widget Function(BuildContext sheetContext)? footerBuilder;

  /// Creates a [MSBottomSheet].
  const MSBottomSheet({
    super.key,
    this.title,
    this.description,
    required this.body,
    this.footerBuilder,
    this.scrollable = true,
  });

  /// Opens the bottom sheet and resolves when it is dismissed.
  ///
  /// With [dialogBreakpoint] set (a Wind breakpoint name such as `'lg'`), a
  /// screen at least that wide gets an [MSDialog] instead, built from the same
  /// arguments; [footerBuilder] then receives the dialog's context, so a
  /// `Navigator.pop` in it closes whichever was shown. The width is read once,
  /// when the call is made. Null (the default) always presents a sheet, and so
  /// does a modal theme whose `presentation` is
  /// [MagicStarterModalPresentation.sheet], which ignores [dialogBreakpoint].
  ///
  /// [canDismiss] holds the sheet open for a body with unsaved input: while
  /// its value is false a drag down is off (the handle stays drawn), and a
  /// scrim tap or its semantics dismiss, Back and Escape leave the sheet open
  /// and call [onDismissBlocked], where the caller can ask the person whether
  /// to discard (the sheet draws no such question). The value is read when
  /// the gesture lands, so a field that turns dirty after the sheet opened
  /// holds the next gesture. The dialog [dialogBreakpoint] presents is held
  /// the same way, barrier tap included.
  ///
  /// [onDismissBlocked] receives the sheet's own context. The sheet sits on
  /// the root navigator, so close it with `Navigator.of(sheetContext).pop()`
  /// once the person confirms the discard: a `pop` skips the guard, so it
  /// need not be flipped first, while a `maybePop` stays refused. The opener's
  /// context would pop the wrong navigator. A `Navigator.pop` from
  /// [footerBuilder] closes either too. Null [canDismiss] (the default) lets
  /// every gesture close it.
  ///
  /// Throws a [StateError] when [dialogBreakpoint] names a breakpoint the Wind
  /// theme does not carry, rather than silently never presenting a dialog.
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? description,
    required Widget body,
    Widget Function(BuildContext sheetContext)? footerBuilder,
    bool scrollable = true,
    String? dialogBreakpoint,
    ValueListenable<bool>? canDismiss,
    void Function(BuildContext sheetContext)? onDismissBlocked,
  }) {
    final String? breakpoint = dialogBreakpoint;
    final bool sheetEverywhere =
        MagicStarter.manager.modalTheme.presentation ==
        MagicStarterModalPresentation.sheet;
    if (!sheetEverywhere &&
        breakpoint != null &&
        MagicStarterBreakpoints.isAtLeast(
          context,
          breakpoint,
          setting: 'MSBottomSheet.show(dialogBreakpoint:)',
        )) {
      // What `MSDialog.show` does, with the guard it does not take; the
      // presentation here is `dialog`, so the presenter shows a dialog.
      return ModalPresenter.show<T>(
        context,
        canDismiss: canDismiss,
        onDismissBlocked: onDismissBlocked,
        builder: (_) => MSDialog(
          title: title,
          description: description,
          body: body,
          footerBuilder: footerBuilder,
          scrollable: scrollable,
        ),
      );
    }

    return ModalPresenter.showSheet<T>(
      context,
      canDismiss: canDismiss,
      onDismissBlocked: onDismissBlocked,
      builder: (_) => MSBottomSheet(
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
    return MSBottomSheetPanel(
      title: title,
      description: description,
      body: body,
      footerBuilder: footerBuilder,
      scrollable: scrollable,
      footerKey: const Key('bottom_sheet_footer'),
    );
  }
}
