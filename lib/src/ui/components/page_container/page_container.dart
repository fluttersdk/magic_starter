import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../facades/magic_starter.dart';
import 'page_container.recipe.dart';

/// **The Shared Page Container**
///
/// One source of truth for how wide a page is and how far its content sits from
/// the edges of the shell. Every authenticated page, whether it ships in this
/// package or in the host app, goes through this container, so there is exactly
/// one answer per app instead of one answer per surface.
///
/// The geometry itself is NOT decided here. It comes from
/// `MagicStarterManager.pageContainerClassName`, which the host sets once in a
/// service provider. That indirection is the whole point: this package's pages
/// render inside the HOST's shell, so a cap or an edge margin chosen here is a
/// guess about someone else's layout. Two containers each holding their own
/// guess is what made the starter's settings pages centre 64px further out per
/// side than the host's own pages, and the team pages spread edge to edge with
/// no cap at all.
///
/// The container owns geometry only. It deliberately does NOT own a scroll view
/// or a page background: the shell's content region already scrolls and paints,
/// and a second scrollable here would contend with it. [MSPageScaffold] is the
/// composition that adds both for pages that want the full treatment.
///
/// ### Safe area
///
/// The horizontal insets are guarded so content never slides under a rounded
/// display corner. Top and bottom are left to the shell, which owns the status
/// bar and the bottom navigation and already clears them.
///
/// ### Example
/// ```dart
/// MSPageContainer(
///   children: [
///     MSPageHeader(title: 'Monitors'),
///     MSCard(child: monitorList),
///   ],
/// )
/// ```
@immutable
class MSPageContainer extends StatelessWidget {
  /// The page content, when the page is one widget.
  ///
  /// Mutually exclusive with [children].
  final Widget? child;

  /// The page content, when the page is a stacked list of sections.
  ///
  /// Mutually exclusive with [child].
  final List<Widget>? children;

  /// Optional per-page className appended after the shared geometry so a page
  /// can tune one axis without losing (or restating) the rest.
  final String? className;

  /// Creates a [MSPageContainer] around [child] or [children].
  const MSPageContainer({super.key, this.child, this.children, this.className})
    : assert(
        child == null || children == null,
        'MSPageContainer: Cannot provide both child and children.',
      ),
      assert(
        child != null || children != null,
        'MSPageContainer: Provide either child or children.',
      );

  @override
  Widget build(BuildContext context) {
    // 1. Resolve the geometry the host chose for every page in this app, then
    //    append whatever this page tunes on top of it.
    final String containerClassName = pageContainerRecipe(
      hostClassName: MagicStarter.manager.pageContainerClassName,
      className: className,
    );

    // 2. Guard the horizontal display insets; the shell owns top and bottom.
    return SafeArea(
      top: false,
      bottom: false,
      child: child != null
          ? WDiv(className: containerClassName, child: child)
          : WDiv(className: containerClassName, children: children),
    );
  }
}
