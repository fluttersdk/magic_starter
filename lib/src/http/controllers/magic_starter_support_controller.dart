import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../models/magic_starter_support_conversation.dart';
import '../../support/support_page_context.dart';

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

/// One thread as the controller holds it, keyed by its id.
class _SupportThread {
  /// Bumped by every read of this thread; only the newest one publishes, so a
  /// slow answer cannot replace a newer one for the same id.
  int read = 0;

  MagicStarterSupportReadStatus status = MagicStarterSupportReadStatus.idle;

  MagicStarterSupportConversation? conversation;
}

/// Backs the support desk screens: the opener's conversation list, the threads
/// read so far, and the writes that touch a thread.
///
/// ## Threads and surfaces
///
/// Threads are held per id, so two surfaces (the `/support/:id` page and a chat
/// panel) can each show a different thread without overwriting the other. The
/// page's thread is the one [loadConversation] last pointed at; [conversation]
/// and [threadStatus] describe it. A write locks per surface: a reply on the
/// page and a new ticket in the chat run side by side, a second tap on the
/// same surface is refused.
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

  /// Suggestions kept, though the backend may send up to five.
  static const int _maxSuggestions = 3;

  /// The backend's cap on `search`; a longer body is searched by its start.
  static const int _maxSearchLength = 200;

  /// Bumped by [resetForSession]; a read that started under an older value
  /// belongs to the previous session and publishes nothing.
  int _sessionGeneration = 0;

  /// The surface a write locks when its caller names none.
  static const String _pageSurface = 'page';

  /// Bumped by every [loadConversations]; a page read that started under an
  /// older value belongs to a list that has since been replaced and appends
  /// nothing, so a slow page 2 cannot land on a freshly reloaded page 1.
  int _listRead = 0;

  /// Bumped by every [suggestArticles] and [forgetArticleSuggestions]; only the
  /// newest lookup publishes, so a slow answer for text the customer has since
  /// changed cannot replace the newer suggestions.
  int _suggestionRead = 0;

  /// The surfaces with a write in flight.
  final Set<String> _submitting = <String>{};
  bool _isLoadingMore = false;

  /// The newest page held in [_conversations], and the last page the backend
  /// reported. Both zero until the first page lands.
  int _listPage = 0;
  int _listLastPage = 0;

  MagicStarterSupportReadStatus _listStatus =
      MagicStarterSupportReadStatus.idle;
  List<MagicStarterSupportConversation> _conversations = const [];

  /// Every thread read this session, by id as a string. Never evicted before
  /// [resetForSession]: a thread nobody watches any more costs one entry.
  Map<String, _SupportThread> _threads = <String, _SupportThread>{};

  /// The id of the page's thread, set by [loadConversation]. Kept across
  /// [resetForSession]: it is where the page is, not session data, and a page
  /// still open after a team switch reads its thread again under it.
  String? _activeThreadId;

  List<MagicStarterSupportArticle> _articleSuggestions = const [];

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

  /// How the page's thread read ended; idle before [loadConversation].
  MagicStarterSupportReadStatus get threadStatus =>
      _threads[_activeThreadId]?.status ?? MagicStarterSupportReadStatus.idle;

  /// The page's thread with its messages. Null until it has loaded, and after
  /// a 404; a reread that fails keeps the copy already shown.
  MagicStarterSupportConversation? get conversation =>
      _threads[_activeThreadId]?.conversation;

  /// The thread [id] as last read, or null while it has not loaded.
  MagicStarterSupportConversation? threadFor(Object id) =>
      _threads[id.toString()]?.conversation;

  /// How the newest read of thread [id] ended; idle before it was read.
  MagicStarterSupportReadStatus threadStatusFor(Object id) =>
      _threads[id.toString()]?.status ?? MagicStarterSupportReadStatus.idle;

  /// The articles suggested for what the customer is writing, at most three.
  /// Empty while nothing is suggested, which includes a failed lookup.
  List<MagicStarterSupportArticle> get articleSuggestions =>
      _articleSuggestions;

  /// Whether the AI still owes the open thread an answer, for the typing
  /// indicator. False when no thread is loaded.
  bool get isAwaitingAi => conversation?.awaitingAi ?? false;

  /// The signed-in customer's display name, for the avatar of their own rows.
  String? get viewerName => Auth.user()?.get<String>('name');

  /// Whether a create, reply or rating from the page is in flight.
  bool get isSubmitting => isSubmittingFor(_pageSurface);

  /// Whether a write from [surface] is in flight.
  bool isSubmittingFor(String surface) => _submitting.contains(surface);

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

  /// Points the page at thread [id] and reads it with its messages.
  ///
  /// While it loads the page shows the copy of [id] already held, if any, and
  /// never the thread it pointed at before: that one's composer would post to
  /// the wrong conversation.
  Future<void> loadConversation(Object id) async {
    _activeThreadId = id.toString();
    await fetchThread(id);
  }

  /// Reads thread [id] with its messages into [threadFor], without moving the
  /// page's thread. Answers what it stored, or null when it stored nothing: a
  /// 404, a failure, a newer read of the same id, or a session change.
  ///
  /// A 404 becomes [MagicStarterSupportReadStatus.notFound] and nothing asks
  /// again: a teammate's conversation answers 404 for the same reason a missing
  /// one does, and a retry would only repeat the refusal. A failure keeps the
  /// copy already held, so a blip does not blank a thread on screen.
  Future<MagicStarterSupportConversation?> fetchThread(Object id) async {
    final generation = _sessionGeneration;
    final key = id.toString();
    final thread = _threads.putIfAbsent(key, _SupportThread.new);
    final read = ++thread.read;
    bool current() => generation == _sessionGeneration && read == thread.read;

    thread.status = MagicStarterSupportReadStatus.loading;
    refreshUI();

    try {
      final response = await Http.get('/support/conversations/$id');
      if (!current()) return null;

      if (response.notFound) {
        _markThreadNotFound(key);
        return null;
      }

      if (!response.successful) {
        thread.status = MagicStarterSupportReadStatus.failed;
        refreshUI();
        return null;
      }

      final conversation = MagicStarterSupportConversation.fromMap(
        _payload(response) as Map<String, dynamic>,
      );
      thread
        ..conversation = conversation
        ..status = MagicStarterSupportReadStatus.loaded;
      refreshUI();

      return conversation;
    } catch (e, stackTrace) {
      Log.error('[MagicStarterSupportController.fetchThread] $e\n$stackTrace');
      if (!current()) return null;
      thread.status = MagicStarterSupportReadStatus.failed;
      refreshUI();

      return null;
    }
  }

  /// Looks up articles for [search] in the app's locale and publishes them as
  /// [articleSuggestions].
  ///
  /// Suggestions are optional, so a refusal (a 404 when the backend has the
  /// feature off included) and a transport failure both leave nothing to show
  /// and say nothing. Only the newest call publishes.
  Future<void> suggestArticles(String search) async {
    final generation = _sessionGeneration;
    final read = ++_suggestionRead;

    try {
      final response = await Http.get(
        '/support/articles',
        query: {
          'search': String.fromCharCodes(search.runes.take(_maxSearchLength)),
          'locale': Lang.current.languageCode,
        },
      );
      if (generation != _sessionGeneration || read != _suggestionRead) return;

      if (response.successful) {
        _articleSuggestions = [
          for (final row in _payload(response) as List<dynamic>)
            MagicStarterSupportArticle.fromMap(row as Map<String, dynamic>),
        ].take(_maxSuggestions).toList();
      } else {
        _articleSuggestions = const [];
        if (!response.notFound) {
          Log.warning(
            '[MagicStarterSupportController.suggestArticles] '
            '${response.statusCode}',
          );
        }
      }
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterSupportController.suggestArticles] $e\n$stackTrace',
      );
      if (generation != _sessionGeneration || read != _suggestionRead) return;
      _articleSuggestions = const [];
    }

    refreshUI();
  }

  /// Drops the suggestions and abandons any lookup still in flight, so what it
  /// finds later is not shown. [notify] false is for a screen's `onInit`, which
  /// runs while the screen is being built (see [forgetWriteError]).
  void forgetArticleSuggestions({bool notify = true}) {
    _suggestionRead++;
    if (_articleSuggestions.isEmpty) return;

    _articleSuggestions = const [];
    if (notify) refreshUI();
  }

  /// Opens a conversation and answers it, or null when the backend refused
  /// (field errors are in [getError], anything else in [writeError]).
  ///
  /// [topic] is one of [topics]. [subject] is optional: left out, the backend
  /// derives one from the body. Either is sent only when given.
  ///
  /// [source] names the surface the customer opened it from; the backend
  /// records it, it does not infer it.
  ///
  /// [attachments] go up one multipart part each and [clientContext] is the
  /// client info (`app_version`, `build_number`, `platform`, `os_version`,
  /// `locale`, `timezone`). Without a file the request stays JSON. [body] may
  /// be empty when [attachments] carries something.
  ///
  /// [surface] is the lock the write takes (see [isSubmittingFor]).
  ///
  /// The host's page references for the screen the customer is on are read when
  /// this is called and go along as `page_context`
  /// ([MagicStarterSupportPageContext]).
  Future<MagicStarterSupportConversation?> createConversation({
    required String body,
    required String source,
    String? topic,
    String? subject,
    List<MagicFile> attachments = const <MagicFile>[],
    Map<String, String>? clientContext,
    String surface = _pageSurface,
  }) async {
    final response = await _submit(
      '/support/conversations',
      data: {
        'topic': ?topic,
        'subject': ?subject,
        if (body.isNotEmpty || attachments.isEmpty) 'body': body,
        'source': source,
      },
      action: 'createConversation',
      fallbackKey: 'magic_starter.support.create_error',
      surface: surface,
      attachments: attachments,
      clientContext: clientContext,
      pageContext: MagicStarterSupportPageContext.collect(),
    );
    if (response == null) return null;

    return MagicStarterSupportConversation.fromMap(
      _payload(response) as Map<String, dynamic>,
    );
  }

  /// Posts a reply to [id] and appends it to that thread when it is held.
  /// Answers whether the backend accepted it.
  ///
  /// [attachments] go up one multipart part each, and [body] may then be
  /// empty. Without a file the request stays JSON. [surface] is the lock the
  /// write takes (see [isSubmittingFor]).
  ///
  /// Like [createConversation], it sends the host's page references for the
  /// screen the customer is on.
  Future<bool> sendMessage(
    Object id,
    String body, {
    List<MagicFile> attachments = const <MagicFile>[],
    String surface = _pageSurface,
  }) async {
    final response = await _submit(
      '/support/conversations/$id/messages',
      data: {if (body.isNotEmpty || attachments.isEmpty) 'body': body},
      action: 'sendMessage',
      fallbackKey: 'magic_starter.support.reply_error',
      surface: surface,
      thread: id,
      attachments: attachments,
      pageContext: MagicStarterSupportPageContext.collect(),
    );
    if (response == null) return false;

    final thread = _threads[id.toString()];
    final loaded = thread?.conversation;
    if (thread == null || loaded == null) return true;

    final Object? payload = _payload(response);
    if (payload is Map<String, dynamic>) {
      // A read already in flight predates this reply and would erase it.
      thread.read++;
      thread.conversation = loaded.withMessage(
        MagicStarterSupportMessage.fromMap(payload),
      );
      refreshUI();
    } else {
      // The server took the reply but answered something this client cannot
      // read: read the thread again rather than report a failure the reader
      // would retry, posting the reply twice.
      Log.error(
        '[MagicStarterSupportController.sendMessage] unreadable reply: '
        '$payload',
      );
      await fetchThread(id);
    }

    return true;
  }

  /// Rates the resolved conversation [id] (`up` or `down`) and answers whether
  /// the backend accepted it. The backend answers 422 for a conversation that
  /// is not resolved; that lands in [getError] under `rating`.
  ///
  /// A blank [comment] is left out. Rating again within one resolution
  /// overwrites the earlier rating. [surface] is the lock the write takes (see
  /// [isSubmittingFor]).
  Future<bool> rate(
    Object id,
    String rating, {
    String? comment,
    String surface = _pageSurface,
  }) async {
    final note = comment?.trim();
    final response = await _submit(
      '/support/conversations/$id/rating',
      data: {
        'rating': rating,
        'comment': ?(note == null || note.isEmpty ? null : note),
      },
      action: 'rate',
      fallbackKey: 'magic_starter.support.rating_error',
      surface: surface,
      thread: id,
    );
    if (response == null) return false;

    final thread = _threads[id.toString()];
    final loaded = thread?.conversation;
    if (thread != null && loaded != null) {
      thread.read++;
      thread.conversation = loaded.withRating(
        MagicStarterSupportRating(
          value: rating,
          comment: note == null || note.isEmpty ? null : note,
          ratedAt: DateTime.now().toUtc(),
        ),
      );
      refreshUI();
    }

    return true;
  }

  /// The headers an attachment read needs. An attachment answers only to the
  /// bearer token, so a widget loading one passes these along with the url.
  /// Empty when nobody is signed in.
  Future<Map<String, String>> attachmentHeaders() async {
    final token = await Auth.getToken();

    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  /// Asks for a 60 second signed url to open the PDF [attachmentId] of
  /// [conversationId] in the system viewer, or null when the backend refused.
  Future<String?> attachmentLink(
    Object conversationId,
    Object attachmentId,
  ) async {
    try {
      final response = await Http.post(
        '/support/conversations/$conversationId/attachments/$attachmentId/link',
      );

      if (!response.successful) {
        Log.warning(
          '[MagicStarterSupportController.attachmentLink] '
          '${response.statusCode}',
        );
        return null;
      }

      return (response.data as Map<String, dynamic>)['url'] as String?;
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterSupportController.attachmentLink] $e\n$stackTrace',
      );
      return null;
    }
  }

  /// Tells the backend the customer has read [id]. Quiet by design: a seen
  /// receipt that fails is logged and never shown, only a 404 changes state.
  Future<bool> markSeen(Object id) async {
    try {
      final response = await Http.post('/support/conversations/$id/seen');

      if (response.notFound) {
        // Only a thread already held turns into not-found; a receipt says
        // nothing about any other thread.
        final key = id.toString();
        if (_threads.containsKey(key)) _markThreadNotFound(key);
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
    _threads = <String, _SupportThread>{};
    _articleSuggestions = const [];
    _listStatus = MagicStarterSupportReadStatus.idle;
    _listPage = 0;
    _listLastPage = 0;
    _writeError = null;
    _submitting.clear();
    _isLoadingMore = false;
    clearErrors();
    refreshUI();

    if (hadList) await loadConversations();
  }

  /// Runs one write under the [surface] lock and answers its response, or null
  /// after recording why the backend refused it (or why the client did not
  /// send it). A 404 turns [thread], the conversation the write is about, into
  /// not-found.
  Future<MagicResponse?> _submit(
    String url, {
    required Map<String, dynamic> data,
    required String action,
    required String fallbackKey,
    required String surface,
    Object? thread,
    List<MagicFile> attachments = const <MagicFile>[],
    Map<String, String>? clientContext,
    List<Map<String, String>> pageContext = const <Map<String, String>>[],
  }) async {
    if (!_submitting.add(surface)) return null;
    _writeError = null;
    clearErrors();
    refreshUI();

    try {
      // 1. Stop a pick the backend would refuse before it is uploaded.
      final refusal = await _attachmentRefusal(attachments);
      if (refusal != null) {
        _writeError = refusal;

        return null;
      }

      // 2. Send it: multipart when a file goes along, JSON otherwise.
      final response = await _send(
        url,
        data: data,
        attachments: attachments,
        clientContext: clientContext ?? const <String, String>{},
        pageContext: pageContext,
      );

      if (response.successful) return response;

      // 3. Record why the backend said no.
      if (response.notFound) {
        if (thread != null) _markThreadNotFound(thread.toString());
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
      _submitting.remove(surface);
      refreshUI();
    }
  }

  /// One key per file: magic's Dio driver turns each `files` key into exactly
  /// one multipart part, and the backend reads `attachments[0]`..`[2]`. The
  /// client info is flattened to `client_context[key]` fields for the same
  /// reason, and the page references to `page_context[i][key]`; the JSON path
  /// keeps both nested. The one place either is added to a body, and a body
  /// without references carries no `page_context` key.
  Future<MagicResponse> _send(
    String url, {
    required Map<String, dynamic> data,
    required List<MagicFile> attachments,
    required Map<String, String> clientContext,
    required List<Map<String, String>> pageContext,
  }) {
    final files = <String, dynamic>{
      for (var i = 0; i < attachments.length; i++)
        'attachments[$i]': attachments[i],
    };

    if (files.isEmpty) {
      return Http.post(
        url,
        data: {
          ...data,
          if (clientContext.isNotEmpty) 'client_context': clientContext,
          if (pageContext.isNotEmpty) 'page_context': pageContext,
        },
      );
    }

    return Http.upload(
      url,
      data: {
        ...data,
        for (final field in clientContext.entries)
          'client_context[${field.key}]': field.value,
        for (var i = 0; i < pageContext.length; i++)
          for (final field in pageContext[i].entries)
            'page_context[$i][${field.key}]': field.value,
      },
      files: files,
    );
  }

  /// Why [attachments] must not be sent, or null when they may be.
  Future<String?> _attachmentRefusal(List<MagicFile> attachments) async {
    final maxFiles = MagicStarterConfig.supportAttachmentMaxFiles();
    if (attachments.length > maxFiles) {
      return trans('magic_starter.support.attachment_too_many', {
        'max': maxFiles,
      });
    }

    // `MagicFile.extension` is lower case; a host list may not be.
    final extensions = {
      for (final extension in MagicStarterConfig.supportAttachmentExtensions())
        extension.toLowerCase(),
    };
    final maxBytes = MagicStarterConfig.supportAttachmentMaxBytes();

    for (final file in attachments) {
      if (!extensions.contains(file.extension)) {
        return trans('magic_starter.support.attachment_type_error', {
          'name': file.name,
        });
      }

      final length = await _byteLength(file);
      if (length != null && length > maxBytes) {
        return trans('magic_starter.support.attachment_too_large', {
          'name': file.name,
          'max': maxBytes ~/ (1024 * 1024),
        });
      }
    }

    return null;
  }

  /// The size of [file] in bytes. A picker that could not read it reports null
  /// or 0 (see [MagicFile.size]), and neither is a measurement, so the bytes
  /// are read instead. Null when they cannot be read either; the backend
  /// enforces the limit regardless.
  Future<int?> _byteLength(MagicFile file) async {
    final size = file.size;
    if (size != null && size > 0) return size;

    return (await file.readAsBytes())?.length;
  }

  void _markThreadNotFound(String key) {
    _threads.putIfAbsent(key, _SupportThread.new)
      ..conversation = null
      ..status = MagicStarterSupportReadStatus.notFound;
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
