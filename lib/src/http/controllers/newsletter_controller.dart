import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Controller for newsletter subscription management.
class StarterNewsletterController extends MagicController with MagicStateMixin, ValidatesRequests {
  /// Singleton accessor — use this instead of constructing directly.
  static StarterNewsletterController get instance =>
      Magic.findOrPut(StarterNewsletterController.new);

  /// Fetches the current newsletter subscription status.
  Future<void> getNewsletterStatus() async {
    if (isLoading) return;
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
          '[StarterNewsletterController.getNewsletterStatus] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    }
  }

  /// Updates the newsletter subscription.
  Future<void> updateNewsletterSubscription({required bool subscribe}) async {
    if (isLoading) return;
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
          '[StarterNewsletterController.updateNewsletterSubscription] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    }
  }
}
