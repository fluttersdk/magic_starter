import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_support_controller.dart';
import '../../../models/magic_starter_support_conversation.dart';
import '../../../support/support_client_context.dart';
import '../../components/button/index.dart';
import '../../components/card/index.dart';
import '../../components/form_field/index.dart';
import '../../components/textarea/index.dart';
import 'magic_starter_support_article_card.dart';
import 'magic_starter_support_attachments.dart';
import 'magic_starter_support_index_view.dart';
import 'magic_starter_support_thread_body.dart'
    show MagicStarterSupportControllerRebuild;

/// The form that opens a support conversation: a topic and a first message.
///
/// The customer picks a topic chip and writes one message; the backend derives
/// the subject from it, so none is asked for. The conversation is recorded as
/// opened from the app (`in_app`), and the client names neither a team nor a
/// user; the backend scopes it to whoever is signed in. A refusal stays on the
/// form with its message under the field it concerns.
///
/// Behind `support_attachments` the form also takes image and PDF files, which
/// may stand in for the message text.
///
/// Behind `support_client_context` the conversation carries the client info
/// ([MagicStarterSupportClientContext]).
///
/// While the customer writes, up to three knowledge-base articles that match
/// the message appear above Send. The lookup waits until the message has 12
/// characters and the typing has paused, and a failed one shows nothing.
///
/// A part for the create page and the chat panel alike: it reads no route,
/// never navigates (the host acts on [onCreated]) and does not clear errors
/// when it mounts, so opening it elsewhere never wipes the page's errors.
class MagicStarterSupportCreateForm extends StatefulWidget {
  const MagicStarterSupportCreateForm({
    super.key,
    required this.onCreated,
    this.surface = 'page',
    this.compact = false,
    this.pickFiles,
  });

  /// Called with the conversation the backend created.
  final void Function(MagicStarterSupportConversation conversation) onCreated;

  /// The write lock the submit takes (see
  /// [MagicStarterSupportController.isSubmittingFor]).
  final String surface;

  /// Fits a bounded panel: no card, only the fields scroll, and Send with the
  /// privacy note (always under it, never beside it) stays pinned below them.
  /// The host must give it a bounded height.
  final bool compact;

  /// Stands in for the system file picker; a parameter only so a test can
  /// choose files without one.
  final Future<List<MagicFile>> Function(List<String> extensions)? pickFiles;

  @override
  State<MagicStarterSupportCreateForm> createState() =>
      _MagicStarterSupportCreateFormState();
}

class _MagicStarterSupportCreateFormState
    extends State<MagicStarterSupportCreateForm>
    with
        MagicStarterSupportControllerRebuild<MagicStarterSupportCreateForm>,
        MagicStarterSupportAttachmentPicking<MagicStarterSupportCreateForm> {
  static const Map<String, IconData> _topicIcons = {
    'billing': Icons.credit_card,
    'technical': Icons.build_outlined,
    'account': Icons.person_outline,
    'sales': Icons.star_outline,
    'other': Icons.more_horiz,
  };
  static const _iconSend = Icons.send;
  static const _iconAttach = Icons.attach_file;

  /// Characters the message needs before articles are looked up.
  static const int _suggestFrom = 12;

  /// How long typing must pause before the lookup is sent.
  static const Duration _suggestDelay = Duration(milliseconds: 600);

  final TextEditingController _body = TextEditingController();

  Timer? _suggestTimer;

  /// The trimmed text the last change was judged on, so a cursor move, which
  /// notifies the controller too, does not restart the pause.
  String _typed = '';

  String? _topic;

  /// True while the client info is read, before the controller's own
  /// in-flight guard takes over.
  bool _collecting = false;

  @override
  Future<List<MagicFile>> Function(List<String> extensions)?
  get pickFilesOverride => widget.pickFiles;

  @override
  void initState() {
    super.initState();
    supportController.forgetArticleSuggestions(notify: false);
    _body.addListener(_onBodyChanged);
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _body.dispose();
    super.dispose();
  }

  void _onBodyChanged() {
    final String text = _body.text.trim();
    if (text == _typed) return;

    _typed = text;
    _suggestTimer?.cancel();

    if (text.runes.length < _suggestFrom) {
      supportController.forgetArticleSuggestions();
      return;
    }

    _suggestTimer = Timer(
      _suggestDelay,
      () => supportController.suggestArticles(text),
    );
  }

  Future<void> _submit() async {
    final bool writing = supportController.isSubmittingFor(widget.surface);
    if (_collecting || writing) return;

    // 1. The client context, when on.
    Map<String, String>? clientContext;
    if (MagicStarterConfig.hasSupportClientContextFeatures()) {
      setState(() => _collecting = true);
      clientContext = await MagicStarterSupportClientContext.collect();
      if (!mounted) return;
      setState(() => _collecting = false);
    }

    // 2. One write carries the message, the files and the client context.
    final conversation = await supportController.createConversation(
      topic: _topic,
      body: _body.text.trim(),
      source: 'in_app',
      attachments: pickedAttachments,
      clientContext: clientContext,
      surface: widget.surface,
    );
    if (conversation == null) return;

    widget.onCreated(conversation);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildCompact();

    final bool wide = wScreenIs(context, 'lg');

    return MSCard(
      child: WDiv(
        className: 'flex flex-col gap-5',
        children: [..._buildFields(), _buildFooter(wide)],
      ),
    );
  }

  /// The panel layout: only the fields scroll, so Send and the privacy note
  /// stay in view however many articles and attachments the fields hold.
  Widget _buildCompact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: WDiv(
              className: 'flex flex-col gap-5',
              children: _buildFields(),
            ),
          ),
        ),
        WDiv(
          className: 'p-4 border-t border-color-border-subtle',
          child: _buildFooter(false),
        ),
      ],
    );
  }

  List<Widget> _buildFields() {
    return [
      MSFormField(
        label: trans('magic_starter.support.topic_label'),
        error: supportController.getError('topic'),
        child: WDiv(
          className: 'flex flex-row wrap gap-2',
          children: [
            for (final topic in supportController.topics) _buildChip(topic),
          ],
        ),
      ),
      MSFormField(
        label: trans('magic_starter.support.message_label'),
        error:
            supportController.getError('body') ??
            supportController.writeError ??
            _unplacedError(),
        child: WDiv(
          className: 'flex flex-col gap-1.5',
          children: [
            MSTextarea(
              controller: _body,
              placeholder: trans('magic_starter.support.message_placeholder'),
              minLines: 6,
              fullWidth: true,
            ),
            _buildCounter(),
          ],
        ),
      ),
      if (MagicStarterConfig.hasSupportAttachmentsFeatures())
        _buildAttachments(),
      if (supportController.articleSuggestions.isNotEmpty) _buildSuggestions(),
    ];
  }

  /// The generic refusal text when the backend rejected a field this form has
  /// no place for (a `client_context.*` key, say), so Send never fails silently.
  String? _unplacedError() {
    final bool unplaced = supportController.validationErrors.keys.any(
      (key) => !_placedErrorKey(key),
    );

    return unplaced ? trans('magic_starter.support.create_error') : null;
  }

  bool _placedErrorKey(String key) {
    return key == 'topic' ||
        key == 'body' ||
        key == 'attachments' ||
        key.startsWith('attachments.');
  }

  Widget _buildSuggestions() {
    return WDiv(
      className: 'flex flex-col gap-2',
      children: [
        WText(
          trans('magic_starter.support.articles_label'),
          className: 'text-sm font-medium text-fg',
        ),
        for (final article in supportController.articleSuggestions)
          MagicStarterSupportArticleCard(article),
      ],
    );
  }

  Widget _buildAttachments() {
    return MSFormField(
      label: trans('magic_starter.support.attachments_label'),
      hint: trans('magic_starter.support.attachments_hint', {
        'max': MagicStarterConfig.supportAttachmentMaxFiles(),
        'size': MagicStarterConfig.supportAttachmentMaxBytes() ~/ (1024 * 1024),
      }),
      error: magicStarterSupportAttachmentError(supportController),
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
            'flex flex-row items-center gap-2 h-11 px-3.5 rounded-xl '
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
      isLoading:
          supportController.isSubmittingFor(widget.surface) || _collecting,
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

    return WDiv(
      className: widget.compact ? 'flex flex-col gap-2' : 'flex flex-col gap-3',
      children: [send, privacy],
    );
  }
}
