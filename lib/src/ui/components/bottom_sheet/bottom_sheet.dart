import 'package:flutter/material.dart' as m show Colors, showModalBottomSheet;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

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
/// await BottomSheet.show(
///   context,
///   title: 'Select action',
///   body: Column(children: [...]),
/// );
/// ```
@immutable
class BottomSheet extends StatelessWidget {
  /// Optional heading rendered at the top of the sheet.
  final String? title;

  /// Optional sub-heading rendered below [title].
  final String? description;

  /// Content widget rendered in the scrollable body area.
  final Widget body;

  /// Optional builder for the sticky footer; receives the sheet's own
  /// [BuildContext].
  final Widget Function(BuildContext sheetContext)? footerBuilder;

  /// Creates a [BottomSheet].
  const BottomSheet({
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
      builder: (_) => BottomSheet(
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

    // 1. Constrain sheet height to 85% of screen minus safe area.
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final maxHeight = (MediaQuery.sizeOf(context).height -
            viewPadding.top -
            viewPadding.bottom) *
        0.85;

    // 2. Build the sheet panel with rounded top corners.
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
                children: [
                  WDiv(
                    className: theme.bodyClassName,
                    child: body,
                  ),
                ],
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
            SizedBox(height: viewPadding.bottom),
          ],
        ),
      ),
    );
  }
}
