import 'package:flutter/widgets.dart';

import '../models/magic_starter_team.dart';

/// A single custom section entry for the team settings view.
///
/// Registered via [MagicStarterTeamSettingsSectionRegistry.registerSection]
/// and rendered after built-in sections (General, Members) sorted by [order].
class MagicStarterTeamSettingsSection {
  /// Unique identifier for this section.
  final String key;

  /// Sort position among custom sections. Lower values render first.
  final int order;

  /// Builder callback that produces the section widget.
  ///
  /// Receives the current [BuildContext] and the active [MagicStarterTeam]
  /// (nullable — team resolver may not be configured).
  final Widget Function(BuildContext context, MagicStarterTeam? team) builder;

  /// Creates a new team settings section definition.
  const MagicStarterTeamSettingsSection({
    required this.key,
    required this.order,
    required this.builder,
  });
}

/// Registry for custom sections in the team settings view.
///
/// Host applications register sections via [registerSection] — each section
/// appears after the built-in General and Members cards, sorted by [order].
///
/// Follows the same keyed-map pattern as [MagicStarterViewRegistry].
///
/// ```dart
/// MagicStarter.teamSettings.registerSection(
///   key: 'billing',
///   order: 10,
///   builder: (context, team) => BillingCard(team: team),
/// );
/// ```
class MagicStarterTeamSettingsSectionRegistry {
  final Map<String, MagicStarterTeamSettingsSection> _sections =
      <String, MagicStarterTeamSettingsSection>{};

  /// Register a custom section for the team settings view.
  ///
  /// If a section with the same [key] already exists, it is replaced.
  /// Sections are sorted by [order] when rendered — lower values appear first.
  void registerSection({
    required String key,
    required int order,
    required Widget Function(BuildContext context, MagicStarterTeam? team)
    builder,
  }) {
    _sections[key] = MagicStarterTeamSettingsSection(
      key: key,
      order: order,
      builder: builder,
    );
  }

  /// Remove a previously registered section by [key].
  ///
  /// No-op if the key does not exist.
  void removeSection(String key) {
    _sections.remove(key);
  }

  /// All registered custom sections, sorted by [order] ascending.
  ///
  /// Sections with equal order values preserve insertion order (stable sort).
  List<MagicStarterTeamSettingsSection> get sections {
    return _sections.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Remove all registered sections. Used for test isolation.
  void clear() {
    _sections.clear();
  }
}
