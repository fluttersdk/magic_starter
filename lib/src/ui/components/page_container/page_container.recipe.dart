import 'package:magic/magic.dart';

/// Returns the className for the shared page container.
///
/// The base is only the part that is true for every consumer: fill the content
/// region (`w-full`) and centre once the cap is reached (`mx-auto`). The width
/// cap, the horizontal edge margins, and the vertical rhythm all arrive through
/// [hostClassName], because they are the HOST app's decision (see
/// `MagicStarterManager.pageContainerClassName`) and every page in that app has
/// to share one answer. Hard-coding them here is what let the starter's pages
/// and the host's own pages drift into different widths and different top
/// offsets inside the same shell.
///
/// [className] is a per-page override appended LAST, so a page that needs to
/// tune one axis (a shorter bottom pad under a footer bar, say) can do it
/// without restating, or losing, the shared geometry.
///
/// Emission order: base (width + centering) then the host geometry then the
/// caller's override.
String pageContainerRecipe({required String hostClassName, String? className}) {
  final Iterable<String> geometry = <String>[
    hostClassName,
    if (className != null) className,
  ].where((String segment) => segment.isNotEmpty);

  return const WindRecipe(base: 'w-full mx-auto')(
    className: geometry.join(' '),
  );
}
