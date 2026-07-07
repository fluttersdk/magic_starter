import 'package:flutter/material.dart' show Brightness, Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../http/controllers/magic_starter_profile_controller.dart';
import '../../../components/settings_row/index.dart';
import '../../../components/settings_scaffold/index.dart';
import '../../../components/settings_section/index.dart';

/// The active appearance mode resolved from the live [WindThemeController].
///
/// [system] follows the platform brightness (`syncWithSystem == true`);
/// [light] and [dark] are explicit manual preferences.
enum _AppearanceMode { light, dark, system }

/// Appearance settings sub-page — light / dark / system theme selector.
///
/// Binds directly to wind's [WindThemeController] (no parallel theme system):
///
/// - **Light / Dark** call [WindThemeController.setTheme] with
///   `syncWithSystem: false`, marking the choice as a manual preference. This
///   mirrors [WindThemeController.toggleTheme]'s contract (manual selection
///   stops system overrides) and triggers `WindTheme.onThemeChanged`, which
///   [MagicApplication] persists to `Vault` and restores on next boot.
/// - **System** calls [WindThemeController.resetToSystem], re-enabling
///   automatic system-brightness sync.
///
/// The active mode is reflected in the selected option card. All three modes
/// ship; persistence is handled by the framework's theme-preference layer
/// (`MagicApplication` + `WindTheme.onThemeChanged` -> `Vault`), so this view
/// owns no persistence of its own.
class MagicStarterAppearanceView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterAppearanceView({super.key});

  @override
  State<MagicStarterAppearanceView> createState() =>
      _MagicStarterAppearanceViewState();
}

class _MagicStarterAppearanceViewState extends MagicStatefulViewState<
    MagicStarterProfileController, MagicStarterAppearanceView> {
  // Static icon constants extracted for Flutter web tree-shaking.
  static const _iconLight = Icons.light_mode_outlined;
  static const _iconDark = Icons.dark_mode_outlined;
  static const _iconSystem = Icons.brightness_auto_outlined;
  static const _iconSelected = Icons.check_circle;

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  /// Resolves the currently active appearance mode from the theme controller.
  ///
  /// `syncWithSystem` takes precedence — when the theme follows the system it
  /// is [_AppearanceMode.system] regardless of the resolved brightness.
  _AppearanceMode _activeMode(WindThemeController theme) {
    if (theme.data.syncWithSystem) {
      return _AppearanceMode.system;
    }
    return theme.brightness == Brightness.dark
        ? _AppearanceMode.dark
        : _AppearanceMode.light;
  }

  /// Applies the chosen [mode] to the live [theme] controller.
  ///
  /// Explicit light/dark set a manual preference (`syncWithSystem: false`) so a
  /// later system brightness change does not override it; system resets to
  /// automatic sync.
  void _selectMode(WindThemeController theme, _AppearanceMode mode) {
    switch (mode) {
      case _AppearanceMode.light:
        theme.setTheme(
          theme.data.copyWith(
            brightness: Brightness.light,
            syncWithSystem: false,
          ),
        );
      case _AppearanceMode.dark:
        theme.setTheme(
          theme.data.copyWith(
            brightness: Brightness.dark,
            syncWithSystem: false,
          ),
        );
      case _AppearanceMode.system:
        theme.resetToSystem();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the WindThemeController so the selected card reflects live
    // theme changes (including system-driven ones) without manual setState.
    final theme = WindTheme.of(context);
    final active = _activeMode(theme);

    return MSSettingsScaffold(
      title: trans('magic_starter.appearance.title'),
      subtitle: trans('magic_starter.appearance.subtitle'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        MSSettingsSection(
          footer: trans('magic_starter.appearance.section_footer'),
          children: [
            _buildOptionRow(
              theme: theme,
              mode: _AppearanceMode.light,
              icon: _iconLight,
              title: trans('magic_starter.appearance.light'),
              subtitle: trans('magic_starter.appearance.light_description'),
              active: active,
            ),
            _buildOptionRow(
              theme: theme,
              mode: _AppearanceMode.dark,
              icon: _iconDark,
              title: trans('magic_starter.appearance.dark'),
              subtitle: trans('magic_starter.appearance.dark_description'),
              active: active,
            ),
            _buildOptionRow(
              theme: theme,
              mode: _AppearanceMode.system,
              icon: _iconSystem,
              title: trans('magic_starter.appearance.system'),
              subtitle: trans('magic_starter.appearance.system_description'),
              active: active,
            ),
          ],
        ),
      ],
    );
  }

  /// Builds a single option card row with a trailing check when selected.
  Widget _buildOptionRow({
    required WindThemeController theme,
    required _AppearanceMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required _AppearanceMode active,
  }) {
    final isSelected = mode == active;
    return MSSettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => _selectMode(theme, mode),
      trailing: isSelected
          ? WIcon(
              _iconSelected,
              className: 'text-primary',
            )
          : null,
    );
  }
}
