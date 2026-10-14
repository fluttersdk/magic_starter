import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_support_controller.dart';
import '../../../models/magic_starter_support_conversation.dart';
import '../../components/button/index.dart';
import '../../components/dialog/index.dart';

/// Picks the files a support message carries, for the create form and the
/// thread composer.
///
/// The host widget names the picker through [pickFilesOverride] only so a test
/// can stand in for the system dialog; production reads `Pick.files` with the
/// configured extensions. Limits (count, size, type) are not checked here: the
/// controller refuses a pick the backend would refuse, before it is uploaded,
/// and the screen shows that refusal where it already shows write errors.
mixin MagicStarterSupportAttachmentPicking<T extends StatefulWidget>
    on State<T> {
  List<MagicFile> _picked = const <MagicFile>[];

  /// The files waiting to go with the next send, in pick order.
  List<MagicFile> get pickedAttachments => _picked;

  /// A stand-in for the system picker. Null reads `Pick.files`.
  Future<List<MagicFile>> Function(List<String> extensions)?
  get pickFilesOverride;

  /// Opens the picker and adds what the customer chose.
  Future<void> pickAttachments() async {
    final extensions = MagicStarterConfig.supportAttachmentExtensions();
    final picker = pickFilesOverride;
    final chosen = picker == null
        ? await Pick.files(extensions: extensions)
        : await picker(extensions);

    if (!mounted || chosen.isEmpty) return;

    setState(() => _picked = [..._picked, ...chosen]);
  }

  void removeAttachment(int index) {
    setState(() => _picked = [..._picked]..removeAt(index));
  }

  /// Forgets the picked files, once the send that carried them succeeded.
  void clearAttachments() {
    if (_picked.isEmpty) return;

    setState(() => _picked = const <MagicFile>[]);
  }
}

/// Why the last write refused the picked files, or null.
///
/// The client's own refusals (too many, too large, wrong type) arrive as the
/// controller's write error; the backend's per-file refusals arrive under
/// `attachments.N`.
String? magicStarterSupportAttachmentError(
  MagicStarterSupportController controller,
) {
  for (var i = 0; i < MagicStarterConfig.supportAttachmentMaxFiles(); i++) {
    final error = controller.getError('attachments.$i');
    if (error != null) return error;
  }

  return controller.getError('attachments');
}

/// `1.5 KB`, `2.0 MB`. Null when the picker reported no size.
String? magicStarterSupportFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';

  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// The round paperclip that opens the picker.
class MagicStarterSupportAttachButton extends StatelessWidget {
  const MagicStarterSupportAttachButton({super.key, required this.onTap});

  final VoidCallback onTap;

  static const _iconAttach = Icons.attach_file;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: trans('magic_starter.support.attach_button'),
      child: WAnchor(
        key: const ValueKey<String>('support-attach'),
        onTap: onTap,
        child: WDiv(
          className: 'w-9 h-9 rounded-full flex items-center justify-center',
          child: WIcon(_iconAttach, className: 'text-base text-fg-muted'),
        ),
      ),
    );
  }
}

/// The picked files as removable chips: name and size.
class MagicStarterSupportPickedChips extends StatelessWidget {
  const MagicStarterSupportPickedChips({
    super.key,
    required this.files,
    required this.onRemove,
  });

  final List<MagicFile> files;

  /// Drops the file at the given index.
  final ValueChanged<int> onRemove;

  static const _iconRemove = Icons.close;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    return WDiv(
      className: 'flex flex-row wrap gap-2',
      children: [
        for (var i = 0; i < files.length; i++) _buildChip(i, files[i]),
      ],
    );
  }

  Widget _buildChip(int index, MagicFile file) {
    final size = magicStarterSupportFileSize(file.size);

    return WDiv(
      key: ValueKey<String>('support-attachment-chip-$index'),
      className:
          'max-w-xs flex flex-row items-center gap-2 pl-3 pr-1.5 py-1.5 '
          'rounded-xl border border-color-border bg-surface-container-high',
      children: [
        Flexible(
          child: WText(
            file.name,
            className: 'text-sm font-medium text-fg truncate',
          ),
        ),
        if (size != null)
          WText(size, className: 'text-xs text-fg-muted shrink-0'),
        Semantics(
          button: true,
          label: trans('magic_starter.support.attachment_remove', {
            'name': file.name,
          }),
          child: WAnchor(
            key: ValueKey<String>('support-attachment-remove-$index'),
            onTap: () => onRemove(index),
            child: WDiv(
              className:
                  'w-6 h-6 rounded-full flex items-center justify-center',
              child: WIcon(_iconRemove, className: 'text-sm text-fg-muted'),
            ),
          ),
        ),
      ],
    );
  }
}

/// What a message carried: images as thumbnails, PDFs as labelled chips.
///
/// An attachment answers only to the bearer token, so an image is read through
/// [headers] and a PDF never as a bare link: [onOpenPdf] asks the backend for a
/// short-lived signed url. The files came from a customer or a teammate's
/// customer, so a PDF is labelled untrusted. Nothing draws until [headers] has
/// resolved, since an image read without them would be refused.
class MagicStarterSupportAttachmentList extends StatelessWidget {
  const MagicStarterSupportAttachmentList({
    super.key,
    required this.attachments,
    required this.headers,
    required this.onOpenPdf,
    this.alignEnd = false,
  });

  final List<MagicStarterSupportAttachment> attachments;

  /// The bearer header for an image read; null while it is still resolving.
  final Map<String, String>? headers;

  final ValueChanged<MagicStarterSupportAttachment> onOpenPdf;

  /// Right-aligns the row, for the customer's own side of the thread.
  final bool alignEnd;

  static const double _thumbnail = 160;
  static const _iconPdf = Icons.picture_as_pdf_outlined;
  static const _iconBroken = Icons.broken_image_outlined;

  /// Where an attachment is read: the API base plus its API-relative path.
  static String urlFor(MagicStarterSupportAttachment attachment) {
    final base = (Config.get<String>('network.drivers.api.base_url') ?? '')
        .replaceFirst(RegExp(r'/+$'), '');

    return '$base/${attachment.url.replaceFirst(RegExp(r'^/+'), '')}';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = headers;
    if (attachments.isEmpty || resolved == null) return const SizedBox.shrink();

    return WDiv(
      className:
          'flex flex-row wrap gap-2 ${alignEnd ? 'justify-end' : 'justify-start'}',
      children: [
        for (final attachment in attachments)
          attachment.kind == 'image'
              ? _buildImage(context, attachment, resolved)
              : _buildPdf(attachment),
      ],
    );
  }

  Widget _buildImage(
    BuildContext context,
    MagicStarterSupportAttachment attachment,
    Map<String, String> resolved,
  ) {
    return WAnchor(
      key: ValueKey<String>('support-attachment-${attachment.id}'),
      onTap: () => _viewFullSize(context, attachment, resolved),
      child: WDiv(
        className:
            'rounded-xl overflow-hidden border border-color-border '
            'bg-surface-container-high',
        child: SizedBox(
          width: _thumbnail,
          height: _thumbnail,
          child: Image.network(
            urlFor(attachment),
            headers: resolved,
            fit: BoxFit.cover,
            semanticLabel: attachment.name,
            errorBuilder: (_, _, _) => _broken(),
          ),
        ),
      ),
    );
  }

  Widget _buildPdf(MagicStarterSupportAttachment attachment) {
    return WAnchor(
      key: ValueKey<String>('support-attachment-${attachment.id}'),
      onTap: () => onOpenPdf(attachment),
      child: WDiv(
        className:
            'max-w-xs flex flex-row items-center gap-2.5 px-3 py-2 rounded-xl '
            'border border-color-border bg-surface-container-high',
        children: [
          WIcon(_iconPdf, className: 'text-xl text-fg-muted'),
          Flexible(
            child: WDiv(
              className: 'flex flex-col gap-0.5',
              children: [
                WText(
                  attachment.name,
                  className: 'text-sm font-medium text-fg truncate',
                ),
                WText(
                  trans('magic_starter.support.attachment_untrusted'),
                  className: 'text-xs text-fg-muted',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _broken() {
    return WDiv(
      className: 'w-full h-full flex items-center justify-center',
      child: WIcon(_iconBroken, className: 'text-2xl text-fg-muted'),
    );
  }

  Future<void> _viewFullSize(
    BuildContext context,
    MagicStarterSupportAttachment attachment,
    Map<String, String> resolved,
  ) {
    return MSDialog.show<void>(
      context,
      title: attachment.name,
      body: Image.network(
        urlFor(attachment),
        headers: resolved,
        fit: BoxFit.contain,
        semanticLabel: attachment.name,
        errorBuilder: (_, _, _) => _broken(),
      ),
      footerBuilder: (dialogContext) => MSButton(
        intent: ButtonIntent.secondary,
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: WText(trans('common.done'), className: 'text-center'),
      ),
    );
  }
}
