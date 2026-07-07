import 'package:flutter/widgets.dart';

import '../components/card/card.dart';

export '../components/card/card.dart' show MSCard, CardVariant;

/// Thin backwards-compatible alias for the migrated [MSCard] component.
///
/// The card moved to the canonical atomic-component folder
/// (`lib/src/ui/components/card/`) as part of the design-system migration.
/// This subclass preserves the historic `MagicStarterCard` name, constructor
/// signature, and barrel export path so existing callers and the widget test
/// suite (`find.byType(MagicStarterCard)`) stay untouched. New code should
/// import [MSCard] directly.
@immutable
class MagicStarterCard extends MSCard {
  /// Creates a [MagicStarterCard] (alias of [MSCard]).
  const MagicStarterCard({
    super.key,
    required super.child,
    super.title,
    super.className,
    super.noPadding,
    super.variant,
  });
}
