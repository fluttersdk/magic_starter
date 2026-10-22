import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../theme/magic_starter_breakpoints.dart';
import 'master_detail.recipe.dart';

/// **A list and its selected item, side by side from a breakpoint up.**
///
/// From [breakpoint] (`lg`, 1024 px, by default) the [master] list sits in a
/// fixed column with the [detail] beside it. Below it there is room for one
/// of them, so the widget renders [detail] when there is one and [master]
/// otherwise, which is push navigation when the selection lives in the route:
///
/// | Route | From `lg` | Below `lg` |
/// |---|---|---|
/// | `/stock` | list, [placeholder] | list |
/// | `/stock/42` | list, item 42 | item 42, back returns to `/stock` |
///
/// So a list row navigates (`MagicRoute.to('/stock/42')`) at every width and
/// the page builds this widget with the item it was routed to. Selection,
/// highlighting and loading stay with the page; this widget only lays out.
///
/// It owns no page geometry and no scroll: it goes inside the page container,
/// as a child of `MSPageScaffold` (or `MSPageContainer`), and both columns
/// scroll with the page. A page that changes more than the body between the
/// two layouts (the title, a back control the split view does not need) asks
/// [isSplit] with the same breakpoint.
///
/// ### Example
/// ```dart
/// MSPageScaffold(
///   title: 'Stock',
///   children: [
///     MSMasterDetail(
///       master: StockList(selectedId: productId),
///       detail: productId == null ? null : ProductDetail(id: productId),
///       placeholder: const MSEmptyState(title: 'Pick a product'),
///     ),
///   ],
/// )
/// ```
@immutable
class MSMasterDetail extends StatelessWidget {
  /// The list. Rendered in the list column from [breakpoint] up, and alone
  /// below it while there is no [detail].
  final Widget master;

  /// The selected item, or null when nothing is selected.
  ///
  /// Below [breakpoint] a non-null detail replaces the list.
  final Widget? detail;

  /// What the detail column shows from [breakpoint] up while [detail] is null.
  ///
  /// Null leaves the column empty. Never shown below the breakpoint, where the
  /// list is on screen instead.
  final Widget? placeholder;

  /// The Wind breakpoint name from which both columns show. Defaults to `'lg'`,
  /// the shell's own `navigationBreakpoint` default, so the split starts where
  /// the sidebar does.
  final String breakpoint;

  /// Extra className for the split row, appended after the recipe.
  final String? className;

  /// Extra className for the list column, appended after the recipe's `w-96`
  /// (a `w-80` here makes the column narrower).
  final String? masterClassName;

  /// Extra className for the detail column, appended after the recipe.
  final String? detailClassName;

  /// Creates a [MSMasterDetail].
  const MSMasterDetail({
    super.key,
    required this.master,
    this.detail,
    this.placeholder,
    this.breakpoint = 'lg',
    this.className,
    this.masterClassName,
    this.detailClassName,
  });

  /// Whether the screen is wide enough for both columns at [breakpoint].
  ///
  /// The same answer the widget acts on, for a page that also changes its
  /// header between the two layouts.
  ///
  /// Throws a [StateError] when the Wind theme carries no [breakpoint], since
  /// an unknown name would otherwise collapse the layout at every width.
  static bool isSplit(BuildContext context, {String breakpoint = 'lg'}) {
    return MagicStarterBreakpoints.isAtLeast(
      context,
      breakpoint,
      setting: 'MSMasterDetail.breakpoint',
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. One column of room: the selected item when there is one, as a pushed
    //    page would show it, otherwise the list.
    if (!isSplit(context, breakpoint: breakpoint)) {
      return detail ?? master;
    }

    // 2. Both columns: the list at a fixed width, the detail (or what stands
    //    in for it) taking the rest.
    return WDiv(
      className: masterDetailSplitRecipe(className: className),
      children: [
        WDiv(
          className: masterDetailMasterColumnRecipe(className: masterClassName),
          child: master,
        ),
        WDiv(
          className: masterDetailDetailColumnRecipe(className: detailClassName),
          child: detail ?? placeholder ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}
