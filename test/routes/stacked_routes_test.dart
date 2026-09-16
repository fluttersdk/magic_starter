import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Pins which of this package's routes push and which replace.
///
/// `MagicRoute.to()` calls `go()`, which replaces the Navigator's whole page
/// list, so a route that does not opt in leaves the stack one page deep. That
/// is not only a missing iOS edge swipe: Flutter reports `canHandlePop: false`
/// to the platform at that depth, the Android embedder unregisters its own back
/// callback, and the system back button LEAVES THE APP. Every settings
/// sub-page in this package shipped that way.
///
/// The split is hub-and-spoke. A hub, and anything a host is likely to give a
/// nav destination, keeps replacing: a destination that pushes grows the stack
/// every time its tab is tapped. A spoke pushes. An arrival (an emailed
/// invitation link) replaces, because there is nothing behind it.
void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
  });

  /// Turns on every feature that gates a route, so the test sees the whole
  /// surface rather than the default-off subset.
  ///
  /// Each is its own boolean key; there is no list form. Written out rather
  /// than looped, because a key that silently does not exist would leave its
  /// route unregistered and the assertion below would then read a missing
  /// route as an unstacked one.
  void enableEveryFeature() {
    for (final String feature in [
      'teams',
      'notifications',
      'two_factor',
      'sessions',
      'newsletter',
      'extended_profile',
      'timezones',
    ]) {
      Config.set('magic_starter.features.$feature', true);
    }
  }

  Map<String, bool?> stackingByPath() {
    return {
      for (final route in MagicRouter.instance.mergedLayouts.expand(
        (layout) => layout.children,
      ))
        route.path: route.isStacked,
    };
  }

  test('every settings spoke pushes and the hub does not', () {
    enableEveryFeature();
    registerMagicStarterProfileRoutes();

    final Map<String, bool?> stacking = stackingByPath();

    expect(
      stacking[MagicStarterConfig.settingsHubRoute()],
      isNot(true),
      reason: 'the hub is a destination; pushing it grows the stack per tap',
    );

    for (final String spoke in [
      MagicStarterConfig.profileRoute(),
      MagicStarterConfig.settingsAppearanceRoute(),
      MagicStarterConfig.settingsPasswordRoute(),
      MagicStarterConfig.settingsLanguageRoute(),
      MagicStarterConfig.settingsTimezoneRoute(),
      MagicStarterConfig.settingsNewsletterRoute(),
      MagicStarterConfig.settingsTwoFactorRoute(),
      MagicStarterConfig.settingsSessionsRoute(),
    ]) {
      // Presence first: an absent route and an unstacked one both read as
      // null, and a feature key that stopped registering its page would
      // otherwise fail this as a stacking bug.
      expect(
        stacking.containsKey(spoke),
        isTrue,
        reason: '$spoke did not register at all',
      );
      expect(
        stacking[spoke],
        isTrue,
        reason: '$spoke replaces, so there is nothing to pop from it',
      );
    }
  });

  test('team create and settings push, an invitation arrival does not', () {
    enableEveryFeature();
    registerMagicStarterTeamRoutes();

    final Map<String, bool?> stacking = stackingByPath();

    expect(stacking['${MagicStarterConfig.teamsPrefix()}/create'], isTrue);
    expect(stacking['${MagicStarterConfig.teamsPrefix()}/settings'], isTrue);
    expect(
      stacking['/invitations/:token/accept'],
      isNot(true),
      reason: 'an emailed link is an arrival with nothing behind it',
    );
  });

  test('both notification screens push', () {
    enableEveryFeature();
    registerMagicStarterNotificationRoutes();

    final Map<String, bool?> stacking = stackingByPath();

    expect(stacking[MagicStarterConfig.notificationsRoute()], isTrue);
    expect(stacking[MagicStarterConfig.notificationPreferencesRoute()], isTrue);
  });

  test('a stacked route names no transition, so the host decides', () {
    enableEveryFeature();
    registerMagicStarterProfileRoutes();
    registerMagicStarterTeamRoutes();
    registerMagicStarterNotificationRoutes();

    // `declaredTransition` is null when the route said nothing, which is what
    // sends it to `MagicRouter.defaultTransition`. A package that named
    // `RouteTransition.none` here would be opting its screens OUT of a host's
    // app-wide choice, which is how they had no animation and no gesture even
    // in an app that had asked for both.
    final List<String> opinionated = [
      for (final route in MagicRouter.instance.mergedLayouts.expand(
        (layout) => layout.children,
      ))
        if (route.isStacked == true && route.declaredTransition != null)
          route.path,
    ];

    expect(
      opinionated,
      isEmpty,
      reason:
          'these routes pin a transition, so a host setting '
          'MagicRouter.defaultTransition cannot reach them',
    );
  });
}
