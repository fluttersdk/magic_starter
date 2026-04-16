import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_team_controller.dart';
import '../../widgets/magic_starter_auth_form_card.dart';

class MagicStarterTeamInvitationAcceptView
    extends MagicStatefulView<MagicStarterTeamController> {
  const MagicStarterTeamInvitationAcceptView({super.key});

  @override
  State<MagicStarterTeamInvitationAcceptView> createState() =>
      _MagicStarterTeamInvitationAcceptViewState();
}

class _MagicStarterTeamInvitationAcceptViewState extends MagicStatefulViewState<
    MagicStarterTeamController, MagicStarterTeamInvitationAcceptView> {
  late final _token = MagicRouter.instance.pathParameter('token') ?? '';

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  Future<void> _accept() async {
    final success = await controller.doAcceptInvitation(token: _token);
    if (success) {
      MagicRoute.to(MagicStarterConfig.homeRoute());
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerSlot = MagicStarter.view
        .buildSlot('teams.invitation_accept', 'header', context);
    final footerSlot = MagicStarter.view
        .buildSlot('teams.invitation_accept', 'footer', context);

    return controller.renderState(
      (_) => _buildSuccess(headerSlot: headerSlot, footerSlot: footerSlot),
      onEmpty: _buildDefault(headerSlot: headerSlot, footerSlot: footerSlot),
      onError: (message) =>
          _buildError(message, headerSlot: headerSlot, footerSlot: footerSlot),
    );
  }

  Widget _buildDefault({Widget? headerSlot, Widget? footerSlot}) {
    final formTheme = MagicStarter.formTheme;

    return MagicStarterAuthFormCard(
      title: trans('teams.accept_invitation'),
      subtitle: trans('teams.accept_invitation_subtitle'),
      child: WDiv(
        className: 'flex flex-col items-center gap-6',
        children: [
          if (headerSlot != null) headerSlot,
          WDiv(
            className:
                'w-16 h-16 rounded-full bg-primary/10 dark:bg-primary/10 flex items-center justify-center',
            child: WIcon(
              Icons.group_add_outlined,
              className: 'text-[32px] text-primary',
            ),
          ),
          WButton(
            onTap: _accept,
            isLoading: controller.isLoading,
            className: formTheme.primaryButtonClassName,
            child: WText(
              trans('teams.accept_invitation'),
              className: 'text-center',
            ),
          ),
          if (footerSlot != null) footerSlot,
        ],
      ),
    );
  }

  Widget _buildSuccess({Widget? headerSlot, Widget? footerSlot}) {
    return MagicStarterAuthFormCard(
      title: trans('teams.accept_invitation'),
      subtitle: trans('teams.accept_invitation_subtitle'),
      child: WDiv(
        className: 'flex flex-col items-center gap-4',
        children: [
          if (headerSlot != null) headerSlot,
          WDiv(
            className:
                'w-16 h-16 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center',
            child: WIcon(
              Icons.check_circle_outline,
              className: 'text-[32px] text-green-600 dark:text-green-400',
            ),
          ),
          WText(
            trans('teams.invite_accepted'),
            className: 'text-sm text-gray-600 dark:text-gray-400 text-center',
          ),
          const WSpacer(className: 'h-2'),
          WAnchor(
            onTap: () => MagicRoute.to(MagicStarterConfig.homeRoute()),
            child: WText(
              trans('common.go_to_dashboard'),
              className: 'text-sm font-semibold text-primary',
            ),
          ),
          if (footerSlot != null) footerSlot,
        ],
      ),
    );
  }

  Widget _buildError(
    String message, {
    Widget? headerSlot,
    Widget? footerSlot,
  }) {
    return MagicStarterAuthFormCard(
      title: trans('teams.accept_invitation'),
      subtitle: trans('teams.accept_invitation_subtitle'),
      errorMessage: message,
      child: WDiv(
        className: 'flex flex-col items-center gap-4',
        children: [
          if (headerSlot != null) headerSlot,
          WDiv(
            className:
                'w-16 h-16 rounded-full bg-red-50 dark:bg-red-900/20 flex items-center justify-center',
            child: WIcon(
              Icons.error_outline,
              className: 'text-[32px] text-red-600 dark:text-red-400',
            ),
          ),
          const WSpacer(className: 'h-2'),
          WAnchor(
            onTap: () => MagicRoute.to(MagicStarterConfig.homeRoute()),
            child: WText(
              trans('common.go_to_dashboard'),
              className: 'text-sm font-semibold text-primary',
            ),
          ),
          if (footerSlot != null) footerSlot,
        ],
      ),
    );
  }
}
