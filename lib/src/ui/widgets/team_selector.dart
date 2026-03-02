import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';
import '../../models/starter_team.dart';
import '../../magic_starter_manager.dart';

/// Team selector widget for Magic Starter.
///
/// Displays the current team and allows switching between teams.
/// Uses the team resolver registered via `MagicStarter.useTeamResolver()`.
class MagicStarterTeamSelector extends StatelessWidget {
  final bool compact;

  const MagicStarterTeamSelector({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final resolver = MagicStarter.teamResolver;
    if (resolver == null) return const SizedBox.shrink();

    final currentTeam = resolver.currentTeam();
    final allTeams = resolver.allTeams();

    if (allTeams.isEmpty) return const SizedBox.shrink();

    return WPopover(
      alignment: PopoverAlignment.bottomCenter,
      className: '''
        w-58
        bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        rounded-xl shadow-xl
      ''',
      triggerBuilder: (context, isOpen, isHovering) => WDiv(
        className:
            'flex flex-row items-center gap-2 mx-3 p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800',
        children: [
          WDiv(
            className:
                'w-8 h-8 rounded-lg bg-primary/10 dark:bg-primary/10 flex items-center justify-center',
            child: WText(
              (currentTeam?.name ?? '?')[0].toUpperCase(),
              className: 'text-sm font-bold text-primary',
            ),
          ),
          if (!compact) ...[
            Expanded(
              child: WText(
                currentTeam?.name ?? trans('teams.select_team'),
                className:
                    'text-sm font-medium text-gray-900 dark:text-white truncate',
              ),
            ),
            WIcon(
              isOpen ? Icons.unfold_less : Icons.unfold_more,
              className: 'text-gray-400 text-lg',
            ),
          ],
        ],
      ),
      contentBuilder: (context, close) =>
          _buildTeamList(allTeams, currentTeam, resolver, close),
    );
  }

  Widget _buildTeamList(
    List<StarterTeam> teams,
    StarterTeam? currentTeam,
    StarterTeamResolverConfig resolver,
    VoidCallback close,
  ) {
    return WDiv(
      className: 'py-2',
      children: [
        // Section label
        WDiv(
          className: 'px-3 pb-1',
          child: WText(
            trans('teams.team').toUpperCase(),
            className:
                'text-xs font-bold tracking-wide text-gray-400 dark:text-gray-500',
          ),
        ),
        // Team list
        ...teams.map((team) {
          final isActive = team.id == currentTeam?.id;
          return WAnchor(
            onTap: () {
              close();
              if (!isActive) resolver.onSwitch(team.id);
            },
            child: WDiv(
              states: {if (isActive) 'active'},
              className:
                  'w-full px-3 py-2.5 flex flex-row items-center gap-3 hover:bg-gray-50 dark:hover:bg-gray-700/50 active:bg-primary/5',
              children: [
                WDiv(
                  className:
                      'w-8 h-8 rounded-lg ${isActive ? "bg-primary/15" : "bg-gray-100 dark:bg-gray-700"} flex items-center justify-center',
                  child: WText(
                    (team.name ?? '?')[0].toUpperCase(),
                    className:
                        'text-xs font-bold ${isActive ? "text-primary" : "text-gray-500 dark:text-gray-400"}',
                  ),
                ),
                Expanded(
                  child: WText(
                    team.name ?? '',
                    className:
                        'text-sm ${isActive ? "font-semibold text-gray-900 dark:text-white" : "font-medium text-gray-700 dark:text-gray-300"} truncate',
                  ),
                ),
                if (isActive)
                  WIcon(
                    Icons.check_circle,
                    className: 'text-primary text-lg',
                  ),
              ],
            ),
          );
        }),
        // Divider
        WDiv(
          className:
              'my-1.5 mx-3 border-t border-gray-100 dark:border-gray-700',
        ),
        // Team Settings
        WAnchor(
          onTap: () {
            close();
            MagicRoute.to(MagicStarterConfig.teamSettingsRoute());
          },
          child: WDiv(
            className:
                'w-full px-3 py-2.5 flex flex-row items-center gap-3 hover:bg-gray-50 dark:hover:bg-gray-700/50',
            children: [
              WDiv(
                className:
                    'w-8 h-8 rounded-lg bg-gray-100 dark:bg-gray-700 flex items-center justify-center',
                child: const WIcon(
                  Icons.settings_outlined,
                  className: 'text-base text-gray-500 dark:text-gray-400',
                ),
              ),
              WText(
                trans('teams.settings'),
                className:
                    'text-sm font-medium text-gray-700 dark:text-gray-300',
              ),
            ],
          ),
        ),
        // Create New Team
        WAnchor(
          onTap: () {
            close();
            MagicRoute.to(MagicStarterConfig.teamCreateRoute());
          },
          child: WDiv(
            className:
                'w-full px-3 py-2.5 flex flex-row items-center gap-3 hover:bg-gray-50 dark:hover:bg-gray-700/50',
            children: [
              WDiv(
                className:
                    'w-8 h-8 rounded-lg bg-primary/10 dark:bg-primary/10 flex items-center justify-center',
                child: const WIcon(
                  Icons.add,
                  className: 'text-base text-primary',
                ),
              ),
              WText(
                trans('teams.create_team'),
                className:
                    'text-sm font-medium text-gray-700 dark:text-gray-300',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
