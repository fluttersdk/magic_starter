import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'accordion.recipe.dart';

// Icon for collapsed/expanded state — extracted as static const for web tree-shaking.
const _kIconExpanded = Icons.keyboard_arrow_up;
const _kIconCollapsed = Icons.keyboard_arrow_down;

/// A single item within an [MSAccordion].
///
/// Carries the [title] shown in the trigger row and the [body] widget displayed
/// in the collapsible panel.
@immutable
class MSAccordionItem {
  /// The title text displayed in the trigger row.
  final String title;

  /// The widget rendered inside the collapsible panel.
  final Widget body;

  /// Creates an [MSAccordionItem].
  const MSAccordionItem({required this.title, required this.body});
}

/// A recipe-driven accordion component for Magic Starter.
///
/// Renders a vertical stack of collapsible items. Each item has a trigger
/// header and a collapsible panel. Only one item can be expanded at a time
/// (single-open). Expanding an already-open item collapses it.
///
/// ### Example Usage:
///
/// ```dart
/// MSAccordion(
///   items: [
///     MSAccordionItem(
///       title: 'What is Magic Starter?',
///       body: WText('A Flutter starter kit built on the Magic framework.'),
///     ),
///     MSAccordionItem(
///       title: 'What features are included?',
///       body: WText('13 opt-in features including auth, teams, and notifications.'),
///     ),
///   ],
/// )
/// ```
class MSAccordion extends StatefulWidget {
  /// The list of accordion items to render.
  final List<MSAccordionItem> items;

  /// Per-slot className overrides appended after the recipe output.
  final Map<String, String>? classNames;

  /// Creates an [MSAccordion] widget.
  const MSAccordion({super.key, required this.items, this.classNames});

  @override
  State<MSAccordion> createState() => _AccordionState();
}

class _AccordionState extends State<MSAccordion> {
  /// Index of the currently expanded item, or `-1` when all are collapsed.
  int _expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // 1. Resolve slot classNames from the recipe.
    final slots = accordionRecipe(classNames: widget.classNames);

    // 2. Build the root container.
    //    LayoutBuilder provides a bounded width so child items can use
    //    flex-row safely. This mirrors how Card handles full-bleed content.
    return WDiv(
      className: slots['root'],
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(
              widget.items.length,
              (index) => _buildItem(index, slots),
            ),
          );
        },
      ),
    );
  }

  /// Builds a single accordion item at [index].
  Widget _buildItem(int index, Map<String, String> slots) {
    final bool isExpanded = _expandedIndex == index;
    final MSAccordionItem item = widget.items[index];

    return WDiv(
      className: slots['item'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row — tappable trigger.
          _buildTrigger(index, isExpanded, item.title, slots),
          // Collapsible panel — only rendered when this item is expanded.
          if (isExpanded) WDiv(className: slots['panel'], child: item.body),
        ],
      ),
    );
  }

  /// Builds the tappable trigger row that toggles [index]'s expansion state.
  Widget _buildTrigger(
    int index,
    bool isExpanded,
    String title,
    Map<String, String> slots,
  ) {
    return WAnchor(
      onTap: () {
        setState(() {
          // Toggle: collapse if already open, expand otherwise.
          _expandedIndex = isExpanded ? -1 : index;
        });
      },
      child: WDiv(
        className: slots['trigger'],
        children: [
          WDiv(className: 'flex-1', child: WText(title)),
          Icon(isExpanded ? _kIconExpanded : _kIconCollapsed, size: 18),
        ],
      ),
    );
  }
}
