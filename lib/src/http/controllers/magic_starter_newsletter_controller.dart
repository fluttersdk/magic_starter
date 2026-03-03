import 'package:magic/magic.dart';

/// Controller for newsletter subscription management.
class MagicStarterNewsletterController extends MagicController
    with MagicStateMixin, ValidatesRequests {
  /// Singleton accessor — use this instead of constructing directly.
  static MagicStarterNewsletterController get instance =>
      Magic.findOrPut(MagicStarterNewsletterController.new);
  bool _isSubmitting = false;

  /// Fetches the current newsletter subscription status.
  Future<void> getNewsletterStatus() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();

    try {
      final response = await Http.get('/user/newsletter');

      if (!response.successful) {
        handleApiError(response,
            fallback: trans('magic_starter.newsletter.fetch_error'));
        return;
      }

      setSuccess(response.data as Map<String, dynamic>?);
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterNewsletterController.getNewsletterStatus] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Updates the newsletter subscription.
  Future<void> updateNewsletterSubscription({required bool subscribe}) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();

    try {
      final response = await Http.put(
        '/user/newsletter',
        data: {'subscribe': subscribe},
      );

      if (!response.successful) {
        handleApiError(response,
            fallback: trans('magic_starter.newsletter.update_error'));
        return;
      }

      setSuccess(response.data as Map<String, dynamic>?);
    } catch (e, stackTrace) {
      Log.error(
          '[MagicStarterNewsletterController.updateNewsletterSubscription] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }
}
