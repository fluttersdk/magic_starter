import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Default Guest Layout for Magic Starter.
///
/// Simple centered wrapper for authentication pages.
///
/// **Construct this through `MagicStarter.view.makeLayout('layout.guest', child:
/// ...)` rather than directly.** That is where the route-keyed `KeyedSubtree`
/// is applied, and this widget no longer carries its own: a host that reaches
/// past the registry gets the unkeyed shell the keying exists to prevent. See
/// `MagicStarterViewRegistry.makeLayout` for what the key is for.
class MagicStarterGuestLayout extends StatelessWidget {
  final Widget child;

  const MagicStarterGuestLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: wColor(
        context,
        MagicStarter.manager.layoutTheme.contentBackgroundLightColor,
        shade: MagicStarter.manager.layoutTheme.contentBackgroundLightShade,
        darkColorName:
            MagicStarter.manager.layoutTheme.contentBackgroundDarkColor,
        darkShade: MagicStarter.manager.layoutTheme.contentBackgroundDarkShade,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          // Each guest page owns its own implicit scroll controller. Never
          // attach to the ambient PrimaryScrollController: with
          // RouteTransition.none, the outgoing and incoming guest routes are
          // briefly mounted together, and two `primary: true` scroll views
          // contending for the single PrimaryScrollController detach each
          // other mid-layout (the dropChild / "wrong build scope" cascade).
          // The page subtree is keyed by route path, which is what makes a
          // guest -> guest navigation (login -> register -> forgot, under
          // RouteTransition.none) a clean unmount/mount instead of a reparent
          // of the previous page's element tree, which tears down mid-build
          // ("wrong build scope" / dropChild cascade). That key is applied by
          // MagicStarterViewRegistry.makeLayout rather than here, so a host
          // app replacing this layout keeps it; see that method's doc block.
          child: SingleChildScrollView(
            primary: false,
            child: WDiv(className: 'p-4 lg:p-8', child: child),
          ),
        ),
      ),
    );
  }
}
