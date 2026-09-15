import 'dart:async';

import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../components/select/select.recipe.dart';

/// Searchable timezone select widget for Magic Starter.
///
/// Fetches available timezones from the `GET /timezones` API endpoint
/// and renders a searchable [WFormSelect] dropdown. Supports async
/// search with debounced API calls.
///
/// ### Example Usage
///
/// ```dart
/// MagicStarterTimezoneSelect(
///   value: currentTimezone,
///   label: trans('attributes.timezone'),
///   onChanged: (tz) => setState(() => currentTimezone = tz),
/// )
/// ```
class MagicStarterTimezoneSelect extends StatefulWidget {
  /// Currently selected timezone identifier (e.g. `'Europe/Istanbul'`).
  final String? value;

  /// Called when the user selects a timezone.
  final Function(String?) onChanged;

  /// Optional label displayed above the select.
  final String? label;

  /// Optional placeholder text when no value is selected.
  final String? placeholder;

  /// Optional className override for the label.
  final String? labelClassName;

  /// Optional className override for the select input.
  final String? className;

  /// Optional className override for the dropdown menu.
  final String? menuClassName;

  const MagicStarterTimezoneSelect({
    super.key,
    this.value,
    required this.onChanged,
    this.label,
    this.placeholder,
    this.labelClassName,
    this.className,
    this.menuClassName,
  });

  @override
  State<MagicStarterTimezoneSelect> createState() =>
      _MagicStarterTimezoneSelectState();
}

/// One page of timezone options, plus whether the server holds another.
typedef _TimezonePage = ({List<SelectOption<String>> options, bool hasMore});

class _MagicStarterTimezoneSelectState
    extends State<MagicStarterTimezoneSelect> {
  /// Rows per request. Small enough that the first page arrives quickly and
  /// large enough that a reader scrolling a dropdown is not asking for another
  /// round trip every few rows.
  static const int _perPage = 20;

  List<SelectOption<String>> _allOptions = [];
  bool _isInitializing = true;
  Timer? _debounceTimer;
  Completer<List<SelectOption<String>>>? _searchCompleter;

  /// The query the visible page belongs to, so a scroll asks for the next page
  /// OF THAT SEARCH rather than of the unfiltered list.
  String _query = '';

  /// The last page fetched for [_query]. A new search puts it back to one.
  int _page = 1;

  /// Whether the server said there is another page after [_page].
  ///
  /// `WSelect` reads this to decide whether a scroll to the bottom should call
  /// `onLoadMore` at all, so it has to be state rather than a local: the value
  /// arrives with a response and the widget has already been built.
  bool _hasMore = false;

  /// Whether the UNFILTERED first page had another page after it.
  ///
  /// Held apart from [_hasMore], which tracks whatever query is running. A
  /// reopen throws that query away, so a search that ended on its last page
  /// would otherwise leave the restored full list reporting no more pages and
  /// the reader could scroll it end to end and never reach page two again.
  bool _baseHasMore = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Load default timezones and ensure the current value is included.
  Future<void> _initialize() async {
    // 1. Fetch the first page of the unfiltered list.
    final first = await _fetchTimezones('');
    final defaultOptions = [...first.options];

    // 2. If a value is pre-selected, ensure it exists in the options list.
    if (widget.value != null && widget.value!.isNotEmpty) {
      final selectedExists = defaultOptions.any(
        (opt) => opt.value == widget.value,
      );
      if (!selectedExists) {
        final selectedOption = await _fetchTimezones(widget.value!);
        if (selectedOption.options.isNotEmpty) {
          defaultOptions.insert(0, selectedOption.options.first);
        }
      }
    }

    if (mounted) {
      setState(() {
        _allOptions = defaultOptions;
        _query = '';
        _page = 1;
        _hasMore = first.hasMore;
        _baseHasMore = first.hasMore;
        _isInitializing = false;
      });
    }
  }

  /// Put the cursor back to the start, because the menu reset its own list.
  ///
  /// `WSelect` clears its search and restores `options` every time the menu
  /// OPENS, which this side cannot see from any other signal. Without this the
  /// cursor survives that reset and the next scroll to the bottom asks for the
  /// page AFTER the one the reader can no longer see: open, scroll once to pull
  /// page two, close, reopen, and page two's twenty identifiers were
  /// unreachable without searching for them, which is the symptom pagination
  /// was added to remove.
  void _resetCursorOnOpen() {
    if (!mounted) return;

    // Before the guard below, and that order is the point: a debounce pending
    // from a query the reader typed and then closed the menu on has written
    // none of the three fields the guard reads, so the guard returns and the
    // timer fires afterwards onto a menu that is showing the unfiltered list.
    // It would then set `_query` to a word nobody can see and `_page` to one,
    // and the next scroll would ask for page two OF THAT query. Completing the
    // completer is what `_handleSearch` already does when a keystroke
    // supersedes an earlier one: `WSelect` awaits this future behind its own
    // in-flight flag, so dropping the timer without answering it leaves the
    // menu waiting on a response that will never come.
    _debounceTimer?.cancel();
    if (_searchCompleter != null && !_searchCompleter!.isCompleted) {
      _searchCompleter!.complete(_allOptions);
    }

    // `_hasMore == _baseHasMore` is the third term and it is load-bearing.
    // `_fetchTimezones` answers `hasMore: false` on any failure, so typing a
    // character and deleting it fires `onSearch('')`, and if THAT request fails
    // the state is `_query == ''`, `_page == 1`, `_hasMore == false` while the
    // unfiltered list still has pages. Guarding on the first two alone returns
    // here forever after, and the reader scrolls twenty rows to the bottom for
    // the life of the widget with nothing loading. The load-more failure path
    // recovers on its own because `_page` is already past one by then; the
    // search path is the one that needs this.
    if (_query.isEmpty && _page == 1 && _hasMore == _baseHasMore) return;

    setState(() {
      _query = '';
      _page = 1;
      _hasMore = _baseHasMore;
    });
  }

  /// Fetch the page after the one on screen and hand it to [WSelect].
  ///
  /// The rows are returned rather than pushed into [_allOptions], because
  /// `WSelect` owns the visible list once a search has filtered it and
  /// replacing `options` from here would throw that filtered list away. Only
  /// the cursor and the has-more flag live on this side.
  Future<List<SelectOption<String>>> _loadMoreTimezones() async {
    // Captured before the await and re-checked after it. Nothing cancels a
    // request when the menu closes, so a page three in flight across a close
    // and reopen would otherwise land on a cursor the reopen had already put
    // back to one, set it to two, and make the next scroll skip page two: the
    // same defect the reopen reset exists to remove, one race later.
    final String query = _query;
    final int page = _page + 1;

    final next = await _fetchTimezones(query, page: page);

    if (!mounted) return next.options;
    if (query != _query || page != _page + 1) return const [];

    setState(() {
      _page = page;
      _hasMore = next.hasMore;
    });

    return next.options;
  }

  /// Fetch one page of timezones, optionally filtered by [query].
  ///
  /// Returns the options AND whether the server holds another page, because
  /// both come from the same response and the caller needs both: there are
  /// well over 400 IANA identifiers and the endpoint pages them, so a list that
  /// stops at the first page silently hides most of them behind a search box
  /// the reader has no reason to think is mandatory.
  Future<_TimezonePage> _fetchTimezones(String query, {int page = 1}) async {
    try {
      final response = await Http.get(
        '/timezones?search=$query&per_page=$_perPage&page=$page',
      );
      if (response.successful) {
        final data = response.data['data'];
        if (data == null || data is! List) {
          return const (options: <SelectOption<String>>[], hasMore: false);
        }

        final List<SelectOption<String>> options = data
            .where(
              (tz) =>
                  tz != null &&
                  tz is Map &&
                  tz['identifier'] != null &&
                  tz['label'] != null,
            )
            .map((tz) {
              return SelectOption<String>(
                value: tz['identifier'] as String,
                label: tz['label'] as String,
              );
            })
            .toList();

        return (options: options, hasMore: _hasNextPage(response, page));
      }
    } catch (e) {
      Log.error('Failed to fetch timezones: $e');
    }
    return const (options: <SelectOption<String>>[], hasMore: false);
  }

  /// Whether the response says a page after [page] exists.
  ///
  /// Reads `meta.last_page`, which Laravel's `LengthAwarePaginator` sends. A
  /// response carrying no meta is treated as the end rather than as unknown:
  /// guessing "there is more" here would have the select ask for a page that
  /// does not exist every time the reader reaches the bottom.
  bool _hasNextPage(MagicResponse response, int page) {
    final meta = response.data['meta'];
    if (meta is! Map) return false;

    final lastPage = meta['last_page'];

    return lastPage is int && page < lastPage;
  }

  /// Handle search requests with debounce to prevent excessive API calls.
  ///
  /// Cancels any pending debounced search and waits [_debounceDuration]
  /// before firing the API request. Returns the current options immediately
  /// via a [Completer] that resolves after the debounce window.
  Future<List<SelectOption<String>>> _handleSearch(String query) {
    // 1. Cancel any previous pending debounce timer.
    _debounceTimer?.cancel();
    if (_searchCompleter != null && !_searchCompleter!.isCompleted) {
      _searchCompleter!.complete(_allOptions);
    }

    // 2. Create a new completer for this search request.
    final completer = Completer<List<SelectOption<String>>>();
    _searchCompleter = completer;

    // 3. Start a debounce timer — only fire API after 300ms of inactivity.
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final page = await _fetchTimezones(query);
        final results = [...page.options];

        // A search restarts the cursor: the next scroll to the bottom has to
        // ask for page two OF THIS QUERY, not of whatever was loaded before.
        if (mounted) {
          setState(() {
            _query = query;
            _page = 1;
            _hasMore = page.hasMore;
          });
        }

        // Always include the currently selected value in results.
        if (widget.value != null && widget.value!.isNotEmpty) {
          final selectedExists = results.any(
            (opt) => opt.value == widget.value,
          );
          if (!selectedExists) {
            final selectedInAll = _allOptions
                .where((opt) => opt.value == widget.value)
                .toList();
            if (selectedInAll.isNotEmpty) {
              results.insert(0, selectedInAll.first);
            }
          }
        }

        if (!completer.isCompleted) {
          completer.complete(results);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.complete(_allOptions);
        }
      }
    });

    return completer.future;
  }

  /// Handle value changes, updating the local cache when needed.
  void _handleChange(String? value) {
    widget.onChanged(value);

    // Ensure _allOptions contains the newly selected value.
    if (value != null && value.isNotEmpty) {
      final exists = _allOptions.any((opt) => opt.value == value);
      if (!exists) {
        _fetchTimezones(value).then((page) {
          if (mounted && page.options.isNotEmpty) {
            setState(() {
              _allOptions = [page.options.first, ..._allOptions];
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the select slot recipe for semantic-token defaults.
    final slots = selectRecipe();

    if (_isInitializing) {
      return WDiv(
        children: [
          if (widget.label != null)
            WText(
              widget.label!,
              className:
                  widget.labelClassName ??
                  'text-sm font-medium text-fg-muted mb-1',
            ),
          WDiv(
            className: widget.className ?? slots['trigger'],
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      );
    }

    return WFormSelect<String>(
      value: widget.value,
      options: _allOptions,
      onChange: _handleChange,
      searchable: true,
      onSearch: _handleSearch,
      onLoadMore: _loadMoreTimezones,
      hasMore: _hasMore,
      onOpen: _resetCursorOnOpen,
      label: widget.label,
      labelClassName:
          widget.labelClassName ?? 'text-sm font-medium text-fg-muted mb-1',
      searchPlaceholder: widget.placeholder ?? trans('profile.timezone_search'),
      placeholder: widget.placeholder ?? trans('profile.timezone_select'),
      className: widget.className ?? slots['trigger'],
      menuClassName: widget.menuClassName ?? slots['popup'],
    );
  }
}
