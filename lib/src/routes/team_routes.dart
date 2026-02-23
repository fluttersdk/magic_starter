import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../http/controllers/team_controller.dart';

/// Registers team routes provided by Magic Starter plugin.
void registerMagicStarterTeamRoutes() {
  MagicRoute.group(
    middleware: ['auth'],
    routes: () {
      MagicRoute.page(
        '${MagicStarterConfig.teamsPrefix()}/create',
        TeamController.instance.create,
      ).transition(RouteTransition.none);

      MagicRoute.page(
        '${MagicStarterConfig.teamsPrefix()}/settings',
        TeamController.instance.edit,
      ).transition(RouteTransition.none);

      MagicRoute.page(
        '/invitations/:token',
        TeamController.instance.acceptInvitation,
      ).transition(RouteTransition.none);
    },
  );
}
