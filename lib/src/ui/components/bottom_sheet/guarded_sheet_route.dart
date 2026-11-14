import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' as m show ModalBottomSheetRoute;
import 'package:flutter/widgets.dart';

/// The bottom-sheet route every starter sheet is pushed on, so a caller's
/// dismiss guard can switch the drag down off while the sheet is open.
///
/// Package-internal; `ModalPresenter.showSheet` pushes it. Without a
/// [canDismiss] it is a plain [m.ModalBottomSheetRoute]. Flutter's drag closes
/// a sheet through `Navigator.pop`, which no `PopScope` can refuse, so the
/// guard has to reach [enableDrag] itself; a scrim tap and Back are refused by
/// a `PopScope` the presenter puts around the content.
class GuardedSheetRoute<T> extends m.ModalBottomSheetRoute<T> {
  /// Whether a drag down may close the sheet now; null always lets it.
  ///
  /// Read again every time the value changes: the route rebuilds its sheet,
  /// so a guard that turns false after the sheet opened holds the next drag.
  final ValueListenable<bool>? canDismiss;

  /// Creates a [GuardedSheetRoute] with the frame `showModalBottomSheet`
  /// would build from the same arguments.
  GuardedSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.modalBarrierColor,
    super.isDismissible,
    super.enableDrag,
    this.canDismiss,
  });

  @override
  bool get enableDrag => super.enableDrag && (canDismiss?.value ?? true);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final ValueListenable<bool>? guard = canDismiss;
    if (guard == null) {
      return super.buildPage(context, animation, secondaryAnimation);
    }

    // ModalRoute builds its page once and keeps it, so the sheet's drag
    // gesture would keep the value it opened with without this rebuild.
    return ValueListenableBuilder<bool>(
      valueListenable: guard,
      builder: (context, _, _) =>
          super.buildPage(context, animation, secondaryAnimation),
    );
  }
}
