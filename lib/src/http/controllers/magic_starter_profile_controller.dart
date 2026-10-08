import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_payments/magic_payments.dart';

import '../../configuration/magic_starter_config.dart';
import '../../contracts/magic_starter_social_auth.dart';
import '../../facades/magic_starter.dart';
import '../../support/social_failure_message.dart';
import 'concerns/navigates_routes.dart';

/// The one thing a refused account deletion offers to clear what blocks it.
///
/// [run] reports its own failures: the caller only invokes it from a tap.
typedef MagicStarterRefusalAction = ({
  String label,
  Future<void> Function() run,
});

/// Profile controller for Magic Starter plugin.
class MagicStarterProfileController extends MagicController
    with MagicStateMixin<bool>, ValidatesRequests, NavigatesRoutes {
  static MagicStarterProfileController get instance =>
      Magic.findOrPut(MagicStarterProfileController.new);
  bool _isSubmitting = false;

  /// How many [withoutNotifying] actions are in flight.
  ///
  /// While above zero, [notifyListeners] calls are silently discarded. A count
  /// rather than a flag, because two of them can overlap (a save still in
  /// flight when the reader opens another settings page that loads on mount),
  /// and a flag cleared by the first to finish would un-suppress the other.
  int _suppressionDepth = 0;

  List<String>? _stepUpAccepts;

  /// The proofs the server takes after refusing a gated call with
  /// `step_up_required` (`code`, `confirmation_token`), or `null` when the
  /// last call was not refused that way.
  ///
  /// Cleared with the errors, so every gated call starts without it.
  List<String>? get stepUpAccepts => _stepUpAccepts;

  MagicStarterRefusalAction? _refusalAction;

  /// What the user can do to clear a refused account deletion, or `null` when
  /// the last call was not refused that way or nothing in the app can clear it.
  ///
  /// Cleared with the errors, so every gated call starts without it.
  MagicStarterRefusalAction? get refusalAction => _refusalAction;

  @override
  void clearErrors() {
    _stepUpAccepts = null;
    _refusalAction = null;
    super.clearErrors();
  }

  /// Render profile settings view via registry key.
  Widget profile() => MagicStarter.view.make('profile.settings');

  /// Execute [action] without triggering UI notifications.
  ///
  /// All [setLoading], [setSuccess], [setError], [handleApiError],
  /// and [clearErrors] calls within [action] will update internal
  /// state but skip [notifyListeners], preventing full-page rebuilds.
  ///
  /// Use when form-level loading (via [MagicFormData.process]) already
  /// drives the submit button's loading indicator.
  ///
  /// ```dart
  /// await form.process(() => controller.withoutNotifying(
  ///     () => controller.doUpdateProfile(name: 'Alice', email: 'a@b.com'),
  /// ));
  /// ```
  Future<T> withoutNotifying<T>(Future<T> Function() action) async {
    _suppressionDepth++;
    try {
      return await action();
    } finally {
      _suppressionDepth--;
    }
  }

  /// Clears errors and returns to the empty state without notifying.
  ///
  /// For a view's `onInit`, which runs while its route is being built. The
  /// settings hub and every settings sub-page bind this one controller, and
  /// the hub stays mounted under a stacked sub-page, so a notifying reset
  /// marked the hub dirty in the middle of the new route's build and Flutter
  /// refused it with "setState() or markNeedsBuild() called during build".
  /// Nothing needs the notification: the view calling this reads the state in
  /// its own first build, and the hub renders nothing from it.
  void resetQuietly() {
    validationErrors = {};
    setState(null, status: const RxStatus.empty(), notify: false);
  }

  @override
  void notifyListeners() {
    if (_suppressionDepth > 0) return;
    super.notifyListeners();
  }

  /// Reports a refused gated call, reading the refusal by its `code`.
  ///
  /// `step_up_required` keeps the proofs the server takes in [stepUpAccepts].
  /// `password_already_set` and `password_not_set` mean the cached user is
  /// stale, so it is restored first and the page that rebuilds shows the
  /// other password form. `last_login_method` and the account deletion
  /// refusals show their own sentence; the two that name blocking teams
  /// (`owns_shared_teams`, `team_has_active_subscription`) say which, and a
  /// subscription one keeps what clears it in [refusalAction]. Anything else
  /// is a plain [handleApiError].
  ///
  /// The server still decides every refusal: this only explains it.
  Future<void> _reportRefusal(
    MagicResponse response, {
    String? fallback,
  }) async {
    final body = response.data;
    final code = body is Map<String, dynamic> ? body['code'] : null;

    switch (code) {
      case 'step_up_required':
        _stepUpAccepts = ((body as Map<String, dynamic>)['accepts'] as List?)
            ?.cast<String>();
        setError(trans('social.step_up_required'));
      case 'password_already_set' || 'password_not_set':
        await Auth.restore();
        setError(trans('social.$code'));
      case 'owns_shared_teams':
        setError(
          _namingBlockingTeams(
            trans('social.owns_shared_teams'),
            _blockingTeamIds(body as Map<String, dynamic>),
          ),
        );
      case 'team_has_active_subscription':
        _reportBlockingSubscription(body as Map<String, dynamic>);
      case 'last_login_method' || 'subscription_active':
        setError(trans('social.$code'));
      default:
        handleApiError(response, fallback: fallback);
    }
  }

  /// The ids of the teams a deletion refusal names, empty when it names none.
  List<String> _blockingTeamIds(Map<String, dynamic> refusal) {
    final ids = refusal['team_ids'];
    if (ids is! List) return const <String>[];

    return [for (final id in ids) id.toString()];
  }

  /// Appends which teams block the deletion to [sentence].
  ///
  /// Names come from the host's team list; one that cannot name every blocking
  /// team (no team resolver, or a team it does not hold) says how many instead,
  /// in a sentence of its own, since a partial list would hide the one that
  /// matters.
  String _namingBlockingTeams(String sentence, List<String> teamIds) {
    if (teamIds.isEmpty) return sentence;

    final teams = MagicStarter.manager.teamResolver?.allTeams() ?? const [];
    final namesById = {for (final team in teams) team.id.toString(): team.name};
    final names = [for (final id in teamIds) namesById[id]];
    final named = names.every((name) => name != null && name.isNotEmpty);

    final blocking = named
        ? trans('social.deletion_blocking_teams', {'teams': names.join(', ')})
        : trans('social.deletion_blocking_teams_count', {
            'count': '${teamIds.length}',
          });

    return '$sentence $blocking';
  }

  /// Explains a `team_has_active_subscription` refusal and keeps the one action
  /// that clears it, chosen by how the first blocking team is billed.
  ///
  /// `team_providers` maps a blocking team id to `app_store`, `play_store` or
  /// `stripe`. A store subscription can only be cancelled in the store, so it
  /// offers that screen; a card one offers the host's deletion page
  /// ([MagicStarterConfig.accountDeletionUrl]), or, when the host has none, a
  /// sentence that points at no page and offers no action. A refusal that names
  /// no known provider keeps the generic sentence.
  void _reportBlockingSubscription(Map<String, dynamic> refusal) {
    final teamIds = _blockingTeamIds(refusal);
    final providers = refusal['team_providers'];
    final provider = providers is Map
        ? [
            for (final id in teamIds) providers[id],
          ].whereType<String>().firstOrNull
        : null;

    final String sentence;
    switch (provider) {
      case 'app_store' || 'play_store':
        sentence = trans('social.subscription_store');
        _refusalAction = (
          label: trans('social.subscription_store_action'),
          run: _openStoreManagement,
        );
      case 'stripe':
        final url = MagicStarterConfig.accountDeletionUrl();
        if (url == null) {
          sentence = trans('social.subscription_stripe_no_link');
        } else {
          sentence = trans('social.subscription_stripe');
          _refusalAction = (
            label: trans('social.subscription_stripe_action'),
            run: () => _openDeletionPage(url),
          );
        }
      default:
        sentence = trans('social.team_has_active_subscription');
    }

    setError(_namingBlockingTeams(sentence, teamIds));
  }

  /// Opens the store's own subscription screen through the store rail.
  ///
  /// A build with no store rail has no such screen, so that is a no-op. A rail
  /// that cannot open it throws [BillingException]: logged for whoever wired the
  /// rail, and the user is told it failed rather than left with a dead tap.
  Future<void> _openStoreManagement() async {
    try {
      await Payments.store?.openStoreManagement();
    } on BillingException catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController._openStoreManagement] '
        '$e\n$stackTrace',
      );
      Magic.toast(trans('errors.unexpected'));
    }
  }

  /// Opens the host's account deletion [url]; `Launch.url` answers `false`
  /// rather than throwing when nothing can handle it, which is told the same
  /// way.
  Future<void> _openDeletionPage(String url) async {
    if (await Launch.url(url)) return;

    Magic.toast(trans('errors.unexpected'));
  }

  /// Update profile information.
  Future<bool> doUpdateProfile({
    required String name,
    required String email,
    String? phone,
    String? timezone,
    String? language,
    String? password,
    String? passwordConfirmation,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final data = <String, dynamic>{
        'name': name,
        'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (timezone != null && timezone.isNotEmpty) 'timezone': timezone,
        if (language != null && language.isNotEmpty) 'locale': language,
        if (password != null && password.isNotEmpty) 'password': password,
        if (passwordConfirmation != null && passwordConfirmation.isNotEmpty)
          'password_confirmation': passwordConfirmation,
      };

      final response = await Http.put('/user/profile', data: data);

      if (!response.successful) {
        handleApiError(response, fallback: trans('profile.update_failed'));
        return false;
      }

      await Auth.restore();
      Magic.toast(trans('profile.updated'));
      _applySavedLanguage(language);
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doUpdateProfile] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Re-point the running app at a language the profile just saved.
  ///
  /// Saving a locale persisted it and confirmed it, and then the app went on
  /// speaking the old language until its next boot. Five views pass `language`
  /// to [doUpdateProfile], so this belongs here rather than in each of them.
  ///
  /// Delegates to [MagicStarterManager.applyLocale], which defers the actual
  /// switch to a post-frame callback: [Lang.setLocale] loads the catalogue
  /// and calls `Magic.reload()`, which swaps a key above the whole tree and
  /// UNMOUNTS the view that is still inside its own `await` on this method.
  /// The language page, for one, clears an isolated save spinner in a
  /// `finally` on a `ValueNotifier` its own state owns and disposes;
  /// rebuilding before that runs would use it after disposal. Letting the
  /// caller finish first costs one frame and keeps every call site correct
  /// without any of them knowing. [applyLocale]'s shared pending target is
  /// also what keeps this call from double-switching alongside
  /// `MagicStarterServiceProvider`'s own listener, which the `Auth.restore()`
  /// two lines up also wakes.
  ///
  /// A no-op when the language is absent or empty;
  /// [MagicStarterManager.applyLocale] covers the already-current case.
  void _applySavedLanguage(String? language) {
    if (language == null || language.isEmpty) return;

    MagicStarter.manager.applyLocale(language);
  }

  /// Update password.
  Future<bool> doUpdatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.put(
        '/user/password',
        data: {
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      if (!response.successful) {
        await _reportRefusal(
          response,
          fallback: trans('profile.password_update_failed'),
        );
        return false;
      }

      Magic.toast(trans('profile.password_updated'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doUpdatePassword] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Sets the first password of an account that signed up through a provider.
  ///
  /// A first password is a new way into the account, so it is stepped up with
  /// [proof] (see [doDeleteAccount]). On success the user is restored, which
  /// flips `has_password` and with it the page from set to change.
  Future<bool> doSetPassword({
    required String password,
    required String passwordConfirmation,
    required Map<String, String> proof,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/user/password/set',
        data: <String, dynamic>{
          'password': password,
          'password_confirmation': passwordConfirmation,
          ...proof,
        },
      );

      if (!response.successful) {
        await _reportRefusal(
          response,
          fallback: trans('profile.password_set_failed'),
        );
        return false;
      }

      await Auth.restore();
      Magic.toast(trans('profile.password_set'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doSetPassword] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Delete user account.
  ///
  /// [proof] is the step-up proof from `confirmIdentity`: `{password}`,
  /// `{code}`, `{confirmation_token}`, or `{}` for a guest.
  ///
  /// The server schedules the deletion rather than running it and answers
  /// with a sentence that says how to cancel (sign in again within the grace
  /// period). It is shown before the sign-out, since it is the only place the
  /// user learns the account is not gone yet.
  ///
  /// With [immediately] the request carries `immediately: true`: the server
  /// applies the same refusals and step-up, then purges now instead of after
  /// the grace period, and answers 202 with `data.immediate`. The key is
  /// absent otherwise.
  Future<bool> doDeleteAccount({
    required Map<String, String> proof,
    bool immediately = false,
  }) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/user',
        data: <String, dynamic>{
          '_method': 'DELETE',
          ...proof,
          if (immediately) 'immediately': true,
        },
      );
      if (!response.successful) {
        await _reportRefusal(
          response,
          fallback: trans('profile.delete_failed'),
        );
        return false;
      }

      // No before-logout hooks here, unlike the other two sign-out paths
      // (the profile dropdown, `MagicStarterAuthController.logout`): the
      // server has already deleted every token for this user
      // (`magic-starter-laravel`'s `DeleteUser` action), so a hook that makes
      // its own authenticated request (a device-release call, say) answers
      // 401 and the auth interceptor logs out mid-hook, on top of the
      // logout this method already performs below. The push-state and
      // device rows a hook would otherwise release are cascade-deleted with
      // the account regardless.
      final message = response.data?['message'];
      if (message is String && message.isNotEmpty) {
        Magic.toast(message);
      }

      await Auth.logout();
      navigateTo(MagicStarterConfig.loginRoute());
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doDeleteAccount] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  // -------------------------------------------------------------------------
  // Connected accounts
  // -------------------------------------------------------------------------

  /// Unlinks [provider] from the signed-in account, then restores the user.
  ///
  /// The server holds the `last_login_method` line (no password and this is
  /// the last active link) whatever the page shows; the refusal surfaces as
  /// its sentence.
  Future<bool> doDisconnectSocialAccount(String provider) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.delete('/user/social-accounts/$provider');

      if (!response.successful) {
        await _reportRefusal(response, fallback: trans('errors.unexpected'));
        return false;
      }

      await Auth.restore();
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doDisconnectSocialAccount] '
        '$e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Starts linking [provider] and answers the call that opens it, or `null`
  /// when the bridge refused or the user backed out.
  ///
  /// [proof] is the step-up proof from `confirmIdentity`, minted for this call
  /// only: a retry asks for a fresh one, since a confirmation token is single
  /// use. The caller hands the opener to [doConnectSocialAccount] from a user
  /// tap where the platform needs one (a web popup).
  Future<Future<Map<String, dynamic>> Function()?> beginSocialConnect(
    String provider, {
    required Map<String, String> proof,
  }) async {
    setEmpty();
    clearErrors();

    try {
      return await MagicStarter.socialAuth!.beginConnect(provider, proof);
    } on MagicStarterSocialException catch (e) {
      _reportSocialFailure(e);
      return null;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.beginSocialConnect] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return null;
    }
  }

  /// Runs the [opener] [beginSocialConnect] answered, then restores the user.
  ///
  /// The opener is called before anything is awaited, so a web provider popup
  /// still opens inside the tap that called this.
  Future<bool> doConnectSocialAccount(
    Future<Map<String, dynamic>> Function() opener,
  ) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      await opener();
      await Auth.restore();
      setSuccess(true);
      return true;
    } on MagicStarterSocialException catch (e) {
      _reportSocialFailure(e);
      return false;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doConnectSocialAccount] '
        '$e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Shows a social refusal through [socialFailureMessage]. A cancelled flow
  /// shows nothing.
  void _reportSocialFailure(MagicStarterSocialException exception) {
    if (exception.cancelled) return;

    setError(socialFailureMessage(exception));
  }

  /// Update profile photo.
  Future<bool> doUpdateProfilePhoto({required MagicFile file}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.upload(
        "/user/profile-photo",
        data: {},
        files: {"photo": file},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.photo_update_failed'),
        );
        return false;
      }

      await Auth.restore();
      Magic.toast(trans('profile.photo_updated'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doUpdateProfilePhoto] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Delete profile photo.
  Future<bool> doDeleteProfilePhoto() async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.delete('/user/profile-photo');

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.photo_delete_failed'),
        );
        return false;
      }

      await Auth.restore();
      Magic.toast(trans('profile.photo_deleted'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doDeleteProfilePhoto] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Enables two-factor authentication for the current user.
  ///
  /// Requires the step-up [proof] (see [doDeleteAccount]).
  ///
  /// Returns a map containing [secret], [qr_url], [qr_svg], and [recovery_codes]
  /// on success, or null on failure.
  Future<Map<String, dynamic>?> doEnableTwoFactor({
    required Map<String, String> proof,
  }) async {
    if (_isSubmitting) return null;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-authentication',
        data: <String, dynamic>{...proof},
      );

      if (!response.successful) {
        await _reportRefusal(
          response,
          fallback: trans('profile.two_factor_enable_failed'),
        );
        if (!isError) {
          setError(trans('profile.two_factor_enable_failed'));
        }
        return null;
      }

      final data = response.data?['data'] as Map<String, dynamic>?;
      setSuccess(true);
      return data;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doEnableTwoFactor] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return null;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Confirms two-factor authentication setup with the provided OTP code.
  Future<bool> doConfirmTwoFactor({required String code}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-authentication/confirm',
        data: {'code': code},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.two_factor_confirm_failed'),
        );
        return false;
      }

      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doConfirmTwoFactor] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Disables two-factor authentication.
  ///
  /// Requires the step-up [proof] (see [doDeleteAccount]), which is sent
  /// directly to the endpoint (no separate confirm call).
  Future<bool> doDisableTwoFactor({required Map<String, String> proof}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-authentication',
        data: <String, dynamic>{'_method': 'DELETE', ...proof},
      );

      if (!response.successful) {
        await _reportRefusal(
          response,
          fallback: trans('profile.two_factor_disable_failed'),
        );
        return false;
      }

      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doDisableTwoFactor] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Retrieves the current two-factor authentication recovery codes.
  ///
  /// Requires the step-up [proof] (see [doDeleteAccount]). Uses
  /// `POST /two-factor-recovery-codes/show` with the proof in the body.
  Future<List<String>?> getRecoveryCodes({
    required Map<String, String> proof,
  }) async {
    if (_isSubmitting) return null;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-recovery-codes/show',
        data: <String, dynamic>{...proof},
      );

      if (!response.successful) {
        await _reportRefusal(
          response,
          fallback: trans('profile.two_factor_recovery_codes_fetch_failed'),
        );
        return null;
      }

      final data = response.data?['data'] as List<dynamic>?;
      setSuccess(true);
      return data?.map((e) => e.toString()).toList();
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.getRecoveryCodes] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return null;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Regenerates two-factor authentication recovery codes.
  ///
  /// Requires the step-up [proof] (see [doDeleteAccount]), which is sent
  /// directly to the endpoint (no separate confirm call).
  Future<List<String>?> doRegenerateRecoveryCodes({
    required Map<String, String> proof,
  }) async {
    if (_isSubmitting) return null;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/two-factor-recovery-codes',
        data: <String, dynamic>{...proof},
      );

      if (!response.successful) {
        await _reportRefusal(
          response,
          fallback: trans(
            'profile.two_factor_recovery_codes_regenerate_failed',
          ),
        );
        return null;
      }

      final data = response.data?['data'] as List<dynamic>?;
      setSuccess(true);
      return data?.map((e) => e.toString()).toList();
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doRegenerateRecoveryCodes] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
      return null;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Retrieves the current browser sessions.
  Future<List<Map<String, dynamic>>?> getSessions() async {
    if (!MagicStarterConfig.hasSessionsFeatures()) return null;
    if (_isSubmitting) return null;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.get('/sessions');

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('profile.sessions_fetch_error'),
        );
        return null;
      }

      final data = response.data?['data'] as List<dynamic>?;
      setSuccess(true);
      return data?.map((e) => e as Map<String, dynamic>).toList();
    } catch (e, stackTrace) {
      Log.error('[MagicStarterProfileController.getSessions] $e\n$stackTrace');
      setError(trans('profile.sessions_fetch_error'));
      return null;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Revokes a specific browser session by its token ID.
  ///
  /// Requires the step-up [proof] (see [doDeleteAccount]).
  Future<bool> doRevokeSession({
    required String tokenId,
    required Map<String, String> proof,
  }) async {
    if (!MagicStarterConfig.hasSessionsFeatures()) return false;
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/sessions/$tokenId',
        data: <String, dynamic>{'_method': 'DELETE', ...proof},
      );

      if (!response.successful) {
        await _reportRefusal(
          response,
          fallback: trans('profile.session_revoke_error'),
        );
        return false;
      }

      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doRevokeSession] $e\n$stackTrace',
      );
      setError(trans('profile.session_revoke_error'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Revokes all other browser sessions except the current one.
  ///
  /// Requires the step-up [proof] (see [doDeleteAccount]).
  Future<bool> doRevokeOtherSessions({
    required Map<String, String> proof,
  }) async {
    if (!MagicStarterConfig.hasSessionsFeatures()) return false;
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/sessions/other',
        data: <String, dynamic>{'_method': 'DELETE', ...proof},
      );

      if (!response.successful) {
        await _reportRefusal(
          response,
          fallback: trans('profile.other_sessions_revoke_error'),
        );
        return false;
      }

      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.doRevokeOtherSessions] $e\n$stackTrace',
      );
      setError(trans('profile.other_sessions_revoke_error'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Sends a verification email to the authenticated user's email address.
  ///
  /// Calls `POST /email/verification-notification`. On success, shows a toast
  /// confirmation and sets success state. On error, delegates to
  /// [handleApiError] with a localised fallback message.
  Future<void> sendEmailVerification() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();

    try {
      final response = await Http.post(
        '/email/verification-notification',
        data: {},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('magic_starter.email_verification.send_error'),
        );
        return;
      }

      setSuccess(true);
      Magic.toast(trans('magic_starter.email_verification.sent'));
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterProfileController.sendEmailVerification] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Returns whether the authenticated user's email address has been verified.
  ///
  /// Reads `email_verified_at` from the current [Auth.user()] — returns `true`
  /// only when the field resolves to a non-null, non-empty string.
  bool get isEmailVerified {
    final user = Auth.user();
    if (user == null) return false;
    final verifiedAt = user.get<String?>('email_verified_at');
    return verifiedAt != null && verifiedAt.isNotEmpty;
  }

  /// Whether the authenticated user has two-factor authentication enabled.
  ///
  /// Reads [two_factor_enabled] from the current [Auth.user()] model.
  /// Returns [false] when no user is authenticated or the field is absent.
  bool get isTwoFactorEnabled {
    final user = Auth.user();
    if (user == null) return false;
    return user.get<bool>('two_factor_enabled') ?? false;
  }
}
