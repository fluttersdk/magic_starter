import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_feedback_controller.dart';
import '../../../support/store_review.dart';
import '../button/index.dart';
import '../card/index.dart';
import '../form_field/index.dart';
import '../textarea/index.dart';
import 'feedback_card.recipe.dart';

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
/// const MSFeedbackCard()
/// ```
class MSFeedbackCard extends StatefulWidget {
  /// Creates an [MSFeedbackCard].
  const MSFeedbackCard({super.key, this.onDemand = false});

  /// Whether the customer asked for the form, which skips the eligibility read
  /// and the dismissal.
  final bool onDemand;

  /// The highest score on the scale; the lowest is 0.
  static const int maxScore = 10;

  @override
  State<MSFeedbackCard> createState() => _MSFeedbackCardState();
}

class _MSFeedbackCardState extends State<MSFeedbackCard> {
  final MagicStarterFeedbackController _controller =
      MagicStarterFeedbackController.instance;
  final TextEditingController _comment = TextEditingController();

  late final bool _mayShow = _resolveMayShow();

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
        final slots = feedbackCardRecipe();

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
                  for (var score = 0; score <= MSFeedbackCard.maxScore; score++)
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
                child: WText(trans('magic_starter.support.feedback_submit')),
              ),
              if (!widget.onDemand)
                MSButton(
                  key: const ValueKey<String>('feedback-dismiss'),
                  intent: ButtonIntent.secondary,
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
    final slots = feedbackCardRecipe(
      variants: <String, String>{
        kFeedbackScoreAxis: selected ? 'selected' : 'idle',
      },
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '$score',
      child: WAnchor(
        key: ValueKey<String>('feedback-score-$score'),
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
