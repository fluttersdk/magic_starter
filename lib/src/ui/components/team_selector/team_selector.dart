import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../models/magic_starter_team.dart';
import '../../../magic_starter_manager.dart';

/// Team selector widget.
///
/// Displays the current team initial and allows switching between teams via a
/// [WPopover] dropdown. Uses the team resolver registered via
/// `MagicStarter.useTeamResolver()`: teamResolver callbacks, team list
/// rendering, settings/create links.
///
/// ### Example
/// ```dart
/// const MSTeamSelector()
/// // or compact (icon-only) mode:
/// const MSTeamSelector(compact: true)
/// ```
class MSTeamSelector extends StatelessWidget {
  static const _iconCollapse = Icons.unfold_less;
  static const _iconExpand = Icons.unfold_more;

  /// When `true`, hides the team name label and expand icon (icon-only mode).
  final bool compact;

  const MSTeamSelector({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final resolver = MagicStarter.teamResolver;
    if (resolver == null) return const SizedBox.shrink();

    final currentTeam = resolver.currentTeam();
    final allTeams = resolver.allTeams();

    if (allTeams.isEmpty) return const SizedBox.shrink();

    final dropdownTheme = MagicStarter.dropdownTheme;

    // The geometry comes after the theme's colours, and `overflow-hidden` is
    // not a theme field: a hovered row fills its full width, and without the
    // clip its square corners paint over the panel's rounded ones.
    return WPopover(
      alignment: PopoverAlignment.bottomCenter,
      className:
          '''
        ${dropdownTheme.panelClassName}
        w-58 rounded-xl shadow-xl overflow-hidden
      ''',
      triggerBuilder: (context, isOpen, isHovering) => WDiv(
        className:
            'flex flex-row items-center gap-2 mx-3 p-2 rounded-lg ${MagicStarter.navigationTheme.hoverItemClassName}',
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
                    'text-sm font-medium ${dropdownTheme.textClassName} truncate',
              ),
            ),
            WIcon(
              isOpen ? _iconCollapse : _iconExpand,
              className: '${dropdownTheme.mutedTextClassName} text-lg',
            ),
          ],
        ],
      ),
      contentBuilder: (context, close) =>
          _buildTeamList(allTeams, currentTeam, resolver, close),
    );
  }

  Widget _buildTeamList(
    List<MagicStarterTeam> teams,
    MagicStarterTeam? currentTeam,
    MagicStarterTeamResolverConfig resolver,
    VoidCallback close,
  ) {
    final theme = MagicStarter.dropdownTheme;

    return WDiv(
      className: 'py-2',
      children: [
        WDiv(
          className: 'px-3 pb-1',
          child: WText(
            trans('teams.team').toUpperCase(),
            className:
                'text-xs font-bold tracking-wide ${theme.mutedTextClassName}',
          ),
        ),
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
                  'w-full px-3 py-2.5 flex flex-row items-center gap-3 ${theme.itemClassName} active:bg-primary/5',
              children: [
                WDiv(
                  className:
                      'w-8 h-8 rounded-lg ${isActive ? "bg-primary/15" : theme.tileClassName} flex items-center justify-center',
                  child: WText(
                    (team.name ?? '?')[0].toUpperCase(),
                    className:
                        'text-xs font-bold ${isActive ? "text-primary" : theme.mutedTextClassName}',
                  ),
                ),
                Expanded(
                  child: WText(
                    team.name ?? '',
                    className:
                        'text-sm ${isActive ? "font-semibold" : "font-medium"} ${theme.textClassName} truncate',
                  ),
                ),
                if (isActive)
                  WIcon(Icons.check_circle, className: 'text-primary text-lg'),
              ],
            ),
          );
        }),
        WDiv(className: 'my-1.5 mx-3 border-t ${theme.dividerClassName}'),
        WAnchor(
          onTap: () {
            close();
            MagicRoute.to(MagicStarterConfig.teamSettingsRoute());
          },
          child: WDiv(
            className:
                'w-full px-3 py-2.5 flex flex-row items-center gap-3 ${theme.itemClassName}',
            children: [
              WDiv(
                className:
                    'w-8 h-8 rounded-lg ${theme.tileClassName} flex items-center justify-center',
                child: WIcon(
                  Icons.settings_outlined,
                  className: 'text-base ${theme.mutedTextClassName}',
                ),
              ),
              Expanded(
                child: WText(
                  trans('teams.settings'),
                  className:
                      'text-sm font-medium ${theme.textClassName} truncate',
                ),
              ),
            ],
          ),
        ),
        WAnchor(
          onTap: () {
            close();
            MagicRoute.to(MagicStarterConfig.teamCreateRoute());
          },
          child: WDiv(
            className:
                'w-full px-3 py-2.5 flex flex-row items-center gap-3 ${theme.itemClassName}',
            children: [
              WDiv(
                className:
                    'w-8 h-8 rounded-lg bg-primary/10 dark:bg-primary/10 flex items-center justify-center',
                child: const WIcon(
                  Icons.add,
                  className: 'text-base text-primary',
                ),
              ),
              Expanded(
                child: WText(
                  trans('teams.create_team'),
                  className:
                      'text-sm font-medium ${theme.textClassName} truncate',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
