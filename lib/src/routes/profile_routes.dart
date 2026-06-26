import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';

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
        () => MagicStarter.view.make('settings.hub'),
      ).transition(RouteTransition.none);

      // Profile sub-page — always available.
      MagicRoute.page(
        MagicStarterConfig.profileRoute(),
        () => MagicStarter.view.make('profile.profile'),
      ).transition(RouteTransition.none);

      // Appearance (theme) sub-page — always available (mirrors the hub row,
      // which renders Appearance unconditionally).
      MagicRoute.page(
        MagicStarterConfig.settingsAppearanceRoute(),
        () => MagicStarter.view.make('settings.appearance'),
      ).transition(RouteTransition.none);

      // Password sub-page — always available. The hub gates the Password row
      // by the `starter.update-password` Gate only (no feature flag), so the
      // route stays registered like a core auth action.
      MagicRoute.page(
        MagicStarterConfig.settingsPasswordRoute(),
        () => MagicStarter.view.make('settings.security.password'),
      ).transition(RouteTransition.none);

      // Language sub-page — extended profile / locale selection.
      if (MagicStarterConfig.hasExtendedProfileFeatures()) {
        MagicRoute.page(
          MagicStarterConfig.settingsLanguageRoute(),
          () => MagicStarter.view.make('settings.language'),
        ).transition(RouteTransition.none);
      }

      // Timezone sub-page.
      if (MagicStarterConfig.hasTimezoneFeatures()) {
        MagicRoute.page(
          MagicStarterConfig.settingsTimezoneRoute(),
          () => MagicStarter.view.make('settings.timezone'),
        ).transition(RouteTransition.none);
      }

      // Newsletter sub-page.
      if (MagicStarterConfig.hasNewsletterFeatures()) {
        MagicRoute.page(
          MagicStarterConfig.settingsNewsletterRoute(),
          () => MagicStarter.view.make('settings.newsletter'),
        ).transition(RouteTransition.none);
      }

      // Security — Two-Factor sub-page.
      if (MagicStarterConfig.hasTwoFactorFeatures()) {
        MagicRoute.page(
          MagicStarterConfig.settingsTwoFactorRoute(),
          () => MagicStarter.view.make('settings.security.two_factor'),
        ).transition(RouteTransition.none);
      }

      // Security — Active Sessions sub-page.
      if (MagicStarterConfig.hasSessionsFeatures()) {
        MagicRoute.page(
          MagicStarterConfig.settingsSessionsRoute(),
          () => MagicStarter.view.make('settings.security.sessions'),
        ).transition(RouteTransition.none);
      }
    },
  );
}
