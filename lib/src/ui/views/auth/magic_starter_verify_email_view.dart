import 'package:flutter/material.dart' show CircularProgressIndicator, Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart' show MSButton;

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_auth_controller.dart';
import '../../widgets/magic_starter_auth_form_card.dart';

/// The page the verification mail opens: it verifies on arrival and says so.
///
/// The link carries `id`, `hash`, `expires` and `signature` as query
/// parameters, and they are replayed once, on the first dependency read. The
/// route sits outside the guest group, so a signed-in viewer lands here too
/// and continues to the app; a signed-out one continues to sign in.
class MagicStarterVerifyEmailView
    extends MagicStatefulView<MagicStarterAuthController> {
  const MagicStarterVerifyEmailView({super.key});

  @override
  State<MagicStarterVerifyEmailView> createState() =>
      _MagicStarterVerifyEmailViewState();
}

class _MagicStarterVerifyEmailViewState
    extends
        MagicStatefulViewState<
          MagicStarterAuthController,
          MagicStarterVerifyEmailView
        > {
  static const _iconCheck = Icons.check_circle_outline;
  static const _iconError = Icons.error_outline;

  bool _started = false;

  /// The `id` the link verifies, kept to tell a reader signed in as someone
  /// else that the address is verified without calling it theirs.
  String _linkUserId = '';

  /// A user key (uuid or integer) and a sha1 hash. Dio normalises `..` out of
  /// a path, so an unchecked `id=..` sent the reader's bearer to another API
  /// path; only a key-shaped link is replayed.
  static final RegExp _keyShape = RegExp(r'^[0-9A-Za-z-]+$');
  static final RegExp _hashShape = RegExp(r'^[0-9a-f]{40}$');

  @override
  void onInit() {
    controller.clearErrors();
    controller.setLoading();
  }

  // The route state cannot be read in initState; this runs again on inherited
  // changes, and a second replay would only answer "already verified".
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final MagicRouter router = MagicRouter.instance;
    final Map<String, String> link = {
      for (final String key in ['id', 'hash', 'expires', 'signature'])
        key: router.queryParameterOf(context, key) ?? '',
    };

    if (link.values.any((value) => value.isEmpty) ||
        !_keyShape.hasMatch(link['id']!) ||
        !_hashShape.hasMatch(link['hash']!)) {
      controller.setError(
        trans('magic_starter.email_verification.verify_failed'),
      );
      return;
    }

    _linkUserId = link['id']!;
    controller.doVerifyEmail(
      id: link['id']!,
      hash: link['hash']!,
      expires: link['expires']!,
      signature: link['signature']!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MagicStarterAuthFormCard(
      title: trans('magic_starter.titles.verify_email'),
      subtitle: trans('magic_starter.email_verification.verify_subtitle'),
      child: controller.renderState(
        (_) => _buildOutcome(
          icon: _iconCheck,
          iconClassName: 'text-[32px] text-green-600 dark:text-green-400',
          badgeClassName: 'bg-green-50 dark:bg-green-900/20',
          message: trans(
            _verifiesSomeoneElse
                ? 'magic_starter.email_verification.verify_success_other'
                : 'magic_starter.email_verification.verify_success',
          ),
        ),
        onLoading: _buildVerifying(),
        onError: (message) => _buildOutcome(
          icon: _iconError,
          iconClassName: 'text-[32px] text-red-600 dark:text-red-400',
          badgeClassName: 'bg-red-50 dark:bg-red-900/20',
          message: message,
        ),
      ),
    );
  }

  /// Whether the reader is signed in as a user other than the one the link
  /// verified: the API route is public, so that link still verifies its owner.
  bool get _verifiesSomeoneElse {
    final Object? signedInId = Auth.id();

    return signedInId != null && '$signedInId' != _linkUserId;
  }

  Widget _buildVerifying() {
    return WDiv(
      className: 'flex flex-col items-center gap-4 py-4',
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        WText(
          trans('magic_starter.email_verification.verifying'),
          className: 'text-sm text-fg-muted text-center',
        ),
      ],
    );
  }

  Widget _buildOutcome({
    required IconData icon,
    required String iconClassName,
    required String badgeClassName,
    required String message,
  }) {
    final bool signedIn = Auth.check();

    return WDiv(
      className: 'flex flex-col items-stretch gap-4',
      children: [
        WDiv(
          className: 'flex flex-col items-center gap-4',
          children: [
            WDiv(
              className:
                  'w-16 h-16 rounded-full $badgeClassName flex items-center justify-center',
              child: WIcon(icon, className: iconClassName),
            ),
            WText(message, className: 'text-sm text-fg-muted text-center'),
          ],
        ),
        const WSpacer(className: 'h-2'),
        MSButton(
          onPressed: () => MagicRoute.to(
            signedIn
                ? MagicStarterConfig.homeRoute()
                : MagicStarterConfig.loginRoute(),
          ),
          className: MagicStarter.formTheme.primaryButtonClassName,
          child: WText(
            trans(
              signedIn
                  ? 'magic_starter.email_verification.continue'
                  : 'auth.back_to_login',
            ),
            className: 'text-center',
          ),
        ),
      ],
    );
  }
}
