import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'usage_meter.recipe.dart';

/// Tone for a usage meter, tracking how close a resource is to its limit.
///
/// Follows `BadgeTone`'s vocabulary (`success`/`warning`/`destructive`)
/// rather than a product's own status language: a shared component ships to
/// every adopter, and "up"/"degraded"/"down" is one consumer's monitoring
/// vocabulary, not this package's.
enum UsageMeterTone {
  /// Comfortable headroom.
  success,

  /// Past 80% of the limit.
  warning,

  /// At or over the limit.
  destructive,
}

/// **A single resource's usage against its plan limit.**
///
/// Shows the [label], a `used / limit` readout (the limit renders as the
/// infinity glyph when [limit] is null), and a tone-coded bar: `success` with
/// headroom, `warning` past 80%, `destructive` at or over the limit (a
/// non-positive [limit] also reads `destructive`; see the ratio comment in
/// [build]). This component knows nothing about WHAT is being metered; a
/// consumer feeds it a label and a used/limit pair for whichever resource
/// (checks, monitors, seats, ...) it wants to show.
///
/// ### Why [formatNumber] is required, with no default
///
/// This is the load-bearing decision of the port: a default would silently
/// re-ship a defect this repository has already shipped and fixed. Number
/// formatting is locale-specific (a thousands separator is `,` in English and
/// `.` in Turkish), and this package cannot know the consumer's locale
/// convention. The origin app's own fix log records exactly this bug: "two
/// byte-identical private copies of this, in `UsageMeter` and
/// `PlanBillingView`, both hardcoding a comma; a Turkish billing page
/// reported `83,365 checks`" (see the origin repo's
/// `lib/app/support/formatters.dart`, around the `formatCount` helper).
/// A hardcoded separator here would put that same defect into every app that
/// installs this package. So there is no default: the caller supplies
/// [formatNumber], and a consumer with no locale-aware formatter can pass
/// `(n) => n.toString()` explicitly, which is a visible choice rather than a
/// silent one.
///
/// ### Example:
/// ```dart
/// MSUsageMeter(
///   label: 'Monitors',
///   used: 4,
///   limit: 50,
///   formatNumber: (n) => n.toString(),
/// )
/// MSUsageMeter(
///   label: 'Monitors',
///   used: 420,
///   limit: null, // unlimited
///   formatNumber: (n) => n.toString(),
/// )
/// ```
@immutable
class MSUsageMeter extends StatelessWidget {
  /// Resource name shown on the left.
  final String label;

  /// Amount consumed so far.
  final int used;

  /// Plan limit; null means unlimited (no bar fill to speak of, infinity readout).
  final int? limit;

  /// Optional short suffix on the numbers, e.g. "min".
  final String? unit;

  /// Renders [used] and the resolved [limit] as a display string.
  ///
  /// Required, with no default: see the class docblock for why a locale-aware
  /// formatter cannot be assumed by this package.
  final String Function(int) formatNumber;

  /// Optional extra classNames appended to the root slot.
  final String? className;

  /// Creates an [MSUsageMeter].
  const MSUsageMeter({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
    required this.formatNumber,
    this.unit,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    final lim = limit;
    final unlimited = lim == null;

    // 1. Resolve the consumed ratio. A limit of zero (or, defensively, a
    //    negative one, which is not a shape this widget was asked to render
    //    but must not crash on either) means the plan includes NONE of this
    //    resource. That is the DEFAULT state for every user on such a plan,
    //    not an edge case: `used / 0` is a division by zero (`0 / 0` is NaN
    //    in Dart, not zero), and a NaN ratio fails `FractionallySizedBox`'s
    //    own `widthFactor >= 0.0` assert. The honest render for "this plan
    //    includes none of it" is a full bar at the at-limit tone, so a
    //    non-positive limit resolves to a ratio of 1.0 rather than reaching
    //    the division at all.
    final double ratio;
    if (unlimited) {
      ratio = 0.0;
    } else if (lim <= 0) {
      ratio = 1.0;
    } else {
      ratio = math.min(1.0, used / lim);
    }

    // 2. Resolve the tone and the recipe slots from the ratio.
    final tone = unlimited
        ? UsageMeterTone.success
        : ratio >= 1
            ? UsageMeterTone.destructive
            : ratio >= 0.8
                ? UsageMeterTone.warning
                : UsageMeterTone.success;
    final slots = usageMeterRecipe(variants: {kUsageMeterToneAxis: tone.name});

    // 3. Resolve the fill width and the display strings.
    final widthFactor = unlimited ? 0.04 : math.max(0.02, ratio);
    final suffix = unit != null ? ' $unit' : '';
    final limitText = unlimited ? '∞' : '${formatNumber(lim)}$suffix';

    return WDiv(
      className:
          className == null ? slots['root'] : '${slots['root']} $className',
      children: [
        WDiv(
          className: slots['head'],
          children: [
            WText(label, className: slots['label']),
            WText(
              '${formatNumber(used)}$suffix / $limitText',
              className: slots['readout'],
            ),
          ],
        ),
        WDiv(
          className: slots['track'],
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFactor,
            child: WDiv(
              className: slots['bar'],
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}
