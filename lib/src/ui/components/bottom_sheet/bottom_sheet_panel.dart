import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_theme.dart';
import '../../../facades/magic_starter.dart';
import '../dialog/modal_sections.dart';

/// The bottom-sheet panel: drag handle, optional header, body, optional sticky
/// footer and the bottom safe-area strip, lifted clear of the keyboard.
///
/// Package-internal. It is the one sheet implementation behind both
/// `MSBottomSheet` and `MSDialog` when that dialog is presented as a sheet
/// (`MagicStarterModalPresentation.sheet`); the two differ only in
/// [footerKey], which their tests and callers find the footer by.
@immutable
class MSBottomSheetPanel extends StatelessWidget {
  /// Optional heading rendered at the top of the panel.
  final String? title;

  /// Optional sub-heading rendered below [title].
  final String? description;

  /// Content widget rendered in the body area.
  final Widget body;

  /// Whether the panel scrolls [body] for it; see `MSBottomSheet.scrollable`.
  final bool scrollable;

  /// Optional builder for the sticky footer; receives the panel's own
  /// [BuildContext], so a `Navigator.pop` in it closes the sheet.
  final Widget Function(BuildContext sheetContext)? footerBuilder;

  /// The key on the footer's wrapper.
  final Key footerKey;

  /// Whether the drag handle is drawn; false for a sheet that cannot be
  /// dragged, so it does not offer a gesture it refuses.
  final bool showHandle;

  /// Creates a [MSBottomSheetPanel].
  const MSBottomSheetPanel({
    super.key,
    this.title,
    this.description,
    required this.body,
    this.footerBuilder,
    this.scrollable = true,
    required this.footerKey,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.manager.modalTheme;

    // 1. Constrain sheet height to 85% of the space the sheet can actually
    //    occupy: the screen, less the safe area, less the software keyboard.
    //
    //    The keyboard term is load-bearing and it is the consumer's job.
    //    `showModalBottomSheet` does not compensate for it: `viewInsets`
    //    appears nowhere in Flutter's `material/bottom_sheet.dart`, so a sheet
    //    asked for 85% of the FULL screen keeps that height while the keyboard
    //    covers the bottom third of it. Measured on an iPhone 17, a sheet whose
    //    last field sat low in the body had that field 259 logical pixels under
    //    the keyboard with nothing to scroll, because the body's own scroll
    //    view had not been told the viewport shrank.
    //    The two bottom insets are taken as the LARGER of the pair rather than
    //    summed, because they describe the same strip of screen: the keyboard
    //    is drawn over the home indicator, so charging for both leaves a sheet
    //    one indicator height shorter than the room it has.
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = keyboardInset > viewPadding.bottom
        ? keyboardInset
        : viewPadding.bottom;
    final maxHeight =
        (MediaQuery.sizeOf(context).height - viewPadding.top - bottomInset) *
        0.85;

    // 2. Build the sheet panel with rounded top corners, lifted clear of the
    //    keyboard. `removeViewInsets` states that the inset is spent here, so a
    //    body widget reading `viewInsets.bottom` for itself does not reserve
    //    the same height a second time inside a panel that already moved.
    //
    //    The panel's own safe-area strip is whatever the keyboard has not
    //    already covered, for the same reason the two insets are not summed:
    //    the keyboard clears the home indicator, and a strip on top of it would
    //    read as an unexplained gap between the sheet's last control and the
    //    keys. A subtraction rather than a branch on `keyboardInset > 0`,
    //    because the inset descends through intermediate values as the keyboard
    //    DISMISSES: for the frames where it is smaller than the indicator, a
    //    branch drops the strip to zero and the last control sits on the
    //    indicator with nothing under it.
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: _buildPanel(
          theme,
          maxHeight,
          math.max(0.0, viewPadding.bottom - keyboardInset),
        ),
      ),
    );
  }

  /// The panel itself.
  ///
  /// [bottomSafeArea] is passed in rather than read here because the caller has
  /// already removed the keyboard inset from this subtree's [MediaQuery], and
  /// the home-indicator strip is a different inset that still applies.
  Widget _buildPanel(
    MagicStarterModalTheme theme,
    double maxHeight,
    double bottomSafeArea,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: WDiv(
        className:
            '${theme.containerClassName} w-full overflow-hidden rounded-t-2xl rounded-b-none',
        child: ModalSections(
          scrollable: scrollable,
          // 3. Drag handle indicator, only on a sheet that drags.
          top: showHandle
              ? Center(
                  child: WDiv(
                    // Semantic alias so the handle re-skins with the theme
                    // instead of hardcoded gray palette utilities.
                    className:
                        'w-9 h-1 bg-surface-container-high rounded-full mt-3 mb-1',
                  ),
                )
              : null,
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
          // 5. Body: scrolled by the panel, or handed the bounded height to
          //    scroll within itself (see [scrollable]).
          body: WDiv(className: theme.bodyClassName, child: body),
          // 6. Sticky footer.
          footer: footerBuilder != null
              ? Builder(
                  builder: (sheetContext) => WDiv(
                    key: footerKey,
                    className: theme.footerClassName,
                    child: footerBuilder!(sheetContext),
                  ),
                )
              : null,
          // 7. Bottom safe-area padding.
          bottom: SizedBox(height: bottomSafeArea),
        ),
      ),
    );
  }
}
