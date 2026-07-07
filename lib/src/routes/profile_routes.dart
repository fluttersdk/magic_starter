import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/magic_starter_newsletter_controller.dart';
import '../http/controllers/magic_starter_profile_controller.dart';

/// Resolves a settings view backed by [MagicStarterProfileController].
///
/// `MagicStatefulView` resolves its controller with `Magic.find<T>()`, which
/// requires the controller to already be registered. The legacy single-page
/// route registered it implicitly by reading `controller.instance`; the
/// registry-driven sub-pages do not, so the controller must be put into the
/// container here before the view builds.
Widget _profileSettingsView(String key) {
  Magic.findOrPut(MagicStarterProfileController.new);
  return MagicStarter.view.make(key);
}

/// Resolves the newsletter sub-page, registering its controller first.
Widget _newsletterSettingsView() {
  Magic.findOrPut(MagicStarterNewsletterController.new);
  return MagicStarter.view.make('settings.newsletter');
}

/// Registers profile/settings routes provided by Magic Starter plugin.
///
/// The Settings surface is an iOS-style hub (`/settings`) that drills into
/// grouped sub-pages. Every route uses a flat absolute path and resolves its
/// view through the registry, so each screen stays overridable via
/// `MagicStarter.view.register(...)`. Sub-routes are feature-gated: a disabled
/// feature means the route is never registered.
void registerMagicStarterProfileRoutes() {
  MagicRoute.group(
    middleware: ['auth'],
    layoutId: 'app',
    layout: (child) => MagicStarter.view.makeLayout('layout.app', child: child),
    routes: () {
      // Hub index — the default Settings destination.
      MagicRoute.page(
        MagicStarterConfig.settingsHubRoute(),
        () => _profileSettingsView('settings.hub'),
      ).transition(RouteTransition.none);

      // Profile sub-page — always available.
      MagicRoute.page(
        MagicStarterConfig.profileRoute(),
        () => _profileSettingsView('profile.profile'),
      ).transition(RouteTransition.none);

      // Appearance (theme) sub-page — always available (mirrors the hub row,
      // which renders Appearance unconditionally).
      MagicRoute.page(
        MagicStarterConfig.settingsAppearanceRoute(),
        () => _profileSettingsView('settings.appearance'),
      ).transition(RouteTransition.none);

      // Password sub-page — always available. The hub gates the Password row
      // by the `starter.update-password` Gate only (no feature flag), so the
      // route stays registered like a core auth action.
      MagicRoute.page(
        MagicStarterConfig.settingsPasswordRoute(),
        () => _profileSettingsView('settings.security.password'),
      ).transition(RouteTransition.none);

      // Language sub-page — extended profile / locale selection.
      if (MagicStarterConfig.hasExtendedProfileFeatures()) {
        MagicRoute.page(
          MagicStarterConfig.settingsLanguageRoute(),
          () => _profileSettingsView('settings.language'),
        ).transition(RouteTransition.none);
      }

      // Timezone sub-page.
      if (MagicStarterConfig.hasTimezoneFeatures()) {
        MagicRoute.page(
          MagicStarterConfig.settingsTimezoneRoute(),
          () => _profileSettingsView('settings.timezone'),
        ).transition(RouteTransition.none);
      }

      // Newsletter sub-page.
      if (MagicStarterConfig.hasNewsletterFeatures()) {
        MagicRoute.page(
          MagicStarterConfig.settingsNewsletterRoute(),
          () => _newsletterSettingsView(),
        ).transition(RouteTransition.none);
      }

      // Security — Two-Factor sub-page.
      if (MagicStarterConfig.hasTwoFactorFeatures()) {
        MagicRoute.page(
          MagicStarterConfig.settingsTwoFactorRoute(),
          () => _profileSettingsView('settings.security.two_factor'),
        ).transition(RouteTransition.none);
      }

      // Security — Active Sessions sub-page.
      if (MagicStarterConfig.hasSessionsFeatures()) {
        MagicRoute.page(
          MagicStarterConfig.settingsSessionsRoute(),
          () => _profileSettingsView('settings.security.sessions'),
        ).transition(RouteTransition.none);
      }
    },
  );
}
