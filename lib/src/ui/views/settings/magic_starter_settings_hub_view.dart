import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_profile_controller.dart';
import '../../components/page_scaffold/index.dart';
import '../../widgets/magic_starter_app_version.dart';
import '../../widgets/magic_starter_settings_account_group.dart';
import '../../widgets/magic_starter_settings_preferences_group.dart';
import '../../widgets/magic_starter_settings_security_group.dart';

/// iOS-style Settings hub --- the drill-down index for the starter.
///
/// Replaces the single long-form profile settings page with a grouped list of
/// nav rows that push into focused sub-pages. The hub itself performs no API
/// calls, and reuses [MagicStarterProfileController] purely so it slots into
/// the same [MagicStatefulView] lifecycle as the other settings views.
///
/// The sections are the public [MagicStarterSettingsAccountGroup],
/// [MagicStarterSettingsSecurityGroup] and
/// [MagicStarterSettingsPreferencesGroup], each carrying its own feature and
/// [Gate] checks, so a host that registers its own `settings.hub` composes the
/// same sections without copying them. The Security group is left out when
/// none of its rows is reachable.
///
/// With the `releases` feature on, the Preferences group ends in a "What's new"
/// row and the page closes on a [MagicStarterAppVersion] caption naming the
/// running build, below the footer slot, so a consumer's own footer groups
/// (team, about) sit above it and the caption is the last thing on the page.
///
/// Header and footer injection points are exposed through the view registry
/// slots `settings.hub.header` and `settings.hub.footer`.
class MagicStarterSettingsHubView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterSettingsHubView({super.key});

  @override
  State<MagicStarterSettingsHubView> createState() =>
      _MagicStarterSettingsHubViewState();
}

class _MagicStarterSettingsHubViewState
    extends
        MagicStatefulViewState<
          MagicStarterProfileController,
          MagicStarterSettingsHubView
        > {
  @override
  Widget build(BuildContext context) {
    // 1. Resolve registry slots so host apps can inject around the hub.
    final headerSlot = MagicStarter.view.buildSlot(
      'settings.hub',
      'header',
      context,
    );
    final footerSlot = MagicStarter.view.buildSlot(
      'settings.hub',
      'footer',
      context,
    );

    // 2. Assemble the groups between the slots. They are not const: the hub
    //    rebuilds on a controller notify, and a const group would keep the
    //    user it read on its first build.
    return MSPageScaffold(
      title: trans('magic_starter.nav.settings'),
      children: [
        ?headerSlot,
        MagicStarterSettingsAccountGroup(),
        // A zero-size child still takes a gap in the sections column.
        if (MagicStarterSettingsSecurityGroup.hasRows)
          MagicStarterSettingsSecurityGroup(),
        MagicStarterSettingsPreferencesGroup(),
        ?footerSlot,
        if (MagicStarterConfig.hasReleasesFeatures())
          const MagicStarterAppVersion(),
      ],
    );
  }
}
