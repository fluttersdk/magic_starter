import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Test Suite
// ---------------------------------------------------------------------------
//
// Every page this package registers must carry a `.title()`.
//
// A route without one is not an error anywhere: `TitleManager` falls back to
// the application title by design, so the app boots, the page renders, and the
// only symptom is a browser tab reading the bare app name. Measured on a
// consumer (uptizm) on 2026-08-29: its own 21 routes all resolved their titles
// in both languages while all 20 of this package's read `Uptizm`, login and
// register included. Nothing failed; there was simply no test asking.
//
// The second half matters as much as the first. A title is a translation KEY,
// and `trans()` returns the key itself when the catalogue has no entry, so a
// route titled with a key nobody added renders `magic_starter.titles.login` in
// the tab: worse than the bare name it replaced. The keys therefore have to
// exist in the install stub, and that is asserted here rather than trusted.

/// Every [RouteDefinition] this package registers, flat and inside layouts.
///
/// Routes registered under `MagicRoute.group(layout: ...)` land in a
/// [LayoutDefinition] rather than the flat list, so both are walked (the same
/// traversal `profile_routes_test.dart` uses to resolve a single path).
List<RouteDefinition> allRegisteredRoutes() {
  return [
    ...MagicRouter.instance.routes,
    for (final layout in MagicRouter.instance.mergedLayouts) ...layout.children,
  ];
}

/// Turn on every gate that guards a route, so the sweep sees all 20.
///
/// A gate left off hides its route from this test, which would make the sweep
/// quietly narrower than it claims to be.
void enableEveryRoutedFeature() {
  Config.set('magic_starter.features.registration', true);
  Config.set('magic_starter.features.two_factor', true);
  Config.set('magic_starter.features.phone_otp', true);
  Config.set('magic_starter.features.notifications', true);
  Config.set('magic_starter.features.extended_profile', true);
  Config.set('magic_starter.features.timezones', true);
  Config.set('magic_starter.features.newsletter', true);
  Config.set('magic_starter.features.sessions', true);
  Config.set('magic_starter.features.teams', true);
}

/// The `magic_starter.titles` block shipped by the install stub.
Map<String, dynamic> stubTitles() {
  final raw = File('assets/stubs/install/en.stub').readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final starter = decoded['magic_starter'] as Map<String, dynamic>?;

  return (starter?['titles'] as Map<String, dynamic>?) ?? const {};
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();

    enableEveryRoutedFeature();

    // The manager reads feature flags at construction time, so it is created
    // after the flags above are set.
    Magic.singleton('magic_starter', () => MagicStarterManager());

    registerMagicStarterAuthRoutes();
    registerMagicStarterProfileRoutes();
    registerMagicStarterNotificationRoutes();
    registerMagicStarterTeamRoutes();
  });

  tearDown(() {
    MagicRouter.reset();
    MagicApp.reset();
    Magic.flush();
  });

  group('route titles', () {
    test('every registered route declares one', () {
      final routes = allRegisteredRoutes();

      // A coverage FLOOR, not a spec: adding a route must not need an edit
      // here, but a stale feature gate silently shrinking the swept set must
      // fail rather than pass on the routes that happen to be left.
      expect(
        routes.length,
        greaterThanOrEqualTo(20),
        reason:
            'The sweep saw ${routes.length} routes where this package registers '
            'at least 20. A feature gate in enableEveryRoutedFeature() has gone '
            'stale, so the routes behind it were never checked.',
      );

      final untitled = routes
          .where((route) => route.routeTitle == null)
          .map((route) => route.fullPath)
          .toList();

      expect(
        untitled,
        isEmpty,
        reason:
            'These routes carry no title, so a browser tab on each shows the '
            'bare app name: $untitled',
      );
    });

    test('every title key is shipped by the install stub', () {
      final titles = stubTitles();

      final missing = allRegisteredRoutes()
          .map((route) => route.routeTitle)
          .whereType<String>()
          .where((key) => key.startsWith('magic_starter.titles.'))
          .map((key) => key.substring('magic_starter.titles.'.length))
          .where((key) => !titles.containsKey(key))
          .toSet()
          .toList();

      expect(
        missing,
        isEmpty,
        reason:
            'A route titles itself with a key the install stub does not carry, '
            'so a fresh install renders the raw key in the tab: $missing',
      );
    });

    test('the stub ships no title key no route uses', () {
      final used = allRegisteredRoutes()
          .map((route) => route.routeTitle)
          .whereType<String>()
          .where((key) => key.startsWith('magic_starter.titles.'))
          .map((key) => key.substring('magic_starter.titles.'.length))
          .toSet();

      final orphans = stubTitles().keys
          .where((key) => !used.contains(key))
          .toList();

      expect(
        orphans,
        isEmpty,
        reason:
            'The stub ships title keys no route references. A removed route '
            'leaves its key behind, and the next reader cannot tell which of '
            'these are dead: $orphans',
      );
    });
  });
}
