import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../http/controllers/magic_starter_feedback_controller.dart';
import '../../support/store_review.dart';
import '../components/button/index.dart';
import '../components/card/index.dart';
import '../components/form_field/index.dart';
import '../components/textarea/index.dart';

/// The `score` axis key: whether a score chip is the chosen one.
const String _scoreAxis = 'score';

/// What a focused score looks like.
///
/// It trails each variant's own border classes, not the base: wind resolves a
/// family last-wins across the active classes, so a `border-*` colour that came
/// after `focus:border-2` would undo the thicker border.
const String _scoreFocus =
    'focus:border-2 focus:border-primary-400 '
    'focus:ring-2 focus:ring-offset-2 focus:ring-primary-500';

/// The card's slots.
///
/// A score is a 44 x 44 tap target. When the keyboard reaches it the border
/// thickens to the primary colour and a ring follows; the border is what shows
/// on a wind release that does not yet paint `focus:ring-*` on a `WDiv`. The
/// chosen one is filled with the primary colour, so it reads as chosen at a
/// glance rather than as a faint ring.
///
/// ```
/// root     - the column inside the card
/// question - the 0-10 question
/// scale    - the wrapping row of eleven score chips
/// score    - one square chip (`score` axis: idle / selected)
/// label    - the number inside a chip (`score` axis: idle / selected)
/// ends     - the "Not likely" / "Very likely" row under the scale
/// end      - one of those two captions
/// actions  - the send and "Not now" row
/// thanks   - the line that replaces the form once answered
/// link     - the conversation a low score opened
/// ```
const WindSlotRecipe _recipe = WindSlotRecipe(
  slots: {
    'root': 'flex flex-col gap-4',
    'question': 'text-sm font-semibold text-fg',
    'scale': 'flex flex-row wrap gap-2',
    'score':
        'flex flex-row items-center justify-center w-11 h-11 rounded-xl border',
    'label': 'text-sm font-medium',
    'ends': 'flex flex-row justify-between gap-3',
    'end': 'text-xs text-fg-muted',
    'actions': 'flex flex-row wrap items-center gap-3',
    'thanks': 'text-sm text-fg',
    'link': 'text-sm font-medium text-primary',
  },
  variants: {
    _scoreAxis: {
      'idle': {
        'score': 'border-color-border bg-surface-container-high $_scoreFocus',
        'label': 'text-fg',
      },
      'selected': {
        'score':
            'border-primary-600 dark:border-primary-500 bg-primary '
            '$_scoreFocus',
        'label': 'text-on-primary',
      },
    },
  },
  defaultVariants: {_scoreAxis: 'idle'},
);

/// **The occasional 0-10 feedback card.**
///
/// Asks how likely the customer is to recommend the product, with an optional
/// comment, and thanks them once answered. When a low score opened a support
/// conversation, the thanks line links to it.
///
/// By default the card asks the backend whether this account is due one
/// ([MagicStarterFeedbackController.loadEligibility]) and renders nothing
/// until it is; "Not now" records a dismissal and the card goes away. With
/// [onDemand] it is the form behind the profile menu's "Send feedback": always
/// shown, no eligibility read, no dismissal.
///
/// Renders nothing while `support_feedback` is off and for a guest or a
/// signed-out visitor, whom the backend refuses anyway. Once on screen it tells
/// [MagicStarterStoreReview] so, and no store review prompt follows in the
/// same run.
///
/// ### Example:
/// ```dart
/// const MagicStarterFeedbackCard()
/// ```
class MagicStarterFeedbackCard extends StatefulWidget {
  /// Creates a [MagicStarterFeedbackCard].
  const MagicStarterFeedbackCard({super.key, this.onDemand = false});

  /// Whether the customer asked for the form, which skips the eligibility read
  /// and the dismissal.
  final bool onDemand;

  /// The highest score on the scale; the lowest is 0.
  static const int maxScore = 10;

  @override
  State<MagicStarterFeedbackCard> createState() =>
      _MagicStarterFeedbackCardState();
}

class _MagicStarterFeedbackCardState extends State<MagicStarterFeedbackCard> {
  final MagicStarterFeedbackController _controller =
      MagicStarterFeedbackController.instance;
  final TextEditingController _comment = TextEditingController();

  late final bool _mayShow = _resolveMayShow();

  /// Lifts a `md` button from 36 to 44 px on a phone, where a thumb taps it.
  static const String _touchHeight = 'py-3 lg:py-2';

  int? _score;
  bool _answered = false;

  @override
  void initState() {
    super.initState();

    if (!_mayShow) return;

    if (widget.onDemand) {
      MagicStarterStoreReview.noteFeedbackCardShown();

      return;
    }

    _controller.addListener(_noteShown);
    _controller.loadEligibility();
  }

  @override
  void dispose() {
    _controller.removeListener(_noteShown);
    _comment.dispose();
    super.dispose();
  }

  bool _resolveMayShow() {
    if (!MagicStarterConfig.hasSupportFeedbackFeatures()) return false;
    if (!Auth.check()) return false;

    return Auth.user()?.get<bool>('is_guest') != true;
  }

  void _noteShown() {
    if (_controller.eligible) MagicStarterStoreReview.noteFeedbackCardShown();
  }

  Future<void> _submit() async {
    final score = _score;
    if (score == null) return;

    final accepted = await _controller.submit(score, comment: _comment.text);

    if (accepted && mounted) setState(() => _answered = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_mayShow) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final slots = _recipe();

        if (_answered) return _buildThanks(slots);
        if (!widget.onDemand && !_controller.eligible) {
          return const SizedBox.shrink();
        }

        return _buildForm(slots);
      },
    );
  }

  Widget _buildForm(Map<String, String> slots) {
    return MSCard(
      key: const ValueKey<String>('feedback-card'),
      child: WDiv(
        className: slots['root'],
        children: [
          WText(
            trans('magic_starter.support.feedback_question'),
            className: slots['question'],
          ),
          WDiv(
            className: 'flex flex-col gap-1.5',
            children: [
              WDiv(
                className: slots['scale'],
                children: [
                  for (
                    var score = 0;
                    score <= MagicStarterFeedbackCard.maxScore;
                    score++
                  )
                    _buildScore(score),
                ],
              ),
              WDiv(
                className: slots['ends'],
                children: [
                  WText(
                    trans('magic_starter.support.feedback_low'),
                    className: slots['end'],
                  ),
                  WText(
                    trans('magic_starter.support.feedback_high'),
                    className: slots['end'],
                  ),
                ],
              ),
            ],
          ),
          MSFormField(
            error:
                _controller.getError('score') ??
                _controller.getError('comment') ??
                _controller.writeError,
            child: MSTextarea(
              key: const ValueKey<String>('feedback-comment'),
              controller: _comment,
              placeholder: trans(
                'magic_starter.support.feedback_comment_placeholder',
              ),
              minLines: 2,
              fullWidth: true,
            ),
          ),
          WDiv(
            className: slots['actions'],
            children: [
              MSButton(
                key: const ValueKey<String>('feedback-submit'),
                onPressed: _submit,
                isLoading: _controller.isSubmitting,
                disabled: _score == null,
                // `disabled:opacity-50` in the button recipe paints nothing on a
                // `WButton`, so the disabled state carries its own muted colours.
                className:
                    '$_touchHeight disabled:bg-surface-container-high '
                    'disabled:text-fg-disabled',
                child: WText(trans('magic_starter.support.feedback_submit')),
              ),
              if (!widget.onDemand)
                MSButton(
                  key: const ValueKey<String>('feedback-dismiss'),
                  intent: ButtonIntent.secondary,
                  className: _touchHeight,
                  onPressed: _controller.isSubmitting
                      ? null
                      : _controller.dismiss,
                  child: WText(trans('magic_starter.support.feedback_dismiss')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScore(int score) {
    final selected = _score == score;
    final slots = _recipe(
      variants: <String, String>{_scoreAxis: selected ? 'selected' : 'idle'},
    );

    // The anchor's own `semanticLabel` makes it the one button of this score;
    // a `Semantics(button: true)` around it announced a second, nested one.
    return Semantics(
      selected: selected,
      child: WAnchor(
        key: ValueKey<String>('feedback-score-$score'),
        semanticLabel: '$score',
        onTap: () => setState(() => _score = score),
        child: WDiv(
          className: slots['score'],
          child: WText('$score', className: slots['label']),
        ),
      ),
    );
  }

  Widget _buildThanks(Map<String, String> slots) {
    final conversationId = _controller.conversationId;

    return MSCard(
      key: const ValueKey<String>('feedback-card'),
      child: WDiv(
        className: slots['root'],
        children: [
          WText(
            trans('magic_starter.support.feedback_thanks'),
            className: slots['thanks'],
          ),
          if (conversationId != null)
            WAnchor(
              key: const ValueKey<String>('feedback-conversation'),
              onTap: () => MagicRoute.to(
                MagicStarterConfig.supportThreadPath(conversationId),
              ),
              child: WText(
                trans('magic_starter.support.feedback_view_conversation'),
                className: slots['link'],
              ),
            ),
        ],
      ),
    );
  }
}
