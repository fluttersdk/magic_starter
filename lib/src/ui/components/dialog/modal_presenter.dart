import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart'
    as m
    show Colors, MaterialLocalizations, Theme, showDialog;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart' show MagicOverlayPresentation;

import '../../../configuration/magic_starter_theme.dart';
import '../../../facades/magic_starter.dart';
import '../../theme/magic_starter_breakpoints.dart';
import '../bottom_sheet/guarded_sheet_route.dart';

/// The one place a starter modal chooses between a dialog and a bottom sheet.
///
/// Package-internal. Every starter opener (`MSDialog.show`,
/// `MSConfirmDialog.show`, the password confirm, step up and two factor
/// dialogs) goes through [show], and `MSBottomSheet.show` through [showSheet]
/// (through [show] for the dialog its `dialogBreakpoint` swaps in), so `MagicStarterModalTheme.presentation` is read in one place. It imports
/// no component, which keeps `dialog.dart` and `bottom_sheet.dart` free of an
/// import cycle.
///
/// [show] and [showSheet] take an optional dismiss guard: while `canDismiss`
/// is false a scrim tap (or its semantics dismiss), Back and Escape leave the
/// modal open and call `onDismissBlocked` with a context inside the modal,
/// and a sheet takes no drag down. The value is read when the gesture lands,
/// not when the modal opens. A `Navigator.pop` with a context inside the
/// modal skips the guard and closes it.
abstract final class ModalPresenter {
  /// Whether the active modal theme presents a dialog at [context]'s width:
  /// always for `dialog`, never for `sheet`, and for `adaptive` from the
  /// theme's `dialogBreakpoint` up.
  ///
  /// Throws a [StateError] naming `MagicStarterModalTheme.dialogBreakpoint`
  /// when `adaptive` is set with a breakpoint the Wind theme does not carry.
  static bool presentsDialog(BuildContext context) {
    final MagicStarterModalTheme theme = MagicStarter.manager.modalTheme;

    return switch (theme.presentation) {
      MagicStarterModalPresentation.dialog => true,
      MagicStarterModalPresentation.sheet => false,
      MagicStarterModalPresentation.adaptive =>
        MagicStarterBreakpoints.isAtLeast(
          context,
          theme.dialogBreakpoint,
          setting: 'MagicStarterModalTheme.dialogBreakpoint',
        ),
    };
  }

  /// How magic's router frames an overlay route (`RouteDefinition.overlay`)
  /// that opens at [context]'s width: a dialog under an `adaptive` theme from
  /// its `dialogBreakpoint` up, a sheet otherwise.
  ///
  /// Only `adaptive` moves an overlay route: a route has always been a sheet
  /// whatever `dialog` and `sheet` say, and an app that never asked for
  /// `adaptive` keeps it so. The starter provider installs this on the router
  /// at boot; an app that wants another rule calls
  /// `MagicRoute.useOverlayPresentation` after it.
  static MagicOverlayPresentation overlayPresentation(BuildContext context) {
    final bool adaptive =
        MagicStarter.manager.modalTheme.presentation ==
        MagicStarterModalPresentation.adaptive;

    return adaptive && presentsDialog(context)
        ? MagicOverlayPresentation.dialog
        : MagicOverlayPresentation.sheet;
  }

  /// Presents [builder] as a dialog or a sheet, per the active modal theme's
  /// `presentation`, read when the call is made (an `adaptive` theme reads the
  /// screen width then too).
  ///
  /// [dismissible] false keeps the modal open on a scrim tap and, as a sheet,
  /// on a drag down too: the openers that pass it guard only their own Cancel
  /// button while a request is in flight.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool dismissible = true,
    ValueListenable<bool>? canDismiss,
    void Function(BuildContext modalContext)? onDismissBlocked,
  }) {
    if (!presentsDialog(context)) {
      return showSheet<T>(
        context,
        builder: builder,
        dismissible: dismissible,
        canDismiss: canDismiss,
        onDismissBlocked: onDismissBlocked,
      );
    }

    return m.showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: _guarded(builder, canDismiss, onDismissBlocked),
    );
  }

  /// Presents [builder] as a bottom sheet whatever the theme says.
  static Future<T?> showSheet<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool dismissible = true,
    ValueListenable<bool>? canDismiss,
    void Function(BuildContext modalContext)? onDismissBlocked,
  }) {
    assert(debugCheckHasMediaQuery(context));

    // 1. Present on the root navigator so the sheet + scrim span the whole
    //    viewport and anchor to the real screen bottom. Shown on the shell's
    //    content navigator the overlay is confined to the content area, which
    //    left the sheet floating with a bottom gap on tall/wide screens.
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    final m.MaterialLocalizations localizations = m.MaterialLocalizations.of(
      context,
    );

    // 2. The frame `showModalBottomSheet` builds, on a route that can also
    //    switch its drag off while the guard refuses.
    return navigator.push(
      GuardedSheetRoute<T>(
        builder: _guarded(builder, canDismiss, onDismissBlocked),
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        isScrollControlled: true,
        barrierLabel: localizations.scrimLabel,
        barrierOnTapHint: localizations.scrimOnTapHint(
          localizations.bottomSheetLabel,
        ),
        backgroundColor: m.Colors.transparent,
        modalBarrierColor: m.Theme.of(context)
            .bottomSheetTheme
            .modalBarrierColor,
        isDismissible: dismissible,
        enableDrag: dismissible,
        canDismiss: canDismiss,
      ),
    );
  }

  /// [builder] behind a [_DismissGuard] when there is a guard, else as is.
  static WidgetBuilder _guarded(
    WidgetBuilder builder,
    ValueListenable<bool>? canDismiss,
    void Function(BuildContext modalContext)? onDismissBlocked,
  ) {
    if (canDismiss == null) {
      return builder;
    }

    return (context) => _DismissGuard(
      canDismiss: canDismiss,
      onDismissBlocked: onDismissBlocked,
      child: builder(context),
    );
  }
}

/// Refuses every `Navigator.maybePop` (a scrim tap, Back, Escape) of the
/// modal it sits in while [canDismiss] is false, and reports each refusal
/// with a context below the `PopScope`.
class _DismissGuard extends StatefulWidget {
  final ValueListenable<bool> canDismiss;
  final void Function(BuildContext modalContext)? onDismissBlocked;
  final Widget child;

  const _DismissGuard({
    required this.canDismiss,
    required this.onDismissBlocked,
    required this.child,
  });

  @override
  State<_DismissGuard> createState() => _DismissGuardState();
}

class _DismissGuardState extends State<_DismissGuard> {
  /// Marks the content below the `PopScope`, whose context the callback gets.
  final GlobalKey _contentKey = GlobalKey();

  void _onPopInvoked(bool didPop, Object? _) {
    // Another pop entry in the modal (a Form) may refuse too; only a refusal
    // this guard made is the caller's to answer.
    if (didPop || widget.canDismiss.value) {
      return;
    }

    widget.onDismissBlocked?.call(_contentKey.currentContext!);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.canDismiss,
      child: KeyedSubtree(key: _contentKey, child: widget.child),
      builder: (context, allowed, child) => PopScope<Object?>(
        canPop: allowed,
        onPopInvokedWithResult: _onPopInvoked,
        child: child!,
      ),
    );
  }
}
