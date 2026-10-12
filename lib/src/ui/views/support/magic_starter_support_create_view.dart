import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_support_controller.dart';
import '../../components/button/index.dart';
import '../../components/card/index.dart';
import '../../components/form_field/index.dart';
import '../../components/input/index.dart';
import '../../components/page_scaffold/index.dart';
import '../../components/textarea/index.dart';

/// Opens a support conversation: a subject and a first message.
///
/// The conversation is recorded as opened from the app (`in_app`), and the
/// client names neither a team nor a user; the backend scopes it to whoever is
/// signed in. A refusal stays on this page with its message under the field it
/// concerns.
class MagicStarterSupportCreateView
    extends MagicStatefulView<MagicStarterSupportController> {
  const MagicStarterSupportCreateView({super.key});

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
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _body = TextEditingController();

  @override
  void onClose() {
    _subject.dispose();
    _body.dispose();
  }

  Future<void> _submit() async {
    final conversation = await controller.createConversation(
      subject: _subject.text.trim(),
      body: _body.text.trim(),
      source: 'in_app',
    );
    if (conversation == null) return;

    MagicRoute.to(
      MagicStarterConfig.supportThreadRoute().replaceFirst(
        ':id',
        '${conversation.id}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MSPageScaffold(
      title: trans('magic_starter.titles.support_create'),
      subtitle: trans('magic_starter.support.create_subtitle'),
      backLabel: trans('magic_starter.support.index_title'),
      backFallback: MagicStarterConfig.supportRoute(),
      children: [
        MSCard(
          child: WDiv(
            className: 'flex flex-col gap-4',
            children: [
              MSFormField(
                label: trans('magic_starter.support.subject_label'),
                error: controller.getError('subject'),
                child: MSInput(
                  controller: _subject,
                  placeholder: trans(
                    'magic_starter.support.subject_placeholder',
                  ),
                  fullWidth: true,
                ),
              ),
              MSFormField(
                label: trans('magic_starter.support.message_label'),
                error: controller.getError('body') ?? controller.writeError,
                child: MSTextarea(
                  controller: _body,
                  placeholder: trans(
                    'magic_starter.support.message_placeholder',
                  ),
                  minLines: 5,
                  fullWidth: true,
                ),
              ),
              WDiv(
                className: 'flex flex-row justify-end',
                child: MSButton(
                  onPressed: _submit,
                  isLoading: controller.isSubmitting,
                  child: WText(
                    trans('magic_starter.support.create_submit'),
                    className: 'text-center',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
