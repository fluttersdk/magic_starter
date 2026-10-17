/// The `layoutId` values this package's route groups register under.
///
/// Magic merges route groups into ONE go_router `ShellRoute` only when they
/// carry the same `layoutId`; a group with another id, or none, becomes a
/// second shell and every crossing between the two re-animates the whole
/// layout. A host's own authenticated group must therefore use [app] so that
/// its pages share the shell with the starter's profile, team and notification
/// pages.
abstract final class MagicStarterLayoutIds {
  /// The authenticated shell: `layout.app` around every signed-in page.
  static const String app = 'app';
}
