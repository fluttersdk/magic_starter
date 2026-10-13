import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../models/magic_starter_support_conversation.dart';

/// How a support read ended, for the screen to branch on.
enum MagicStarterSupportReadStatus {
  /// Nothing has been requested since construction or the last session reset.
  idle,

  loading,

  loaded,

  /// The backend answered 404. For a thread this also covers a teammate's
  /// conversation, which the backend deliberately does not tell apart from a
  /// missing one, so it is never retried and never explained further.
  notFound,

  failed,
}

/// Backs the support desk screens: the opener's conversation list, one thread,
/// and the three writes that touch a thread.
///
/// ## Why this controller does NOT use `MagicStateMixin`
///
/// The list and the thread are two independent reads on one singleton. The
/// mixin holds a single state slot that `setLoading()` nulls, so opening a
/// thread would blank the list behind it. Each read publishes its own field and
/// status instead and notifies through [refreshUI], the shape
/// `MagicStarterBillingController` documents.
///
/// ## Tenant boundary
///
/// The client never sends a team or user id: the backend scopes every endpoint
/// to the authenticated opener. The rows cached here belong to one session, so
/// the controller is [SessionScoped] and a sign-in drops them before anything
/// else renders.
class MagicStarterSupportController extends MagicController
    with ValidatesRequests
    implements SessionScoped {
  /// Singleton accessor. Use this instead of constructing directly.
  static MagicStarterSupportController get instance =>
      Magic.findOrPut(MagicStarterSupportController.new);

  /// Rows requested per page of the conversation list.
  static const int _perPage = 20;

  /// Bumped by [resetForSession]; a read that started under an older value
  /// belongs to the previous session and publishes nothing.
  int _sessionGeneration = 0;

  /// Bumped by every [loadConversation]; only the newest thread read
  /// publishes, so a slow answer for a thread the reader already left cannot
  /// replace the one on screen, whose composer posts to the newer thread.
  int _threadRead = 0;

  /// Bumped by every [loadConversations]; a page read that started under an
  /// older value belongs to a list that has since been replaced and appends
  /// nothing, so a slow page 2 cannot land on a freshly reloaded page 1.
  int _listRead = 0;

  bool _isSubmitting = false;
  bool _isLoadingMore = false;

  /// The newest page held in [_conversations], and the last page the backend
  /// reported. Both zero until the first page lands.
  int _listPage = 0;
  int _listLastPage = 0;

  MagicStarterSupportReadStatus _listStatus =
      MagicStarterSupportReadStatus.idle;
  List<MagicStarterSupportConversation> _conversations = const [];

  MagicStarterSupportReadStatus _threadStatus =
      MagicStarterSupportReadStatus.idle;
  MagicStarterSupportConversation? _conversation;

  String? _writeError;

  MagicStarterSupportReadStatus get listStatus => _listStatus;

  /// The signed-in user's own conversations, newest activity first as the
  /// backend orders them. Every page loaded so far, concatenated.
  List<MagicStarterSupportConversation> get conversations => _conversations;

  /// Whether the backend has a page beyond the last one loaded.
  ///
  /// Independent of [listStatus]: a refresh rereads with the rows on screen,
  /// and the pages behind them still exist while it runs.
  bool get hasMoreConversations => _listPage < _listLastPage;

  /// Whether [loadMoreConversations] has a page in flight.
  bool get isLoadingMoreConversations => _isLoadingMore;

  /// The topics a new conversation can be filed under, in display order
  /// (`magic_starter.support.topics`).
  List<String> get topics => MagicStarterConfig.supportTopics();

  MagicStarterSupportReadStatus get threadStatus => _threadStatus;

  /// The thread last read, with its messages. Null before the first read and
  /// whenever [threadStatus] is not loaded.
  MagicStarterSupportConversation? get conversation => _conversation;

  /// Whether the AI still owes the open thread an answer, for the typing
  /// indicator. False when no thread is loaded.
  bool get isAwaitingAi => _conversation?.awaitingAi ?? false;

  /// The signed-in customer's display name, for the avatar of their own rows.
  String? get viewerName => Auth.user()?.get<String>('name');

  /// Whether a create, reply or seen write is in flight.
  bool get isSubmitting => _isSubmitting;

  /// The message of the last write the backend refused for a reason other than
  /// validation (field errors live in [getError]). Cleared by the next write.
  String? get writeError => _writeError;

  /// Reads the signed-in user's conversations from page 1, and arms
  /// [loadMoreConversations] for the pages behind them.
  ///
  /// The first read holds page 1. A read made while further pages are already
  /// held (the 30 second poll, a broadcast, the thread's own refresh) rereads
  /// every page held so far, one request each, so a refresh never collapses what
  /// "Load more" showed. The pages are read one by one at the normal page size
  /// rather than as one oversized page: the backend caps `per_page`, and that
  /// cap is not this client's to know. A page the backend no longer has (a
  /// conversation was removed) ends the read early.
  ///
  /// A failure keeps the rows already loaded, so a blip does not blank the
  /// list; [resetForSession] is the path that clears.
  Future<void> loadConversations() async {
    final generation = _sessionGeneration;
    final read = ++_listRead;
    final pagesHeld = _listPage < 1 ? 1 : _listPage;
    _isLoadingMore = false;
    _listStatus = MagicStarterSupportReadStatus.loading;
    refreshUI();

    try {
      final rows = <MagicStarterSupportConversation>[];
      final held = <String>{};
      var lastPage = 1;
      var page = 1;

      do {
        final response = await _getPage(page);
        if (generation != _sessionGeneration || read != _listRead) return;

        if (!response.successful) {
          _listStatus = MagicStarterSupportReadStatus.failed;
          refreshUI();
          return;
        }

        // New activity moves a conversation up the order between two page
        // reads, so the same row can arrive twice.
        for (final row in _rows(response)) {
          if (held.add(row.id.toString())) rows.add(row);
        }
        lastPage = _lastPage(response, fallback: page);
        page++;
      } while (page <= pagesHeld && page <= lastPage);

      _conversations = rows;
      _listPage = page - 1;
      _listLastPage = lastPage;
      _listStatus = MagicStarterSupportReadStatus.loaded;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterSupportController.loadConversations] $e\n$stackTrace',
      );
      if (generation != _sessionGeneration || read != _listRead) return;
      _listStatus = MagicStarterSupportReadStatus.failed;
    }

    refreshUI();
  }

  /// Appends the page after the last one loaded. Does nothing while a page or
  /// a full reread is already in flight, or when [hasMoreConversations] is
  /// false.
  ///
  /// A failed page keeps every row and leaves [hasMoreConversations] true, so
  /// the next call retries the same page. A row already held is skipped: new
  /// activity moves conversations up the order between two page reads, and the
  /// same row would otherwise appear twice.
  Future<void> loadMoreConversations() async {
    if (!hasMoreConversations ||
        _isLoadingMore ||
        _listStatus == MagicStarterSupportReadStatus.loading) {
      return;
    }

    final generation = _sessionGeneration;
    final read = _listRead;
    final page = _listPage + 1;
    _isLoadingMore = true;
    refreshUI();

    try {
      final response = await _getPage(page);
      if (generation != _sessionGeneration || read != _listRead) return;

      if (response.successful) {
        final held = {for (final row in _conversations) row.id.toString()};
        _conversations = [
          ..._conversations,
          for (final row in _rows(response))
            if (!held.contains(row.id.toString())) row,
        ];
        _listPage = page;
        _listLastPage = _lastPage(response, fallback: page);
      } else {
        Log.warning(
          '[MagicStarterSupportController.loadMoreConversations] '
          '${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterSupportController.loadMoreConversations] '
        '$e\n$stackTrace',
      );
      if (generation != _sessionGeneration || read != _listRead) return;
    }

    _isLoadingMore = false;
    refreshUI();
  }

  /// Reads one thread with its messages.
  ///
  /// A 404 becomes [MagicStarterSupportReadStatus.notFound] and nothing asks
  /// again: a teammate's conversation answers 404 for the same reason a missing
  /// one does, and a retry would only repeat the refusal.
  Future<void> loadConversation(Object id) async {
    final generation = _sessionGeneration;
    final read = ++_threadRead;

    // A different thread must not show the previous one while it loads; the
    // same thread keeps its messages so a refresh does not blink.
    if (_conversation?.id.toString() != id.toString()) _conversation = null;
    _threadStatus = MagicStarterSupportReadStatus.loading;
    refreshUI();

    try {
      final response = await Http.get('/support/conversations/$id');
      if (generation != _sessionGeneration || read != _threadRead) return;

      if (response.notFound) {
        _markThreadNotFound();
        return;
      }

      if (!response.successful) {
        _threadStatus = MagicStarterSupportReadStatus.failed;
        refreshUI();
        return;
      }

      _conversation = MagicStarterSupportConversation.fromMap(
        _payload(response) as Map<String, dynamic>,
      );
      _threadStatus = MagicStarterSupportReadStatus.loaded;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterSupportController.loadConversation] $e\n$stackTrace',
      );
      if (generation != _sessionGeneration || read != _threadRead) return;
      _threadStatus = MagicStarterSupportReadStatus.failed;
    }

    refreshUI();
  }

  /// Opens a conversation and answers it, or null when the backend refused
  /// (field errors are in [getError], anything else in [writeError]).
  ///
  /// [topic] is one of [topics]. [subject] is optional: left out, the backend
  /// derives one from the body. Either is sent only when given.
  ///
  /// [source] names the surface the customer opened it from; the backend
  /// records it, it does not infer it.
  Future<MagicStarterSupportConversation?> createConversation({
    required String body,
    required String source,
    String? topic,
    String? subject,
  }) async {
    final response = await _submit(
      '/support/conversations',
      data: {
        'topic': ?topic,
        'subject': ?subject,
        'body': body,
        'source': source,
      },
      action: 'createConversation',
      fallbackKey: 'magic_starter.support.create_error',
    );
    if (response == null) return null;

    return MagicStarterSupportConversation.fromMap(
      _payload(response) as Map<String, dynamic>,
    );
  }

  /// Posts a reply to [id] and appends it to the loaded thread. Answers whether
  /// the backend accepted it.
  Future<bool> sendMessage(Object id, String body) async {
    final response = await _submit(
      '/support/conversations/$id/messages',
      data: {'body': body},
      action: 'sendMessage',
      fallbackKey: 'magic_starter.support.reply_error',
    );
    if (response == null) return false;

    final loaded = _conversation;
    if (loaded != null && loaded.id.toString() == id.toString()) {
      _conversation = loaded.withMessage(
        MagicStarterSupportMessage.fromMap(
          _payload(response) as Map<String, dynamic>,
        ),
      );
      refreshUI();
    }

    return true;
  }

  /// Tells the backend the customer has read [id]. Quiet by design: a seen
  /// receipt that fails is logged and never shown, only a 404 changes state.
  Future<bool> markSeen(Object id) async {
    try {
      final response = await Http.post('/support/conversations/$id/seen');

      if (response.notFound) {
        // Only the thread on screen turns into not-found; a late receipt for
        // a thread the reader already left says nothing about this one.
        if (_conversation?.id.toString() == id.toString()) {
          _markThreadNotFound();
        }
        return false;
      }

      if (!response.successful) {
        Log.warning(
          '[MagicStarterSupportController.markSeen] ${response.statusCode}',
        );
        return false;
      }

      return true;
    } catch (e, stackTrace) {
      Log.error('[MagicStarterSupportController.markSeen] $e\n$stackTrace');
      return false;
    }
  }

  /// Forgets the last write refusal without notifying, for a screen's
  /// `onInit`: magic's view clears field errors there itself, but
  /// [writeError] is this controller's own and would otherwise greet the next
  /// screen. Silent because it runs while the screen is being built.
  void forgetWriteError() => _writeError = null;

  /// Drops every row of the previous session, then refetches the list when one
  /// had been read (see [SessionScoped]).
  ///
  /// Clears BEFORE refetching, so a failed refetch leaves the screens empty
  /// rather than populated with the previous user's conversations.
  @override
  Future<void> resetForSession() async {
    _sessionGeneration++;

    final hadList = _listStatus != MagicStarterSupportReadStatus.idle;

    _conversations = const [];
    _conversation = null;
    _listStatus = MagicStarterSupportReadStatus.idle;
    _threadStatus = MagicStarterSupportReadStatus.idle;
    _listPage = 0;
    _listLastPage = 0;
    _writeError = null;
    _isSubmitting = false;
    _isLoadingMore = false;
    clearErrors();
    refreshUI();

    if (hadList) await loadConversations();
  }

  /// Runs one write and answers its response, or null after recording why the
  /// backend refused it.
  Future<MagicResponse?> _submit(
    String url, {
    required Map<String, dynamic> data,
    required String action,
    required String fallbackKey,
  }) async {
    if (_isSubmitting) return null;
    _isSubmitting = true;
    _writeError = null;
    clearErrors();
    refreshUI();

    try {
      final response = await Http.post(url, data: data);

      if (response.successful) return response;

      if (response.notFound) {
        _markThreadNotFound();
      } else if (response.isValidationError) {
        setErrorsFromResponse(response);
      } else {
        _writeError = response.firstError ?? trans(fallbackKey);
      }

      return null;
    } catch (e, stackTrace) {
      Log.error('[MagicStarterSupportController.$action] $e\n$stackTrace');
      _writeError = trans('errors.unexpected');

      return null;
    } finally {
      _isSubmitting = false;
      refreshUI();
    }
  }

  void _markThreadNotFound() {
    _conversation = null;
    _threadStatus = MagicStarterSupportReadStatus.notFound;
    refreshUI();
  }

  Future<MagicResponse> _getPage(int page) {
    return Http.get(
      '/support/conversations',
      query: {'page': page, 'per_page': _perPage},
    );
  }

  List<MagicStarterSupportConversation> _rows(MagicResponse response) {
    return [
      for (final row in _payload(response) as List<dynamic>)
        MagicStarterSupportConversation.fromMap(row as Map<String, dynamic>),
    ];
  }

  /// The last page the paginator reports, or [fallback] when the answer carries
  /// no `meta`, which reads as "nothing further".
  int _lastPage(MagicResponse response, {required int fallback}) {
    final meta = (response.data as Map<String, dynamic>)['meta'];

    return ((meta as Map<String, dynamic>?)?['last_page'] as num?)?.toInt() ??
        fallback;
  }

  /// The resource under the `data` envelope every endpoint answers with.
  Object? _payload(MagicResponse response) =>
      (response.data as Map<String, dynamic>)['data'];
}
