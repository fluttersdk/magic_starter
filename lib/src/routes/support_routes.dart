import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../http/controllers/magic_starter_feedback_controller.dart';
import '../http/controllers/magic_starter_support_controller.dart';
import '../support/screen_capture.dart';
import '../ui/widgets/magic_starter_hide_bottom_nav.dart';
import 'layout_ids.dart';

/// Full path of the "Send feedback" page (`support_feedback`).
///
/// Lives under the support prefix, so arriving on it counts as entering
/// support for [MagicStarterScreenCapture].
String magicStarterSupportFeedbackRoute() =>
    '${MagicStarterConfig.supportRoute()}/feedback';

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
/// `/support/new` and, behind `support_feedback`, `/support/feedback` are
/// registered before `/support/:id` so the literal segment wins over the
/// parameter. The list replaces and the other two are
/// `.stacked()`, the hub-and-spoke shape the settings routes use: a host
/// commonly gives the list a nav destination, and the create and thread pages
/// are places a reader drills into and needs the back gesture out of.
///
/// The thread is a chat screen, so its page is wrapped in
/// [MagicStarterHideBottomNav]: the phone's bottom navigation slides away under
/// the composer with the push and comes back with the pop, and stays on the
/// list and the create page. Every support page shares the one app shell, so
/// moving between them never rebuilds the layout.
///
/// The host calls this from its route provider, as it does the other
/// `registerMagicStarter*Routes()`: the profile dropdown shows its Support item
/// whenever the feature is on, and without this call that item leads nowhere.
/// The view keys (`support.index`, `support.create`, `support.thread`, and
/// `support.feedback` behind its flag) have default builders;
/// `MagicStarter.view.register(...)` replaces one.
///
/// Behind `support_diagnostics` this also adds
/// [MagicStarterScreenCapture.observer] to the router, which is why it has to
/// run before the router is built, as every route registration does.
void registerMagicStarterSupportRoutes() {
  if (!MagicStarterConfig.hasSupportFeatures()) return;

  final observer = MagicStarterScreenCapture.observer;
  if (MagicStarterConfig.hasSupportDiagnosticsFeatures() &&
      !MagicRouter.instance.observers.contains(observer)) {
    MagicRouter.instance.addObserver(observer);
  }

  MagicRoute.group(
    middleware: ['auth'],
    layoutId: MagicStarterLayoutIds.app,
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

      if (MagicStarterConfig.hasSupportFeedbackFeatures()) {
        MagicRoute.page(magicStarterSupportFeedbackRoute(), () {
          Magic.findOrPut(MagicStarterFeedbackController.new);
          return MagicStarter.view.make('support.feedback');
        }).title('magic_starter.titles.support_feedback').stacked();
      }

      MagicRoute.page(
        MagicStarterConfig.supportThreadRoute(),
        () => MagicStarterHideBottomNav(child: _supportView('support.thread')),
      ).title('magic_starter.titles.support_thread').stacked();
    },
  );
}
