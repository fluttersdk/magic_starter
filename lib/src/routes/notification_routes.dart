import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../ui/components/confirm_dialog/confirm_dialog.dart';
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
/// registered only when nobody has CHOSEN a screen for the key, which is not
/// the same as the key being absent: reading `Notify.view` seeds
/// `magic_notifications`' own two defaults into it, so the key never is.
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
  _mountUnlessOverridden(
    'notifications.list',
    // `onDelete` is what makes the row's delete affordance render at all
    // (`NotificationsListView` draws it only when the callback is non-null), and
    // this registration is the one a magic_starter app actually gets: it
    // replaces the package's own default in order to apply the host page
    // geometry, so a null here is the whole ecosystem's answer. Left unpassed,
    // `Notify.deleteNotification` and the backend route behind it had no
    // surface anywhere: a working endpoint nothing could call.
    () => _inHostPageGeometry(
      NotificationsListView(onDelete: _confirmThenDelete),
    ),
  );
  _mountUnlessOverridden(
    'notifications.preferences',
    () => _inHostPageGeometry(
      NotificationPreferencesView(
        backRoute: MagicStarterConfig.settingsHubRoute(),
      ),
    ),
  );
}

/// Asks before deleting, then deletes.
///
/// A delete is destructive, irreversible and one tap away in a list of rows a
/// thumb scrolls past, which is the combination a confirmation exists for. The
/// package's list cannot ask on its own: it takes `onDelete` as a plain
/// callback, and `magic_notifications` removed its own dialog widget in 0.1.0
/// precisely so a published package stops imposing one adopter's tone and
/// layout on everybody. Asking here is that decision honoured, not worked
/// around, and it puts the confirmation in the same package as every other
/// destructive confirmation a starter app shows.
///
/// [MSConfirmDialog] rather than `Magic.confirm`, and the context comes from
/// the router's navigator key. Neither the view registry nor `onDelete` hands
/// this function a [BuildContext], but one is reachable without either:
/// `MagicRouter.instance.navigatorKey.currentContext` is exactly where
/// `MagicFeedback` gets its own. That matters because the two dialogs are not
/// interchangeable here. `MSConfirmDialog` reads
/// `MagicStarter.manager.modalTheme`, so it follows the host's modal styling
/// and its dark mode; `Magic.confirm` styles from `view.confirm.*` with
/// hardcoded light-mode fallbacks (`bg-white`, `bg-red-500`) and no host in
/// this package registers a confirm builder to replace them. Using the magic
/// facade would have shipped the one destructive dialog in the app that
/// ignores the theme every other one obeys.
///
/// A null context refuses rather than deleting. It means no navigator is
/// mounted, so nobody could have been asked, and a destructive action whose
/// question could not be put has not been answered yes.
///
/// The delete itself is left unguarded on purpose, and what that means depends
/// on the resolved dependency. On `magic_notifications` 0.1.0 it cannot throw:
/// `deleteNotification` logs a failed request, rolls the row back and completes
/// normally, so a failure is silent and nothing here can change that.
/// fluttersdk/magic_notifications#21 makes it rethrow and has the list row
/// catch it and say so. Either way this call site is correct by not catching:
/// today there is nothing to catch, and once there is, swallowing it here would
/// put the silence back one layer up.
Future<void> _confirmThenDelete(String id) async {
  final BuildContext? context =
      MagicRouter.instance.navigatorKey.currentContext;
  if (context == null) return;

  final bool confirmed = await MSConfirmDialog.show(
    context,
    title: trans('notifications.delete_confirm_title'),
    description: trans('notifications.delete_confirm_message'),
    confirmLabel: trans('common.delete'),
    cancelLabel: trans('common.cancel'),
    variant: ConfirmDialogVariant.danger,
  );

  if (!confirmed) return;

  await Notify.deleteNotification(id);
}

/// Registers [builder] under [key] unless somebody has already chosen a screen
/// for it.
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
void _mountUnlessOverridden(String key, Widget Function() builder) {
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
