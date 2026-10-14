import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_support_controller.dart';
import '../../components/button/index.dart';
import '../../components/card/index.dart';
import '../../components/form_field/index.dart';
import '../../components/page_scaffold/index.dart';
import '../../components/textarea/index.dart';
import 'magic_starter_support_attachments.dart';
import 'magic_starter_support_index_view.dart';
import 'magic_starter_support_message_bubble.dart';

/// Opens a support conversation: a topic and a first message.
///
/// The customer picks a topic chip and writes one message; the backend derives
/// the subject from it, so none is asked for. The conversation is recorded as
/// opened from the app (`in_app`), and the client names neither a team nor a
/// user; the backend scopes it to whoever is signed in. A refusal stays on this
/// page with its message under the field it concerns.
///
/// Behind `support_attachments` the form also takes image and PDF files, which
/// may stand in for the message text.
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
        >
    with MagicStarterSupportAttachmentPicking<MagicStarterSupportCreateView> {
  static const Map<String, IconData> _topicIcons = {
    'billing': Icons.credit_card,
    'technical': Icons.build_outlined,
    'account': Icons.person_outline,
    'sales': Icons.star_outline,
    'other': Icons.more_horiz,
  };
  static const _iconSend = Icons.send;
  static const _iconAttach = Icons.attach_file;

  /// Width of the "How it works" column beside the form on a wide screen.
  static const double _sideWidth = 300;

  final TextEditingController _body = TextEditingController();

  String? _topic;

  @override
  Future<List<MagicFile>> Function(List<String> extensions)?
  get pickFilesOverride => widget.pickFiles;

  @override
  void onInit() => controller.forgetWriteError();

  @override
  void onClose() => _body.dispose();

  Future<void> _submit() async {
    final conversation = await controller.createConversation(
      topic: _topic,
      body: _body.text.trim(),
      source: 'in_app',
      attachments: pickedAttachments,
    );
    if (conversation == null) return;

    MagicRoute.to(MagicStarterConfig.supportThreadPath(conversation.id));
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
                  Expanded(child: _buildForm(wide)),
                  SizedBox(width: _sideWidth, child: _buildHowItWorks(wide)),
                ],
              )
            : WDiv(
                className: 'flex flex-col gap-4',
                children: [_buildHowItWorks(wide), _buildForm(wide)],
              ),
      ],
    );
  }

  Widget _buildForm(bool wide) {
    return MSCard(
      child: WDiv(
        className: 'flex flex-col gap-5',
        children: [
          MSFormField(
            label: trans('magic_starter.support.topic_label'),
            error: controller.getError('topic'),
            child: WDiv(
              className: 'flex flex-row wrap gap-2',
              children: [
                for (final topic in controller.topics) _buildChip(topic),
              ],
            ),
          ),
          MSFormField(
            label: trans('magic_starter.support.message_label'),
            error: controller.getError('body') ?? controller.writeError,
            child: WDiv(
              className: 'flex flex-col gap-1.5',
              children: [
                MSTextarea(
                  controller: _body,
                  placeholder: trans(
                    'magic_starter.support.message_placeholder',
                  ),
                  minLines: 6,
                  fullWidth: true,
                ),
                _buildCounter(),
              ],
            ),
          ),
          if (MagicStarterConfig.hasSupportAttachmentsFeatures())
            _buildAttachments(),
          _buildFooter(wide),
        ],
      ),
    );
  }

  Widget _buildAttachments() {
    return MSFormField(
      label: trans('magic_starter.support.attachments_label'),
      hint: trans('magic_starter.support.attachments_hint', {
        'max': MagicStarterConfig.supportAttachmentMaxFiles(),
        'size': MagicStarterConfig.supportAttachmentMaxBytes() ~/ (1024 * 1024),
      }),
      error: magicStarterSupportAttachmentError(controller),
      child: WDiv(
        className: 'flex flex-col items-start gap-2',
        children: [
          MSButton(
            key: const ValueKey<String>('support-attach'),
            intent: ButtonIntent.secondary,
            onPressed: pickAttachments,
            child: WDiv(
              className: 'flex flex-row items-center justify-center gap-2',
              children: [
                WIcon(_iconAttach, className: 'text-sm'),
                WText(trans('magic_starter.support.attach_button')),
              ],
            ),
          ),
          MagicStarterSupportPickedChips(
            files: pickedAttachments,
            onRemove: removeAttachment,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String topic) {
    final bool selected = topic == _topic;
    final IconData? icon = _topicIcons[topic];

    final String tone = selected
        ? 'border-primary-600 dark:border-primary-500 bg-primary-container'
        : 'border-color-border bg-surface-container-high';

    return WAnchor(
      key: ValueKey<String>('support-topic-$topic'),
      onTap: () => setState(() => _topic = topic),
      child: WDiv(
        className:
            'flex flex-row items-center gap-2 h-[38px] px-3.5 rounded-xl '
            'border $tone',
        children: [
          if (icon != null) WIcon(icon, className: 'text-sm text-fg'),
          WText(
            magicStarterSupportTopicLabel(topic),
            className: 'text-sm font-medium text-fg',
          ),
        ],
      ),
    );
  }

  Widget _buildCounter() {
    return ListenableBuilder(
      listenable: _body,
      builder: (context, _) => WDiv(
        className: 'flex flex-row justify-end',
        child: WText(
          '${_body.text.runes.length} / ${MagicStarterConfig.supportMessageMaxLength()}',
          className: 'text-xs text-fg-disabled',
        ),
      ),
    );
  }

  Widget _buildFooter(bool wide) {
    final Widget privacy = WText(
      trans('magic_starter.support.privacy_note'),
      className: 'text-xs text-fg-muted',
    );
    final Widget send = MSButton(
      onPressed: _submit,
      isLoading: controller.isSubmitting,
      fullWidth: !wide,
      child: WDiv(
        className: 'flex flex-row items-center justify-center gap-2',
        children: [
          Flexible(
            child: WText(
              trans('magic_starter.support.create_submit'),
              className: 'text-center',
            ),
          ),
          WIcon(_iconSend, className: 'text-sm'),
        ],
      ),
    );

    if (wide) {
      return WDiv(
        className: 'flex flex-row items-center justify-between gap-3',
        children: [
          Flexible(child: privacy),
          send,
        ],
      );
    }

    return WDiv(className: 'flex flex-col gap-3', children: [send, privacy]);
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
