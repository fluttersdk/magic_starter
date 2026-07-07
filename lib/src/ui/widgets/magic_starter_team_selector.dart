// Thin alias — MagicStarterTeamSelector is preserved for backward
// compatibility. The implementation now lives in
// components/team_selector/team_selector.dart.

import '../components/team_selector/team_selector.dart';

export '../components/team_selector/team_selector.dart' show MSTeamSelector;

/// Backward-compatible alias for [MSTeamSelector].
class MagicStarterTeamSelector extends MSTeamSelector {
  const MagicStarterTeamSelector({super.key, super.compact});
}
