import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../ui/components/page_container/page_container.dart';
import '../ui/components/page_scaffold/page_scaffold.recipe.dart';

/// Registers notification routes provided by Magic Starter plugin.
///
/// Routes are only registered when `magic_starter.features.notifications`
/// is enabled. When disabled, calling this function is a no-op.
///
/// The two screens themselves belong to `magic_notifications` and resolve
/// through [Notify.view], so an app swaps either of them without touching
/// these routes. What stays here is what a published notifications package
/// cannot know: the paths, the authenticated `layout.app` shell, and the page
/// geometry the screens are mounted in.
void registerMagicStarterNotificationRoutes() {
  if (!MagicStarterConfig.hasNotificationFeatures()) return;

  _mountNotificationViews();

  MagicRoute.group(
    middleware: ['auth'],
    layoutId: 'app',
    layout: (child) => MagicStarter.view.makeLayout('layout.app', child: child),
    routes: () {
      MagicRoute.page(
            MagicStarterConfig.notificationsRoute(),
            () => Notify.view.make('notifications.list'),
          )
          .title('magic_starter.titles.notifications')
          .transition(RouteTransition.none);
      MagicRoute.page(
            MagicStarterConfig.notificationPreferencesRoute(),
            () => Notify.view.make('notifications.preferences'),
          )
          .title('magic_starter.titles.notification_preferences')
          .transition(RouteTransition.none);
    },
  );
}

/// Re-registers the package's two screens with the parts only this package can
/// supply, replacing the defaults `Notify.view` ships.
///
/// `magic_notifications` rebuilds its own surface, scroll and header, but not
/// the page geometry: the width cap and the edge margins come from
/// `MagicStarterManager.pageContainerClassName`, which the host sets once and
/// which a published notifications package has no way to resolve. Left
/// unwrapped, these two pages would spread the full shell width while every
/// neighbouring page stayed capped. The back route is the same kind of seam:
/// the preferences screen takes it as a parameter rather than naming a
/// settings hub it cannot know about.
///
/// A host registration wins whichever side of
/// `registerMagicStarterNotificationRoutes()` it lands on. Registering after it
/// replaces the entry; registering before it is left alone, because these are
/// registered only when nobody has CHOSEN a screen for the key.
///
/// Not "when the key is absent": the key is never absent, because reading
/// `Notify.view` seeds `magic_notifications`' own two defaults into it. That
/// distinction is the whole of `_mountIfAbsent` below.
///
/// Register-if-absent rather than unconditional, matching
/// `MagicStarterManager._registerDefault`, which is how every other default in
/// this package is installed. The two calls sit in different files by design:
/// the installer injects the route mount into `route_service_provider.dart`
/// while the scaffold tells adopters to do their `Notify.view` work in
/// `AppServiceProvider`, so which boot runs first is a property of the host's
/// provider order rather than of anything either file can see. Unconditional,
/// an adopter who followed that guidance lost their screen with no error.
void _mountNotificationViews() {
  _mountIfAbsent(
    'notifications.list',
    () => _inHostPageGeometry(const NotificationsListView()),
  );
  _mountIfAbsent(
    'notifications.preferences',
    () => _inHostPageGeometry(
      NotificationPreferencesView(
        backRoute: MagicStarterConfig.settingsHubRoute(),
      ),
    ),
  );
}

/// Registers [builder] under [key] unless the host has already claimed it.
///
/// `hasOverride`, not `has`. Reading `Notify.view` is what seeds
/// `magic_notifications`' own two screens into the registry, so `has(key)` is
/// true from the first read and gating on it would make this function skip
/// EVERY time: the host page geometry it exists to apply, the `MSPageContainer`
/// and the width cap, would never reach either screen in a real app. Both
/// ordering tests pass against `has` only because their `setUp` calls
/// `Notify.view.clear()`, so they run against an empty registry rather than
/// against the one an app boots with.
///
/// `hasOverride` asks the question that actually has an answer: has anybody
/// CHOSEN a screen here, as opposed to the package having seeded its default.
void _mountIfAbsent(String key, Widget Function() builder) {
  if (Notify.view.hasOverride(key)) return;

  Notify.view.register(key, builder);
}

/// Wraps [view] in the host's shared page geometry.
///
/// The surface fill sits OUTSIDE the container, exactly as [MSPageScaffold]
/// composes it, so the page token paints the whole content viewport rather
/// than only the capped column; the shell's own content background is a grey,
/// so a surface that stopped at the cap would show gutters no other page in the
/// app has.
Widget _inHostPageGeometry(Widget view) {
  return WDiv(
    className: pageScaffoldSurfaceRecipe(),
    child: MSPageContainer(child: view),
  );
}
