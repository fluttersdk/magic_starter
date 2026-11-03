import 'package:flutter/material.dart'
    as m
    show Colors, showDialog, showModalBottomSheet;
import 'package:flutter/widgets.dart';

import '../../../configuration/magic_starter_theme.dart';
import '../../../facades/magic_starter.dart';

/// The one place a starter modal chooses between a dialog and a bottom sheet.
///
/// Package-internal. Every starter opener (`MSDialog.show`,
/// `MSConfirmDialog.show`, the password confirm, step up and two factor
/// dialogs) goes through [show], and `MSBottomSheet.show` through [showSheet],
/// so `MagicStarterModalTheme.presentation` is read in one place. It imports
/// no component, which keeps `dialog.dart` and `bottom_sheet.dart` free of an
/// import cycle.
abstract final class ModalPresenter {
  /// Presents [builder] as a dialog or a sheet, per the active modal theme's
  /// `presentation`, read when the call is made.
  ///
  /// [dismissible] false keeps the modal open on a scrim tap and, as a sheet,
  /// on a drag down too: the openers that pass it guard only their own Cancel
  /// button while a request is in flight.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool dismissible = true,
  }) {
    if (MagicStarter.manager.modalTheme.presentation ==
        MagicStarterModalPresentation.sheet) {
      return showSheet<T>(context, builder: builder, dismissible: dismissible);
    }

    return m.showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: builder,
    );
  }

  /// Presents [builder] as a bottom sheet whatever the theme says.
  static Future<T?> showSheet<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool dismissible = true,
  }) {
    return m.showModalBottomSheet<T>(
      context: context,
      backgroundColor: m.Colors.transparent,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      // Present on the root navigator so the sheet + scrim span the whole
      // viewport and anchor to the real screen bottom. Shown on the shell's
      // content navigator the overlay is confined to the content area, which
      // left the sheet floating with a bottom gap on tall/wide screens.
      useRootNavigator: true,
      builder: builder,
    );
  }
}
