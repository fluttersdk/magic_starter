import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The share of the body's scroll viewport the header may take and still
/// stay pinned above the body.
///
/// A taller header (a phone in landscape, the keyboard up, a large text size,
/// a long description) scrolls away with the body instead, so the body keeps
/// room to show and the footer, which holds the actions, keeps its place.
const double kModalPinnedHeaderShare = 0.5;

/// The column every starter modal lays out: [top], [header], [body],
/// [footer] and [bottom], with the footer fixed under a scrolling body.
///
/// Package-internal; `MSDialog`'s shell and `MSBottomSheetPanel` both use it.
/// With [scrollable], the header and the body share one scroll view and the
/// header stays pinned while it takes at most [kModalPinnedHeaderShare] of the
/// viewport. That choice is made at layout, from the header's measured
/// height, so crossing it rebuilds nothing: a focused field in the body keeps
/// its focus and the body keeps its scroll offset while the keyboard rises.
/// Without [scrollable], the header stays fixed and the body gets the bounded
/// height left to scroll in itself. [body] arrives already wrapped in its
/// padding.
class ModalSections extends StatelessWidget {
  /// Drawn above the header (the sheet's drag handle).
  final Widget? top;

  /// The title and description block.
  final Widget? header;

  /// The padded body.
  final Widget body;

  /// The sticky footer.
  final Widget? footer;

  /// Drawn under the footer (the sheet's safe-area strip).
  final Widget? bottom;

  /// Whether the body is scrolled for it; see `MSDialog.scrollable`.
  final bool scrollable;

  /// Creates a [ModalSections].
  const ModalSections({
    super.key,
    this.top,
    this.header,
    required this.body,
    this.footer,
    this.bottom,
    required this.scrollable,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? header = this.header;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?top,
        if (!scrollable) ?header,
        Flexible(
          child: scrollable
              ? CustomScrollView(
                  // Not primary, so it is not always scrollable: a body that
                  // fits leaves a drag to the sheet around it.
                  primary: false,
                  shrinkWrap: true,
                  slivers: [
                    if (header != null) _ModalHeaderSliver(child: header),
                    _ModalBodySliver(child: body),
                  ],
                )
              : body,
        ),
        ?footer,
        ?bottom,
      ],
    );
  }
}

/// The body sliver: a box adapter that paints nothing under a pinned header.
///
/// The header has no background of its own (`headerClassName` is padding), so
/// the part of the body the header overlaps (the viewport's `overlap`) is
/// clipped away instead of painted over, whatever the theme's colours.
class _ModalBodySliver extends SingleChildRenderObjectWidget {
  const _ModalBodySliver({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderModalBodySliver();
}

class _RenderModalBodySliver extends RenderSliverToBoxAdapter {
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    final double overlap = constraints.overlap;
    if (overlap <= 0 || geometry == null) {
      _clip.layer = null;
      super.paint(context, offset);

      return;
    }

    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTWH(
        0,
        overlap,
        constraints.crossAxisExtent,
        math.max(0, geometry!.paintExtent - overlap),
      ),
      super.paint,
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

/// A header sliver that stays pinned while it fits [kModalPinnedHeaderShare]
/// of the viewport and scrolls like a box adapter otherwise.
class _ModalHeaderSliver extends SingleChildRenderObjectWidget {
  const _ModalHeaderSliver({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderModalHeaderSliver();
}

class _RenderModalHeaderSliver extends RenderSliverSingleBoxAdapter {
  bool _pinned = false;

  @override
  void performLayout() {
    final RenderBox? box = child;
    if (box == null) {
      geometry = SliverGeometry.zero;

      return;
    }

    // 1. Measure the header at the viewport's width.
    box.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final double extent = box.size.height;

    // 2. Pin it only while it leaves the body most of the viewport.
    final bool pinned =
        extent <= constraints.viewportMainAxisExtent * kModalPinnedHeaderShare;
    if (pinned != _pinned) {
      _pinned = pinned;
      markNeedsSemanticsUpdate();
    }

    if (_pinned) {
      // The geometry of the SDK's `PinnedHeaderSliver`: `paintOrigin` takes
      // the overlap an overscroll hands the first sliver, so the header holds
      // still while the body bounces or stretches under it.
      final double paintExtent = math.min(
        extent,
        constraints.remainingPaintExtent - constraints.overlap,
      );
      geometry = SliverGeometry(
        scrollExtent: extent,
        paintOrigin: constraints.overlap,
        paintExtent: paintExtent,
        layoutExtent: clampDouble(
          extent - constraints.scrollOffset,
          0,
          constraints.remainingPaintExtent,
        ),
        maxPaintExtent: extent,
        maxScrollObstructionExtent: extent,
        cacheExtent: calculateCacheOffset(constraints, from: 0, to: extent),
        hasVisualOverflow: true,
      );
    } else {
      final double paintExtent = calculatePaintOffset(
        constraints,
        from: 0,
        to: extent,
      );
      geometry = SliverGeometry(
        scrollExtent: extent,
        paintExtent: paintExtent,
        cacheExtent: calculateCacheOffset(constraints, from: 0, to: extent),
        maxPaintExtent: extent,
        hasVisualOverflow:
            extent > constraints.remainingPaintExtent ||
            constraints.scrollOffset > 0,
      );
    }

    // 3. A pinned header paints at the viewport's top edge, over the body.
    (box.parentData! as SliverPhysicalParentData).paintOffset = Offset(
      0,
      childMainAxisPosition(box),
    );
  }

  @override
  double childMainAxisPosition(RenderBox child) =>
      _pinned ? 0 : -constraints.scrollOffset;

  /// A pinned header is read as its own node, outside the scrolling one, as
  /// the SDK's `PinnedHeaderSliver` is.
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    if (_pinned) {
      config.addTagForChildren(RenderViewport.excludeFromScrolling);
    }
  }
}
