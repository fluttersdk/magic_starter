import 'dart:async';

import 'package:flutter/foundation.dart'
    show Listenable, VoidCallback, visibleForTesting;
import 'package:magic/magic.dart';

import '../http/controllers/magic_starter_support_controller.dart';
import '../models/magic_starter_support_conversation.dart';

/// The one owner of the support desk's live refresh, shared by every surface
/// that shows it (the `/support` pages, a chat panel).
///
/// While at least one surface [retain]s it, it runs ONE 30 second poll and ONE
/// listener for `support.conversation.updated` on the private user channel
/// `App.Models.User.{id}`, and each tick, broadcast or reconnect rereads the
/// list and every watched thread once ([refresh]), then tells the retained
/// surfaces ([addListener]). The poll runs whatever the socket says: a
/// connected socket is not a subscribed one.
///
/// Why one owner: two surfaces each running their own would double the poll
/// and the seen receipt, and `BroadcastListeners.channel` replaces the alias's
/// `onReconnect` in place, so only the last mounted reader would refetch after
/// a socket drop. It subscribes through [BroadcastListeners], never
/// `Echo.private(...).listen(...)`: the user channel is shared with the
/// notification bell, and `listen` replaces a same-event handler.
///
/// Not a controller, so it owns its [Timer] directly; reads go through
/// [MagicStarterSupportController.instance], so no view has to be mounted.
class MagicStarterSupportSync implements Listenable, SessionScoped {
  MagicStarterSupportSync._() {
    SessionScope.register(this);
  }

  static final MagicStarterSupportSync instance = MagicStarterSupportSync._();

  /// How often the desk rereads, socket or not.
  static const Duration pollInterval = Duration(seconds: 30);

  static const String _alias = 'magic_starter_support';
  static const String _event = 'support.conversation.updated';

  int _retains = 0;
  Timer? _pollTimer;
  BroadcastListenerToken? _broadcastToken;

  /// How many surfaces watch each thread, by id as a string.
  final Map<String, int> _watched = <String, int>{};

  final List<VoidCallback> _listeners = <VoidCallback>[];

  /// The run requested but not started yet; every [refresh] call until it
  /// starts shares it.
  Completer<void>? _queued;
  bool _running = false;

  /// Bumped by [resetForSession]; a receipt sent under an older value records
  /// nothing.
  int _generation = 0;

  final Set<String> _seenInFlight = <String>{};

  /// The unread state each thread was last marked seen in, by id.
  final Map<String, String> _seenStates = <String, String>{};

  /// Starts the poll and, with a broadcast driver configured, the listener, on
  /// the first retain; later retains only count.
  void retain() {
    if (_retains++ > 0) return;

    _pollTimer = Timer.periodic(pollInterval, (_) => _tick());
    if (!_broadcastingEnabled()) return;

    // Reverb has no replay: whatever was published while the socket was down is
    // gone, and only a read recovers it.
    BroadcastListeners.channel(_alias, _userChannel, onReconnect: _tick);
    _broadcastToken = BroadcastListeners.add(_alias, _event, (_) => _tick());

    unawaited(
      BroadcastListeners.sync().catchError((Object error) {
        Log.error('[MagicStarterSupportSync] sync failed: $error');
      }),
    );
  }

  /// Undoes one [retain]; the last one stops the poll and the listener.
  void release() {
    if (_retains == 0) return;
    if (--_retains > 0) return;

    _stop();
  }

  /// Adds thread [id] to what every [refresh] rereads, until as many
  /// [unwatchThread] calls.
  void watchThread(Object id) {
    _watched.update(id.toString(), (count) => count + 1, ifAbsent: () => 1);
  }

  void unwatchThread(Object id) {
    final key = id.toString();
    final count = _watched[key];
    if (count == null) return;

    if (count > 1) {
      _watched[key] = count - 1;
    } else {
      _watched.remove(key);
    }
  }

  /// Rereads the list (every page held) and each watched thread.
  ///
  /// Calls made before a run starts share it, so the surfaces a tick notifies
  /// cause one read between them. Calls made while a run is in flight are
  /// coalesced into ONE follow-up run, since the event behind them may have
  /// landed after the running read was answered.
  Future<void> refresh() {
    final queued = _queued;
    if (queued != null) return queued.future;

    final next = _queued = Completer<void>();
    if (!_running) scheduleMicrotask(_drain);

    return next.future;
  }

  /// Tells the backend the customer has read thread [id], once per unread
  /// state: nothing is sent while a receipt for it is in flight, while the
  /// thread as held is not unread, or when this unread state was already
  /// marked. A reply arriving later is a new state and is marked again.
  ///
  /// After an accepted receipt the list is reread so its unread dot goes.
  /// Answers whether a receipt was accepted; a refused one is tried again on
  /// the next call.
  Future<bool> markSeenOnce(Object id) async {
    final key = id.toString();
    final controller = MagicStarterSupportController.instance;
    final thread = controller.threadFor(id);
    if (thread == null || !thread.hasUnread) return false;

    final state = _unreadState(thread);
    if (_seenStates[key] == state || !_seenInFlight.add(key)) return false;

    final generation = _generation;
    final bool seen;
    try {
      seen = await controller.markSeen(id);
    } finally {
      if (generation == _generation) _seenInFlight.remove(key);
    }
    if (!seen || generation != _generation) return false;

    _seenStates[key] = state;
    await controller.loadConversations();

    return true;
  }

  /// Registers [listener] to run after every tick, broadcast and reconnect,
  /// for a surface to do its own share of a refresh.
  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Forgets which unread states were marked seen; they belong to the previous
  /// session.
  ///
  /// The poll, the listener and the watched threads stay: they belong to the
  /// surfaces still on screen (a team switch keeps the page open), and each
  /// surface's own release stops them. The rows themselves are dropped by the
  /// controller's own reset.
  @override
  Future<void> resetForSession() async {
    _generation++;
    _seenInFlight.clear();
    _seenStates.clear();
  }

  /// Stops everything and forgets every surface: statics outlive a test's
  /// `Magic.flush()`.
  @visibleForTesting
  static void resetForTesting() {
    final sync = instance;
    sync._stop();
    sync._retains = 0;
    sync._watched.clear();
    sync._listeners.clear();
    sync._queued = null;
    sync._running = false;
    unawaited(sync.resetForSession());
  }

  void _stop() {
    _pollTimer?.cancel();
    _pollTimer = null;

    final BroadcastListenerToken? token = _broadcastToken;
    if (token != null) BroadcastListeners.remove(token);
    _broadcastToken = null;
  }

  void _tick() {
    if (_retains == 0) return;

    unawaited(refresh());
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  /// Runs the queued run, then the one follow-up queued behind it, if any.
  Future<void> _drain() async {
    _running = true;
    try {
      while (true) {
        final done = _queued;
        if (done == null) break;
        _queued = null;

        final run = _reread();
        done.complete(run);
        await run;
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _reread() async {
    final controller = MagicStarterSupportController.instance;

    await Future.wait<void>([
      controller.loadConversations(),
      for (final id in _watched.keys) controller.fetchThread(id),
    ]);
  }

  /// What tells one unread state of [thread] from the next: a new message
  /// moves both.
  String _unreadState(MagicStarterSupportConversation thread) =>
      '${thread.messages.length}:${thread.lastActivityAt?.toIso8601String()}';

  /// The null driver accepts a subscription and delivers nothing, so it counts
  /// as no driver and is never subscribed to.
  bool _broadcastingEnabled() {
    final String? driver = Config.get<String>('broadcasting.default');

    return driver != null && driver.isNotEmpty && driver != 'null';
  }

  /// The signed-in user's private channel, or null while no identity resolved.
  String? _userChannel() {
    final String? id = Auth.id()?.toString();

    return (id == null || id.isEmpty) ? null : 'App.Models.User.$id';
  }
}
