import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../models/magic_starter_support_conversation.dart';
import '../../components/button/index.dart';
import '../../components/card/index.dart';
import '../../components/form_field/index.dart';
import '../../components/textarea/index.dart';

/// The thumbs rating under a resolved thread.
///
/// A resolved conversation that [MagicStarterSupportConversation.canRate] asks
/// "How did we do?" with a thumbs up or down and an optional comment. One that
/// already carries a rating shows its choice and comment and lets the customer
/// change them: the backend overwrites the rating while the conversation stays
/// resolved. A saved rating is acknowledged with a thank-you line that goes
/// away as soon as the customer edits again.
///
/// The block holds the choice and the comment; [onSubmit] does the write and
/// answers whether the backend took it.
class MagicStarterSupportRatingBlock extends StatefulWidget {
  const MagicStarterSupportRatingBlock({
    super.key,
    required this.rating,
    required this.onSubmit,
    required this.isSubmitting,
    this.error,
  });

  /// The rating on record for this resolution, or null while unrated.
  final MagicStarterSupportRating? rating;

  /// Writes the rating (`up` or `down`) with its comment, which is empty when
  /// the customer wrote none.
  final Future<bool> Function(String rating, String comment) onSubmit;

  final bool isSubmitting;

  /// Why the last submit was refused, shown under the comment.
  final String? error;

  /// The longest comment the backend takes.
  static const int commentMaxLength = 1000;

  @override
  State<MagicStarterSupportRatingBlock> createState() =>
      _MagicStarterSupportRatingBlockState();
}

class _MagicStarterSupportRatingBlockState
    extends State<MagicStarterSupportRatingBlock> {
  static const _iconUp = Icons.thumb_up_outlined;
  static const _iconUpSelected = Icons.thumb_up;
  static const _iconDown = Icons.thumb_down_outlined;
  static const _iconDownSelected = Icons.thumb_down;

  late final TextEditingController _comment = TextEditingController(
    text: widget.rating?.comment ?? '',
  );

  late String? _choice = widget.rating?.value;

  bool _thanked = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _choose(String value) {
    setState(() {
      _choice = value;
      _thanked = false;
    });
  }

  Future<void> _submit() async {
    final choice = _choice;
    if (choice == null || widget.isSubmitting) return;

    final saved = await widget.onSubmit(choice, _comment.text.trim());

    if (saved && mounted) setState(() => _thanked = true);
  }

  @override
  Widget build(BuildContext context) {
    final rated = widget.rating != null;

    return MSCard(
      key: const ValueKey<String>('support-rating'),
      child: WDiv(
        className: 'flex flex-col gap-3.5',
        children: [
          WText(
            trans('magic_starter.support.rating_prompt'),
            className: 'text-sm font-semibold text-fg',
          ),
          WDiv(
            className: 'flex flex-row wrap gap-2',
            children: [
              _buildThumb(
                value: 'up',
                label: trans('magic_starter.support.rating_up'),
                icon: _iconUp,
                selectedIcon: _iconUpSelected,
              ),
              _buildThumb(
                value: 'down',
                label: trans('magic_starter.support.rating_down'),
                icon: _iconDown,
                selectedIcon: _iconDownSelected,
              ),
            ],
          ),
          MSFormField(
            error: widget.error,
            child: ListenableBuilder(
              listenable: _comment,
              builder: (context, _) => WDiv(
                className: 'flex flex-col gap-1.5',
                children: [
                  MSTextarea(
                    key: const ValueKey<String>('support-rating-comment'),
                    controller: _comment,
                    placeholder: trans(
                      'magic_starter.support.rating_comment_placeholder',
                    ),
                    minLines: 2,
                    fullWidth: true,
                  ),
                  WDiv(
                    className: 'flex flex-row justify-end',
                    child: WText(
                      '${_comment.text.runes.length} / '
                      '${MagicStarterSupportRatingBlock.commentMaxLength}',
                      className: 'text-xs text-fg-disabled',
                    ),
                  ),
                ],
              ),
            ),
          ),
          WDiv(
            className: 'flex flex-row wrap items-center gap-3',
            children: [
              MSButton(
                key: const ValueKey<String>('support-rating-submit'),
                // 44 px on a phone, the default 36 from `lg` up.
                className: 'py-3 lg:py-2',
                onPressed: _submit,
                isLoading: widget.isSubmitting,
                child: WText(
                  trans(
                    rated
                        ? 'magic_starter.support.rating_update'
                        : 'magic_starter.support.rating_submit',
                  ),
                  className: 'text-center',
                ),
              ),
              if (_thanked)
                WText(
                  trans('magic_starter.support.rating_thanks'),
                  key: const ValueKey<String>('support-rating-thanks'),
                  className: 'text-sm text-fg-muted',
                ),
            ],
          ),
          if (rated && !_thanked)
            WText(
              trans('magic_starter.support.rating_change_hint'),
              className: 'text-xs text-fg-muted',
            ),
        ],
      ),
    );
  }

  Widget _buildThumb({
    required String value,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final selected = _choice == value;
    final tone = selected
        ? 'border-primary-600 dark:border-primary-500 bg-primary-container'
        : 'border-color-border bg-surface-container-high';

    // The anchor's own `semanticLabel` makes it the one button of this pill;
    // a `Semantics(button: true)` around it announced a second, nested one.
    return Semantics(
      selected: selected,
      child: WAnchor(
        key: ValueKey<String>('support-rating-$value'),
        semanticLabel: label,
        onTap: () => _choose(value),
        child: WDiv(
          className:
              'flex flex-row items-center gap-2 h-11 lg:h-[38px] px-3.5 rounded-xl '
              'border $tone',
          children: [
            WIcon(selected ? selectedIcon : icon, className: 'text-sm text-fg'),
            WText(label, className: 'text-sm font-medium text-fg'),
          ],
        ),
      ),
    );
  }
}
