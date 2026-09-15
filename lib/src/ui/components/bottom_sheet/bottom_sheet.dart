import 'dart:math' as math;

import 'package:flutter/material.dart' as m show Colors, showModalBottomSheet;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_theme.dart';
import '../../../facades/magic_starter.dart';

/// A reusable bottom-sheet component with Wind UI chrome driven by
/// `MagicStarter.manager.modalTheme` tokens.
///
/// Provides an optional header (title + description), a scrollable body, and
/// an optional sticky footer. The bottom sheet slides up from the screen edge
/// with a rounded top radius.
///
/// All classNames are read from the modal theme at build time; override via
/// `MagicStarter.useModalTheme()` before the first bottom sheet is shown.
///
/// ### Example
/// ```dart
/// await MSBottomSheet.show(
///   context,
///   title: 'Select action',
///   body: Column(children: [...]),
/// );
/// ```
@immutable
class MSBottomSheet extends StatelessWidget {
  /// Optional heading rendered at the top of the sheet.
  final String? title;

  /// Optional sub-heading rendered below [title].
  final String? description;

  /// Content widget rendered in the scrollable body area.
  final Widget body;

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
  });

  /// Opens the bottom sheet and resolves when it is dismissed.
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? description,
    required Widget body,
    Widget Function(BuildContext sheetContext)? footerBuilder,
  }) {
    return m.showModalBottomSheet<T>(
      context: context,
      backgroundColor: m.Colors.transparent,
      isScrollControlled: true,
      // Present on the root navigator so the sheet + scrim span the whole
      // viewport and anchor to the real screen bottom. Shown on the shell's
      // content navigator the overlay is confined to the content area, which
      // left the sheet floating with a bottom gap on tall/wide screens.
      useRootNavigator: true,
      builder: (_) => MSBottomSheet(
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
          context,
          theme,
          maxHeight,
          math.max(0.0, viewPadding.bottom - keyboardInset),
        ),
      ),
    );
  }

  /// The sheet panel itself: handle, optional header, scrollable body, optional
  /// sticky footer, and the bottom safe-area strip.
  ///
  /// [bottomSafeArea] is passed in rather than read here because the caller has
  /// already removed the keyboard inset from this subtree's [MediaQuery], and
  /// the home-indicator strip is a different inset that still applies.
  Widget _buildPanel(
    BuildContext context,
    MagicStarterModalTheme theme,
    double maxHeight,
    double bottomSafeArea,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: WDiv(
        className:
            '${theme.containerClassName} w-full overflow-hidden rounded-t-2xl rounded-b-none',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3. Drag handle indicator.
            Center(
              child: WDiv(
                // Semantic alias so the handle re-skins with the theme instead
                // of hardcoded gray palette utilities.
                className:
                    'w-9 h-1 bg-surface-container-high rounded-full mt-3 mb-1',
              ),
            ),
            // 4. Header section: title + description.
            if (title != null || description != null)
              WDiv(
                className: theme.headerClassName,
                children: [
                  if (title != null)
                    WText(title!, className: theme.titleClassName),
                  if (description != null)
                    WText(description!, className: theme.descriptionClassName),
                ],
              ),
            // 5. Scrollable body.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [WDiv(className: theme.bodyClassName, child: body)],
              ),
            ),
            // 6. Sticky footer.
            if (footerBuilder != null)
              Builder(
                builder: (sheetContext) => WDiv(
                  key: const Key('bottom_sheet_footer'),
                  className: theme.footerClassName,
                  child: footerBuilder!(sheetContext),
                ),
              ),
            // 7. Bottom safe-area padding.
            SizedBox(height: bottomSafeArea),
          ],
        ),
      ),
    );
  }
}
