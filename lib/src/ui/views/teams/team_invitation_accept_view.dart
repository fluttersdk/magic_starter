import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/team_controller.dart';
import '../../widgets/auth_form_card.dart';

class MagicStarterTeamInvitationAcceptView
    extends MagicStatefulView<StarterTeamController> {
  const MagicStarterTeamInvitationAcceptView({super.key});

  @override
  State<MagicStarterTeamInvitationAcceptView> createState() =>
      _MagicStarterTeamInvitationAcceptViewState();
}

class _MagicStarterTeamInvitationAcceptViewState extends MagicStatefulViewState<
    StarterTeamController, MagicStarterTeamInvitationAcceptView> {
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
    return controller.renderState(
      (_) => _buildSuccess(),
      onEmpty: _buildDefault(),
      onError: (message) => _buildError(message),
    );
  }

  Widget _buildDefault() {
    return MagicStarterAuthFormCard(
      title: trans('teams.accept_invitation'),
      subtitle: trans('teams.accept_invitation_subtitle'),
      child: WDiv(
        className: 'flex flex-col items-center gap-6',
        children: [
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
            className: '''
                w-full bg-primary hover:bg-primary/80
                text-white text-base font-bold
                p-4 rounded-xl shadow-lg
              ''',
            child: WText(trans('teams.accept_invitation'),
                className: 'text-center'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return MagicStarterAuthFormCard(
      title: trans('teams.accept_invitation'),
      subtitle: trans('teams.accept_invitation_subtitle'),
      child: WDiv(
        className: 'flex flex-col items-center gap-4',
        children: [
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
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return MagicStarterAuthFormCard(
      title: trans('teams.accept_invitation'),
      subtitle: trans('teams.accept_invitation_subtitle'),
      errorMessage: message,
      child: WDiv(
        className: 'flex flex-col items-center gap-4',
        children: [
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
        ],
      ),
    );
  }
}
