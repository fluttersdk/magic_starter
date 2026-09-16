import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/magic_starter_team_controller.dart';

/// Registers team routes provided by Magic Starter plugin.
///
/// Routes are only registered when `magic_starter.features.teams` is enabled.
/// When disabled, calling this function is a no-op.
///
/// Create and settings are `.stacked()`: both are reached by drilling in from
/// the team switcher or the settings hub, and a route that replaces leaves the
/// Navigator one page deep, which costs the iOS edge swipe and makes Android's
/// system back leave the app. Invitation acceptance is not stacked, because it
/// is an ARRIVAL: the link comes from an email and there is nothing behind it
/// to go back to.
void registerMagicStarterTeamRoutes() {
  if (!MagicStarterConfig.hasTeamFeatures()) return;

  MagicRoute.group(
    middleware: ['auth'],
    layoutId: 'app',
    layout: (child) => MagicStarter.view.makeLayout('layout.app', child: child),
    routes: () {
      MagicRoute.page(
        '${MagicStarterConfig.teamsPrefix()}/create',
        MagicStarterTeamController.instance.create,
      ).title('magic_starter.titles.team_create').stacked();

      MagicRoute.page(
        '${MagicStarterConfig.teamsPrefix()}/settings',
        MagicStarterTeamController.instance.edit,
      ).title('magic_starter.titles.team_settings').stacked();

      MagicRoute.page(
            '/invitations/:token/accept',
            MagicStarterTeamController.instance.acceptInvitation,
          )
          .title('magic_starter.titles.team_invitation')
          .transition(RouteTransition.none);
    },
  );
}
