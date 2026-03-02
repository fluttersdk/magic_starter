import 'dart:async';

import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

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

class _MagicStarterTimezoneSelectState
    extends State<MagicStarterTimezoneSelect> {
  List<SelectOption<String>> _allOptions = [];
  bool _isInitializing = true;
  Timer? _debounceTimer;
  Completer<List<SelectOption<String>>>? _searchCompleter;

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
    // 1. Fetch default (popular) timezones.
    final defaultOptions = await _fetchTimezones('');

    // 2. If a value is pre-selected, ensure it exists in the options list.
    if (widget.value != null && widget.value!.isNotEmpty) {
      final selectedExists = defaultOptions.any(
        (opt) => opt.value == widget.value,
      );
      if (!selectedExists) {
        final selectedOption = await _fetchTimezones(widget.value!);
        if (selectedOption.isNotEmpty) {
          defaultOptions.insert(0, selectedOption.first);
        }
      }
    }

    if (mounted) {
      setState(() {
        _allOptions = defaultOptions;
        _isInitializing = false;
      });
    }
  }

  /// Fetch timezones from the API with an optional search query.
  Future<List<SelectOption<String>>> _fetchTimezones(String query) async {
    try {
      final response = await Http.get('/timezones?search=$query&per_page=20');
      if (response.successful) {
        final data = response.data['data'] as List;
        return data.map((tz) {
          return SelectOption<String>(
            value: tz['identifier'] as String,
            label: tz['label'] as String,
          );
        }).toList();
      }
    } catch (e) {
      Log.error('Failed to fetch timezones: $e');
    }
    return [];
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
        final results = await _fetchTimezones(query);

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
        _fetchTimezones(value).then((options) {
          if (mounted && options.isNotEmpty) {
            setState(() {
              _allOptions = [options.first, ..._allOptions];
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return WDiv(
        children: [
          if (widget.label != null)
            WText(
              widget.label!,
              className: widget.labelClassName ??
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            ),
          WDiv(
            className:
                'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 flex items-center justify-center',
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
      label: widget.label,
      labelClassName: widget.labelClassName ??
          'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
      searchPlaceholder: widget.placeholder ?? trans('profile.timezone_search'),
      placeholder: widget.placeholder ?? trans('profile.timezone_select'),
      className: widget.className ??
          'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary',
      menuClassName: widget.menuClassName ??
          'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700',
    );
  }
}
