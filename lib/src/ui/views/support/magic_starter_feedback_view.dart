import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_feedback_controller.dart';
import '../../components/page_scaffold/index.dart';
import '../../widgets/magic_starter_feedback_card.dart';

/// The "Send feedback" page the profile menu opens.
///
/// The same 0-10 question as the occasional card, asked on demand: it is there
/// whenever `support_feedback` is on, whether or not the backend would show the
/// card right now. The card does the write through
/// [MagicStarterFeedbackController].
class MagicStarterFeedbackView
    extends MagicStatefulView<MagicStarterFeedbackController> {
  const MagicStarterFeedbackView({super.key});

  @override
  State<MagicStarterFeedbackView> createState() =>
      _MagicStarterFeedbackViewState();
}

class _MagicStarterFeedbackViewState
    extends
        MagicStatefulViewState<
          MagicStarterFeedbackController,
          MagicStarterFeedbackView
        > {
  @override
  Widget build(BuildContext context) {
    return MSPageScaffold(
      title: trans('magic_starter.titles.support_feedback'),
      subtitle: trans('magic_starter.support.feedback_subtitle'),
      backLabel: trans('magic_starter.support.index_title'),
      backFallback: MagicStarterConfig.supportRoute(),
      children: const [MagicStarterFeedbackCard(onDemand: true)],
    );
  }
}
