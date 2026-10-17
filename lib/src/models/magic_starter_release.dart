import 'package:flutter/foundation.dart';

import '../configuration/magic_starter_config.dart';

/// The kind of change a [MagicStarterReleaseItem] announces.
///
/// The wire value is `new`, `improved` or `fixed`. Dart cannot name an enum
/// case `new`, so that one is [newFeature]; [key] returns the wire spelling.
enum MagicStarterReleaseItemType {
  newFeature('new'),
  improved('improved'),
  fixed('fixed');

  const MagicStarterReleaseItemType(this.key);

  /// The value the backend sends in an item's `type`.
  final String key;

  /// Maps a wire value to its case, or `null` for an unknown or missing one.
  ///
  /// A `null` is how a client older than the backend skips a type it has not
  /// learned yet instead of failing the whole feed.
  static MagicStarterReleaseItemType? tryParse(String? value) {
    for (final MagicStarterReleaseItemType type in values) {
      if (type.key == value) {
        return type;
      }
    }

    return null;
  }
}

/// One line of a release's changelog.
///
/// Wire shape: `{"type": "new", "text": {"en": "...", "tr": "..."}}`. The
/// backend fills every locale it supports, falling back to its default
/// locale's copy, so a value can repeat across languages but is rarely empty.
@immutable
class MagicStarterReleaseItem {
  /// What kind of change this line announces.
  final MagicStarterReleaseItemType type;

  /// The copy per language code. Entries whose value is not a string are not
  /// kept.
  final Map<String, String> text;

  const MagicStarterReleaseItem({required this.type, required this.text});

  /// The copy to show a reader whose language is [languageCode].
  ///
  /// Picks, in order: the exact code's non-empty value,
  /// [MagicStarterConfig.defaultLocale]'s, the first non-empty value, and
  /// `''` when the map holds none. Never throws.
  String textFor(String languageCode) {
    // 1. The reader's own language.
    final String? exact = text[languageCode];
    if (exact != null && exact.isNotEmpty) {
      return exact;
    }

    // 2. The app's default language.
    final String? fallback = text[MagicStarterConfig.defaultLocale()];
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    // 3. Anything the backend did send.
    for (final String value in text.values) {
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }
}

/// One released version of the app, as listed by the backend's `releases`
/// endpoint.
///
/// Wire shape: `{"version": "1.1.0", "published_at": "2026-10-20T09:00:00.000000Z",
/// "ios_build": 15, "android_build": 15, "items": [...]}`. `published_at`,
/// `ios_build` and `android_build` may be null: a release that has not shipped
/// to a store carries no build for it.
@immutable
class MagicStarterRelease {
  /// The human version label, such as `1.1.0`.
  final String version;

  /// When the release was published; `null` when absent or unparseable.
  final DateTime? publishedAt;

  /// The iOS build number this release shipped as, or `null`.
  final int? iosBuild;

  /// The Android build number this release shipped as, or `null`.
  final int? androidBuild;

  /// The changelog lines, in the backend's order.
  final List<MagicStarterReleaseItem> items;

  const MagicStarterRelease({
    required this.version,
    required this.publishedAt,
    required this.iosBuild,
    required this.androidBuild,
    required this.items,
  });

  /// Reads one entry of the feed's `data` list.
  ///
  /// An item with an unknown or missing `type` is skipped; a `text` value that
  /// is not a string is ignored.
  factory MagicStarterRelease.fromJson(Map<String, dynamic> json) {
    final Object? version = json['version'];
    final Object? publishedAt = json['published_at'];
    final Object? iosBuild = json['ios_build'];
    final Object? androidBuild = json['android_build'];
    final Object? rawItems = json['items'];

    return MagicStarterRelease(
      version: version is String ? version : '',
      publishedAt: publishedAt is String
          ? DateTime.tryParse(publishedAt)
          : null,
      iosBuild: iosBuild is int ? iosBuild : null,
      androidBuild: androidBuild is int ? androidBuild : null,
      items: <MagicStarterReleaseItem>[
        if (rawItems is List<dynamic>)
          for (final Object? rawItem in rawItems)
            if (rawItem is Map<String, dynamic>) ..._parseItem(rawItem),
      ],
    );
  }

  /// Yields the item, or nothing when its `type` is not one this client knows.
  static Iterable<MagicStarterReleaseItem> _parseItem(
    Map<String, dynamic> json,
  ) sync* {
    final Object? rawType = json['type'];
    final MagicStarterReleaseItemType? type =
        MagicStarterReleaseItemType.tryParse(
          rawType is String ? rawType : null,
        );
    if (type == null) {
      return;
    }

    final Object? rawText = json['text'];

    yield MagicStarterReleaseItem(
      type: type,
      text: <String, String>{
        if (rawText is Map<dynamic, dynamic>)
          for (final MapEntry<dynamic, dynamic> entry in rawText.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
      },
    );
  }
}

/// The body of the backend's `GET releases`: the releases plus the newest
/// store builds.
///
/// Wire shape: `{"data": [...], "meta": {"latest_build": {"ios": 15,
/// "android": 15}}}`. Releases arrive newest first. Either latest build may be
/// null, and `meta` may be missing altogether.
@immutable
class MagicStarterReleaseFeed {
  /// The releases, newest first.
  final List<MagicStarterRelease> releases;

  /// The newest iOS build the backend knows of, or `null`.
  final int? latestIosBuild;

  /// The newest Android build the backend knows of, or `null`.
  final int? latestAndroidBuild;

  const MagicStarterReleaseFeed({
    required this.releases,
    required this.latestIosBuild,
    required this.latestAndroidBuild,
  });

  /// Reads the whole response body; a missing `data` or `meta` reads as empty.
  factory MagicStarterReleaseFeed.fromJson(Map<String, dynamic> json) {
    final Object? data = json['data'];
    final Object? meta = json['meta'];
    final Object? latest = meta is Map<String, dynamic>
        ? meta['latest_build']
        : null;
    final Object? ios = latest is Map<String, dynamic> ? latest['ios'] : null;
    final Object? android = latest is Map<String, dynamic>
        ? latest['android']
        : null;

    return MagicStarterReleaseFeed(
      releases: <MagicStarterRelease>[
        if (data is List<dynamic>)
          for (final Object? row in data)
            if (row is Map<String, dynamic>) MagicStarterRelease.fromJson(row),
      ],
      latestIosBuild: ios is int ? ios : null,
      latestAndroidBuild: android is int ? android : null,
    );
  }
}
