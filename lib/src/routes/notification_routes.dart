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
/// A registration a host makes AFTER `registerMagicStarterNotificationRoutes()`
/// replaces either entry, which is how an app swaps a whole screen.
void _mountNotificationViews() {
  Notify.view.register(
    'notifications.list',
    () => _inHostPageGeometry(const NotificationsListView()),
  );
  Notify.view.register(
    'notifications.preferences',
    () => _inHostPageGeometry(
      NotificationPreferencesView(
        backRoute: MagicStarterConfig.settingsHubRoute(),
      ),
    ),
  );
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
