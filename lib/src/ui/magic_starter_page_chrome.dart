import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Decides, for the page being built under [context], whether the host draws
/// its title and back control.
///
/// [context] sits inside the page, so the predicate can read `MediaQuery`
/// (`MediaQuery.sizeOf(context).width < 768`) and is asked again when it
/// changes.
typedef MagicStarterPageChromeOwnership = bool Function(BuildContext context);

/// What a mounted page reports to a host that draws its chrome: the title,
/// subtitle and back control the page no longer draws itself.
@immutable
class MagicStarterPageChromeEntry {
  /// The page title.
  final String title;

  /// The line under the title, when the page has one.
  final String? subtitle;

  /// The accessible name of the back control: the parent it returns to.
  final String? backLabel;

  /// The route back goes to when there is nothing to pop. The page draws a
  /// back control only when both this and [backLabel] are set, and a host
  /// should follow the same rule.
  final String? backFallback;

  /// Creates a [MagicStarterPageChromeEntry].
  const MagicStarterPageChromeEntry({
    required this.title,
    this.subtitle,
    this.backLabel,
    this.backFallback,
  });

  @override
  bool operator ==(Object other) {
    return other is MagicStarterPageChromeEntry &&
        other.title == title &&
        other.subtitle == subtitle &&
        other.backLabel == backLabel &&
        other.backFallback == backFallback;
  }

  @override
  int get hashCode => Object.hash(title, subtitle, backLabel, backFallback);

  @override
  String toString() {
    return 'MagicStarterPageChromeEntry(title: $title, subtitle: $subtitle, '
        'backLabel: $backLabel, backFallback: $backFallback)';
  }
}

/// The page chrome a host draws in its own bar on the widths it claims.
///
/// Reached as `MagicStarter.pageChrome`. A host claims the chrome with
/// `MagicStarter.useHostPageChrome(predicate)`; wherever [hostOwns] answers
/// true, `MSPageHeader` (and so every `MSPageScaffold`) reports its title,
/// subtitle and back control here instead of drawing them, and keeps only its
/// actions. The host listens and draws [current].
///
/// Entries are keyed by an owner object, one per mounted header. [current] is
/// the entry of the owner whose FIRST report is the most recent: an owner
/// keeps its place when it updates its entry, so the older of two pages
/// briefly mounted together under an instant route swap neither takes over by
/// rebuilding nor clears the newer page's entry by withdrawing.
///
/// Listeners are notified after the frame in which [current] changed, never
/// synchronously: headers report from their lifecycle methods while the tree
/// builds, where a listener's `setState` would throw. A change undone within
/// the same frame notifies nobody.
class MagicStarterPageChrome extends ChangeNotifier {
  /// Whether the host owns the chrome under a given context; null (the
  /// default) means it never does and every page draws its own.
  MagicStarterPageChromeOwnership? ownsWhen;

  final Map<Object, MagicStarterPageChromeEntry> _entries =
      <Object, MagicStarterPageChromeEntry>{};

  /// The [current] value listeners were last told about.
  MagicStarterPageChromeEntry? _notified;

  bool _notificationScheduled = false;

  /// Whether the host draws the title and back control of the page under
  /// [context]. False while no predicate is registered.
  bool hostOwns(BuildContext context) => ownsWhen?.call(context) ?? false;

  /// The entry the host should draw, or null when no mounted page reports one.
  MagicStarterPageChromeEntry? get current =>
      _entries.isEmpty ? null : _entries.values.last;

  /// Records [entry] for [owner], replacing its previous entry in place.
  ///
  /// A first report from [owner] makes its entry [current]; a later one
  /// updates the entry without moving the owner ahead of a newer one.
  void report(Object owner, MagicStarterPageChromeEntry entry) {
    _entries[owner] = entry;
    _scheduleNotification();
  }

  /// Forgets the entry of [owner]; a no-op for an owner that never reported.
  void withdraw(Object owner) {
    if (_entries.remove(owner) == null) return;
    _scheduleNotification();
  }

  /// Forgets the predicate and every entry, as `MagicStarterManager.reset`
  /// does for the rest of the starter's state.
  void reset() {
    ownsWhen = null;
    _entries.clear();
    _scheduleNotification();
  }

  /// Notifies once after the current frame if [current] then differs from
  /// what listeners last heard.
  ///
  /// `addPostFrameCallback` does not ask for a frame, and a report from a
  /// gesture handler arrives on an idle app, so the frame is requested too.
  void _scheduleNotification() {
    if (_notificationScheduled || current == _notified) return;

    _notificationScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _notificationScheduled = false;
      final MagicStarterPageChromeEntry? latest = current;
      if (latest == _notified) return;

      _notified = latest;
      notifyListeners();
    }, debugLabel: 'MagicStarterPageChrome.notify');
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}
