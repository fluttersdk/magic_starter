import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'feedback_card.dart';

/// Preview for [MSFeedbackCard].
///
/// Shows the on-demand form, which needs no eligibility answer to render. One
/// preview class per file; discovered by `previews:refresh`.
class FeedbackCardPreview extends StatelessWidget {
  /// Creates the MSFeedbackCard preview.
  const FeedbackCardPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const WDiv(
      className: 'flex flex-col gap-4 p-6 max-w-xl',
      children: [MSFeedbackCard(onDemand: true)],
    );
  }
}
