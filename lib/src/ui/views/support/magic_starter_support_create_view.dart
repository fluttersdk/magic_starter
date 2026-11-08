import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_support_controller.dart';
import '../../components/card/index.dart';
import '../../components/page_scaffold/index.dart';
import 'magic_starter_support_create_form.dart';
import 'magic_starter_support_message_bubble.dart';

/// Opens a support conversation: a topic and a first message.
///
/// The page chrome around [MagicStarterSupportCreateForm]: the scaffold, the
/// "How it works" column beside the form on a wide screen, and the hop to the
/// new thread once it is created. A refusal stays on this page with its message
/// under the field it concerns.
///
/// What the form takes (files, client info, article suggestions) is documented
/// on [MagicStarterSupportCreateForm].
class MagicStarterSupportCreateView
    extends MagicStatefulView<MagicStarterSupportController> {
  /// [pickFiles] stands in for the system file picker; it is a parameter only
  /// so a test can choose files without one.
  const MagicStarterSupportCreateView({
    super.key,
    @visibleForTesting this.pickFiles,
  });

  final Future<List<MagicFile>> Function(List<String> extensions)? pickFiles;

  @override
  State<MagicStarterSupportCreateView> createState() =>
      _MagicStarterSupportCreateViewState();
}

class _MagicStarterSupportCreateViewState
    extends
        MagicStatefulViewState<
          MagicStarterSupportController,
          MagicStarterSupportCreateView
        > {
  /// Width of the "How it works" column beside the form on a wide screen.
  static const double _sideWidth = 300;

  /// Keeps the form's draft when a resize crosses `lg` and moves it between the
  /// row and the column.
  final GlobalKey _formKey = GlobalKey();

  @override
  void onInit() {
    controller.forgetWriteError();
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = wScreenIs(context, 'lg');

    return MSPageScaffold(
      title: trans('magic_starter.titles.support_create'),
      subtitle: trans('magic_starter.support.create_subtitle'),
      backLabel: trans('magic_starter.support.index_title'),
      backFallback: MagicStarterConfig.supportRoute(),
      children: [
        wide
            ? WDiv(
                className: 'flex flex-row items-start gap-6',
                children: [
                  Expanded(child: _buildForm()),
                  SizedBox(width: _sideWidth, child: _buildHowItWorks(wide)),
                ],
              )
            : WDiv(
                className: 'flex flex-col gap-4',
                children: [_buildHowItWorks(wide), _buildForm()],
              ),
      ],
    );
  }

  Widget _buildForm() {
    return MagicStarterSupportCreateForm(
      key: _formKey,
      pickFiles: widget.pickFiles,
      onCreated: (conversation) =>
          MagicRoute.to(MagicStarterConfig.supportThreadPath(conversation.id)),
    );
  }

  Widget _buildHowItWorks(bool wide) {
    if (!wide) {
      return MSCard(
        child: WDiv(
          className: 'flex flex-row items-center gap-2.5',
          children: [
            const MagicStarterSupportSenderAvatar(senderType: 'ai'),
            Flexible(
              child: WText(
                trans('magic_starter.support.how_short'),
                className: 'text-sm text-fg',
              ),
            ),
          ],
        ),
      );
    }

    return MSCard(
      child: WDiv(
        className: 'flex flex-col gap-3.5',
        children: [
          const MagicStarterSupportSenderAvatar(senderType: 'ai'),
          WText(
            trans('magic_starter.support.how_title'),
            className: 'text-sm font-semibold text-fg',
          ),
          for (var step = 1; step <= 3; step++) _buildStep(step),
        ],
      ),
    );
  }

  Widget _buildStep(int number) {
    return WDiv(
      className: 'flex flex-row items-start gap-2.5',
      children: [
        WDiv(
          className:
              'w-6 h-6 shrink-0 rounded-full flex items-center '
              'justify-center bg-ai-soft',
          child: WText(
            '$number',
            className: 'text-xs font-bold text-ai-soft-foreground',
          ),
        ),
        Flexible(
          child: WText(
            trans('magic_starter.support.how_step_$number'),
            className: 'text-sm text-fg',
          ),
        ),
      ],
    );
  }
}
