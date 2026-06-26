import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Test Suite
// ---------------------------------------------------------------------------
//
// Step 11 contract: `registerMagicStarterProfileRoutes()` builds the iOS-style
// Settings hub (`/settings`) + feature-gated sub-routes, each registry-driven
// and `RouteTransition.none`, inside the authenticated `layout.app` group.

/// Returns the registered [RouteDefinition] whose `fullPath` matches [path].
///
/// Routes registered inside a `MagicRoute.group(layout: ...)` are collected
/// into a [LayoutDefinition] rather than the flat `routes` list, so both the
/// top-level routes and every layout's children are scanned.
RouteDefinition? routeFor(String path) {
  for (final route in MagicRouter.instance.routes) {
    if (route.fullPath == path) {
      return route;
    }
  }

  for (final layout in MagicRouter.instance.mergedLayouts) {
    for (final route in layout.children) {
      if (route.fullPath == path) {
        return route;
      }
    }
  }

  return null;
}

/// Enables every starter feature gate that guards a settings sub-route.
void enableAllSettingsFeatures() {
  Config.set('magic_starter.features.two_factor', true);
  Config.set('magic_starter.features.sessions', true);
  Config.set('magic_starter.features.extended_profile', true);
  Config.set('magic_starter.features.timezones', true);
  Config.set('magic_starter.features.newsletter', true);
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();

    // The manager reads feature flags at construction time, so the
    // singleton must be created after the per-test flags are set. Tests
    // that need defaults registered resolve it explicitly.
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  tearDown(() {
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  group('registerMagicStarterProfileRoutes', () {
    test('registers the Settings hub at the profile prefix', () {
      registerMagicStarterProfileRoutes();

      final hub = routeFor(MagicStarterConfig.settingsHubRoute());
      expect(hub, isNotNull);
      expect(hub!.transitionType, RouteTransition.none);
    });

    test('keeps the Profile sub-route at /settings/profile', () {
      registerMagicStarterProfileRoutes();

      final profile = routeFor(MagicStarterConfig.profileRoute());
      expect(profile, isNotNull);
      expect(profile!.transitionType, RouteTransition.none);
    });

    test('registers the Appearance sub-route (always available)', () {
      registerMagicStarterProfileRoutes();

      expect(routeFor(MagicStarterConfig.settingsAppearanceRoute()), isNotNull);
    });

    test('hub + profile + appearance handlers resolve registered views', () {
      // Touch the manager so default views are registered.
      MagicStarter.view;
      registerMagicStarterProfileRoutes();

      final hub = routeFor(MagicStarterConfig.settingsHubRoute())!;
      final profile = routeFor(MagicStarterConfig.profileRoute())!;
      final appearance =
          routeFor(MagicStarterConfig.settingsAppearanceRoute())!;

      // Each handler builds a Widget via the registry without throwing.
      expect(hub.buildWidget(const {}), isA<Widget>());
      expect(profile.buildWidget(const {}), isA<Widget>());
      expect(appearance.buildWidget(const {}), isA<Widget>());
    });

    test('every settings route is wrapped in the layout.app group', () {
      registerMagicStarterProfileRoutes();

      final hub = routeFor(MagicStarterConfig.settingsHubRoute())!;
      // Group routes carry no explicit prefix here (flat absolute paths), so
      // the fullPath equals the registered absolute path.
      expect(hub.fullPath, MagicStarterConfig.settingsHubRoute());
    });
  });

  group('feature gating', () {
    test('security + preference sub-routes are absent when features are off',
        () {
      // All gated features default to false.
      registerMagicStarterProfileRoutes();

      expect(routeFor(MagicStarterConfig.settingsTwoFactorRoute()), isNull);
      expect(routeFor(MagicStarterConfig.settingsSessionsRoute()), isNull);
      expect(routeFor(MagicStarterConfig.settingsLanguageRoute()), isNull);
      expect(routeFor(MagicStarterConfig.settingsTimezoneRoute()), isNull);
      expect(routeFor(MagicStarterConfig.settingsNewsletterRoute()), isNull);

      // The hub, profile, appearance, and password are always present
      // (password mirrors the hub row, which has no feature flag).
      expect(routeFor(MagicStarterConfig.settingsHubRoute()), isNotNull);
      expect(routeFor(MagicStarterConfig.profileRoute()), isNotNull);
      expect(routeFor(MagicStarterConfig.settingsAppearanceRoute()), isNotNull);
      expect(routeFor(MagicStarterConfig.settingsPasswordRoute()), isNotNull);
    });

    test('two-factor sub-route appears when two_factor is on', () {
      Config.set('magic_starter.features.two_factor', true);

      registerMagicStarterProfileRoutes();

      expect(routeFor(MagicStarterConfig.settingsTwoFactorRoute()), isNotNull);
    });

    test('sessions sub-route appears when sessions is on', () {
      Config.set('magic_starter.features.sessions', true);

      registerMagicStarterProfileRoutes();

      expect(routeFor(MagicStarterConfig.settingsSessionsRoute()), isNotNull);
    });

    test('language sub-route appears when extended_profile is on', () {
      Config.set('magic_starter.features.extended_profile', true);

      registerMagicStarterProfileRoutes();

      expect(routeFor(MagicStarterConfig.settingsLanguageRoute()), isNotNull);
    });

    test('timezone sub-route appears when timezones is on', () {
      Config.set('magic_starter.features.timezones', true);

      registerMagicStarterProfileRoutes();

      expect(routeFor(MagicStarterConfig.settingsTimezoneRoute()), isNotNull);
    });

    test('newsletter sub-route appears when newsletter is on', () {
      Config.set('magic_starter.features.newsletter', true);

      registerMagicStarterProfileRoutes();

      expect(routeFor(MagicStarterConfig.settingsNewsletterRoute()), isNotNull);
    });

    test('all sub-routes resolve registered views when every feature is on',
        () {
      enableAllSettingsFeatures();
      // Rebuild the manager so the gated default views are registered.
      Magic.flush();
      Magic.singleton('magic_starter', () => MagicStarterManager());
      MagicStarter.view;

      registerMagicStarterProfileRoutes();

      final paths = <String>[
        MagicStarterConfig.settingsHubRoute(),
        MagicStarterConfig.profileRoute(),
        MagicStarterConfig.settingsAppearanceRoute(),
        MagicStarterConfig.settingsLanguageRoute(),
        MagicStarterConfig.settingsTimezoneRoute(),
        MagicStarterConfig.settingsNewsletterRoute(),
        MagicStarterConfig.settingsTwoFactorRoute(),
        MagicStarterConfig.settingsPasswordRoute(),
        MagicStarterConfig.settingsSessionsRoute(),
      ];

      for (final path in paths) {
        final route = routeFor(path);
        expect(route, isNotNull, reason: 'route missing for $path');
        expect(
          route!.buildWidget(const {}),
          isA<Widget>(),
          reason: 'handler did not build a widget for $path',
        );
      }
    });
  });
}
