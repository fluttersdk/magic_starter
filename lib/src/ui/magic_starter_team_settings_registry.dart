import 'package:flutter/widgets.dart';

import '../models/magic_starter_team.dart';

/// Builder function for custom team settings sections.
///
/// Receives the current [BuildContext] and the active [MagicStarterTeam]
/// (nullable when the team resolver is not configured or returns null).
typedef TeamSettingsSectionBuilder =
    Widget Function(BuildContext context, MagicStarterTeam? team);

/// Registry for custom sections in the team settings view.
///
/// Host apps register additional cards (billing, integrations, preferences)
/// that render after the built-in General, Members, and Invitations sections.
///
/// ```dart
/// MagicStarter.teamSettings.registerSection(
///   key: 'billing',
///   order: 10,
///   builder: (context, team) => MagicStarterCard(
///     title: 'Billing',
///     child: BillingForm(teamId: team?.id),
///   ),
/// );
/// ```
class MagicStarterTeamSettingsRegistry {
  final Map<String, _TeamSettingsSection> _sections =
      <String, _TeamSettingsSection>{};

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Register a custom section under [key].
  ///
  /// If a section with the same [key] already exists it is replaced.
  /// Sections are rendered sorted by [order] ascending — lower values
  /// appear higher on the page.
  void registerSection({
    required String key,
    required int order,
    required TeamSettingsSectionBuilder builder,
  }) {
    _sections[key] = _TeamSettingsSection(
      key: key,
      order: order,
      builder: builder,
    );
  }

  /// Remove a previously registered section by [key].
  ///
  /// Does nothing when [key] is not registered.
  void removeSection(String key) {
    _sections.remove(key);
  }

  /// Build all registered sections sorted by [order] ascending.
  ///
  /// Returns an empty list when no sections are registered.
  List<Widget> buildSections(BuildContext context, MagicStarterTeam? team) {
    if (_sections.isEmpty) return const [];

    final sorted = _sections.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return sorted
        .map((section) => section.builder(context, team))
        .toList(growable: false);
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  /// Clear all registered sections. Called by [MagicStarterManager.reset].
  void clear() {
    _sections.clear();
  }
}

/// Internal model for a registered team settings section.
class _TeamSettingsSection {
  final String key;
  final int order;
  final TeamSettingsSectionBuilder builder;

  const _TeamSettingsSection({
    required this.key,
    required this.order,
    required this.builder,
  });
}
