import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/team_controller.dart';

import '../configuration/magic_starter_config.dart';
import '../http/controllers/team_controller.dart';

/// Registers team routes provided by Magic Starter plugin.
void registerMagicStarterTeamRoutes() {
  MagicRoute.group(
    middleware: ['auth'],
    layout: (child) => MagicStarter.view.makeLayout('layout.app', child: child),
    routes: () {
      MagicRoute.page(
        '${MagicStarterConfig.teamsPrefix()}/create',
        StarterTeamController.instance.create,
      ).transition(RouteTransition.none);

      MagicRoute.page(
        '${MagicStarterConfig.teamsPrefix()}/settings',
        StarterTeamController.instance.edit,
      ).transition(RouteTransition.none);

      MagicRoute.page(
        '/invitations/:token',
        StarterTeamController.instance.acceptInvitation,
      ).transition(RouteTransition.none);
    },
  );
}
