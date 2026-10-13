import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/magic_starter_support_controller.dart';
import '../ui/widgets/magic_starter_hide_bottom_nav.dart';

/// Resolves a support screen, registering the shared controller first.
///
/// The views resolve their controller with `Magic.find<T>()`, which needs it
/// already in the container, so the put happens here before the view builds.
Widget _supportView(String key) {
  Magic.findOrPut(MagicStarterSupportController.new);
  return MagicStarter.view.make(key);
}

/// Registers the support desk routes provided by Magic Starter plugin.
///
/// Routes are only registered when `magic_starter.features.support` is
/// enabled. When disabled, calling this function is a no-op.
///
/// `/support/new` is registered before `/support/:id` so the literal segment
/// wins over the parameter. The list replaces and the other two are
/// `.stacked()`, the hub-and-spoke shape the settings routes use: a host
/// commonly gives the list a nav destination, and the create and thread pages
/// are places a reader drills into and needs the back gesture out of.
///
/// The thread is a chat screen, so it sits in its own route group
/// (`layoutId: 'app.chat'`) whose layout is wrapped in
/// [MagicStarterHideBottomNav]: the phone's bottom navigation is gone under the
/// composer, and stays on the list and the create page. The group needs its own
/// id because two groups sharing one share one layout element.
///
/// The host calls this from its route provider, as it does the other
/// `registerMagicStarter*Routes()`: the profile dropdown shows its Support item
/// whenever the feature is on, and without this call that item leads nowhere.
/// The three view keys (`support.index`, `support.create`, `support.thread`)
/// have default builders; `MagicStarter.view.register(...)` replaces one.
void registerMagicStarterSupportRoutes() {
  if (!MagicStarterConfig.hasSupportFeatures()) return;

  MagicRoute.group(
    middleware: ['auth'],
    layoutId: 'app',
    layout: (child) => MagicStarter.view.makeLayout('layout.app', child: child),
    routes: () {
      MagicRoute.page(
        MagicStarterConfig.supportRoute(),
        () => _supportView('support.index'),
      ).title('magic_starter.titles.support');

      MagicRoute.page(
        MagicStarterConfig.supportCreateRoute(),
        () => _supportView('support.create'),
      ).title('magic_starter.titles.support_create').stacked();
    },
  );

  MagicRoute.group(
    middleware: ['auth'],
    layoutId: 'app.chat',
    layout: (child) => MagicStarterHideBottomNav(
      child: MagicStarter.view.makeLayout('layout.app', child: child),
    ),
    routes: () {
      MagicRoute.page(
        MagicStarterConfig.supportThreadRoute(),
        () => _supportView('support.thread'),
      ).title('magic_starter.titles.support_thread').stacked();
    },
  );
}
