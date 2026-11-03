import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart'
    show ButtonIntent, ButtonSize, MSButton;

import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_handoff_controller.dart';
import '../../widgets/magic_starter_auth_form_card.dart';

/// The sign-in handoff page (`/auth/handoff?code=&next=`).
///
/// Shows "signing in" while [MagicStarterHandoffController.handOff] runs, once,
/// with the route's `code` and `next`, and is replaced by wherever that lands.
/// A valid answer turns it into a confirmation naming the handed account with
/// Continue and Cancel, worded for whether a session is open. It never shows
/// the code or anything the exchange refused with.
class MagicStarterHandoffView
    extends MagicStatefulView<MagicStarterHandoffController> {
  const MagicStarterHandoffView({super.key});

  @override
  State<MagicStarterHandoffView> createState() =>
      _MagicStarterHandoffViewState();
}

class _MagicStarterHandoffViewState
    extends
        MagicStatefulViewState<
          MagicStarterHandoffController,
          MagicStarterHandoffView
        > {
  bool _started = false;

  // The route state cannot be read in initState, and the handoff navigates,
  // which cannot happen inside this frame: it starts after it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final MagicRouter router = MagicRouter.instance;
    final String? code = router.queryParameterOf(context, 'code');
    final String? next = router.queryParameterOf(context, 'next');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.handOff(code: code, next: next);
    });
  }

  /// An unanswered confirmation dies with the screen, token included.
  @override
  void onClose() => controller.forget();

  @override
  Widget build(BuildContext context) {
    if (!controller.isConfirming) return _buildSigningIn();

    return _buildConfirmation(controller.confirmingAs);
  }

  Widget _buildSigningIn() {
    return MagicStarterAuthFormCard(
      title: trans('magic_starter.titles.handoff'),
      subtitle: trans('magic_starter.handoff.signing_in'),
      child: const WDiv(
        className: 'flex flex-col items-center py-4',
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }

  /// Asks before signing in as [identity]; Continue comes first in reading and
  /// focus order, Cancel keeps any open session as it is.
  Widget _buildConfirmation(String? identity) {
    return MagicStarterAuthFormCard(
      title: identity == null
          ? trans('magic_starter.handoff.confirm_title_unknown')
          : trans('magic_starter.handoff.confirm_title', {
              'identity': identity,
            }),
      subtitle: trans(
        Auth.check()
            ? 'magic_starter.handoff.confirm_description'
            : 'magic_starter.handoff.confirm_description_signed_out',
      ),
      child: WDiv(
        className: 'flex flex-col items-stretch gap-3',
        children: [
          MSButton(
            onPressed: controller.confirm,
            size: ButtonSize.lg,
            className: MagicStarter.formTheme.primaryButtonClassName,
            child: WText(
              trans('magic_starter.handoff.continue_button'),
              className: 'text-center',
            ),
          ),
          MSButton(
            onPressed: controller.cancel,
            intent: ButtonIntent.secondary,
            size: ButtonSize.lg,
            className: 'w-full',
            child: WText(
              trans('magic_starter.handoff.cancel_button'),
              className: 'text-center',
            ),
          ),
        ],
      ),
    );
  }
}
