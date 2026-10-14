import 'package:magic/magic.dart';

/// Backs the occasional 0-10 feedback card: whether to show it, and the one
/// write that answers or dismisses it.
///
/// ## Why this controller does NOT use `MagicStateMixin`
///
/// The card is optional chrome with no loading or error screen of its own: any
/// read that does not say "eligible" simply shows nothing. A single state slot
/// would only invite a spinner where there should be silence, so the answer is
/// a plain field notified through [refreshUI], the shape
/// `MagicStarterSupportController` documents.
///
/// ## Tenant boundary
///
/// Eligibility belongs to one signed-in user, so the controller is
/// [SessionScoped] and a sign-in drops the previous answer before anything else
/// renders.
class MagicStarterFeedbackController extends MagicController
    with ValidatesRequests
    implements SessionScoped {
  /// Singleton accessor. Use this instead of constructing directly.
  static MagicStarterFeedbackController get instance =>
      Magic.findOrPut(MagicStarterFeedbackController.new);

  /// Bumped by [resetForSession]; a read that started under an older value
  /// belongs to the previous user and publishes nothing.
  int _sessionGeneration = 0;

  bool _hasRead = false;
  bool _eligible = false;
  bool _isSubmitting = false;
  Object? _conversationId;
  String? _writeError;

  /// Whether the card should show. False until [loadEligibility] answers yes,
  /// and again once the card is answered or dismissed.
  bool get eligible => _eligible;

  /// Whether a [submit] is in flight.
  bool get isSubmitting => _isSubmitting;

  /// The conversation a low score opened (or continued), for the screen to
  /// offer. Null when the last answer opened none.
  Object? get conversationId => _conversationId;

  /// The message of the last write the backend refused for a reason other than
  /// validation (field errors live in [getError]). Cleared by the next write.
  String? get writeError => _writeError;

  /// Asks whether this user is due a feedback card.
  ///
  /// Any answer other than a clear yes reads as "not eligible", a guest or an
  /// unverified email (403) included: the card is optional, so a failed read is
  /// logged and never shown.
  Future<void> loadEligibility() async {
    final generation = _sessionGeneration;
    _hasRead = true;

    try {
      final response = await Http.get('/support/feedback');
      if (generation != _sessionGeneration) return;

      if (!response.successful) {
        if (response.statusCode != 403) {
          Log.warning(
            '[MagicStarterFeedbackController.loadEligibility] '
            '${response.statusCode}',
          );
        }
        _eligible = false;
      } else {
        _eligible = (response.data as Map<String, dynamic>)['eligible'] == true;
      }
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterFeedbackController.loadEligibility] $e\n$stackTrace',
      );
      if (generation != _sessionGeneration) return;
      _eligible = false;
    }

    refreshUI();
  }

  /// Answers the card with [score] (0 to 10), or dismisses it when [score] is
  /// null. Answers whether the backend accepted it; [conversationId] then holds
  /// the conversation a low score opened, if any.
  ///
  /// A blank [comment] is left out. A refused answer keeps the card up so the
  /// customer can retry: field errors are in [getError], anything else in
  /// [writeError].
  Future<bool> submit(int? score, {String? comment}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _writeError = null;
    _conversationId = null;
    clearErrors();
    refreshUI();

    final generation = _sessionGeneration;
    final note = comment?.trim();

    try {
      final response = await Http.post(
        '/support/feedback',
        data: {
          'score': score,
          'comment': ?(note == null || note.isEmpty ? null : note),
        },
      );
      if (generation != _sessionGeneration) return false;

      if (!response.successful) {
        if (response.isValidationError) {
          setErrorsFromResponse(response);
        } else {
          _writeError =
              response.firstError ??
              trans('magic_starter.support.feedback_error');
        }

        return false;
      }

      _conversationId =
          (response.data as Map<String, dynamic>)['conversation_id'];
      _eligible = false;

      return true;
    } catch (e, stackTrace) {
      Log.error('[MagicStarterFeedbackController.submit] $e\n$stackTrace');
      if (generation == _sessionGeneration) {
        _writeError = trans('errors.unexpected');
      }

      return false;
    } finally {
      if (generation == _sessionGeneration) _isSubmitting = false;
      refreshUI();
    }
  }

  /// Dismisses the card. The card goes away for the session even when the
  /// backend does not record the dismissal, so a failed write never nags.
  Future<void> dismiss() async {
    await submit(null);

    _eligible = false;
    refreshUI();
  }

  /// Drops the previous user's answer, then reads again when a read had been
  /// made (see [SessionScoped]).
  ///
  /// Clears BEFORE reading, so a failed read leaves no card rather than the
  /// previous user's.
  @override
  Future<void> resetForSession() async {
    _sessionGeneration++;

    final hadRead = _hasRead;

    _hasRead = false;
    _eligible = false;
    _isSubmitting = false;
    _conversationId = null;
    _writeError = null;
    clearErrors();
    refreshUI();

    if (hadRead) await loadEligibility();
  }
}
