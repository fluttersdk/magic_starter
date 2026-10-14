import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:in_app_review/in_app_review.dart';
import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';

/// Asks for a native store review at moments the host chooses, and opens the
/// store listing for an explicit "Rate us".
///
/// ## The prompt is the host's milestone, never a tap
///
/// [maybeRequest] belongs after something went well (a first check passed, a
/// tenth incident resolved), never behind a button: the platforms decide
/// whether a sheet appears at all and say nothing back, so a button wired to it
/// would sometimes do nothing. A button opens the listing instead
/// ([openStoreListing]), which is not quota-limited.
///
/// ## When it stays quiet
///
/// No prompt on the web, for a guest, for an account younger than
/// [MagicStarterConfig.storeReviewMinAccountDays], within
/// [MagicStarterConfig.storeReviewIntervalDays] of the last prompt on this
/// device, or in a run where the feedback card was shown: one ask per session
/// is already plenty. Nothing is asked before it, and nothing depends on a
/// feedback score.
class MagicStarterStoreReview {
  MagicStarterStoreReview._();

  /// The [Vault] key the last prompt's UTC instant is stored under.
  static const String lastPromptKey = 'magic_starter.store_review.prompted_at';

  /// Stands in for `kIsWeb` in a test, which always runs on a host VM.
  @visibleForTesting
  static bool? debugIsWebOverride;

  static bool _feedbackCardShown = false;
  static bool _requesting = false;

  static bool get _isWeb => debugIsWebOverride ?? kIsWeb;

  /// Whether the feedback card was shown in this run of the app.
  static bool get feedbackCardShown => _feedbackCardShown;

  /// Whether a "Rate us" action belongs on screen: the feature is on and this
  /// device has a store listing the plugin can open.
  ///
  /// The web has no store. Android finds the listing from the package name;
  /// iOS and macOS need [MagicStarterConfig.storeReviewAppStoreId], and the
  /// plugin throws without it. Other desktops are not offered the action.
  static bool get canOpenStoreListing {
    if (!MagicStarterConfig.hasStoreReviewFeatures() || _isWeb) return false;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS || TargetPlatform.macOS =>
        MagicStarterConfig.storeReviewAppStoreId() != null,
      _ => false,
    };
  }

  /// Records that the feedback card was put in front of the customer, so no
  /// review prompt follows it in the same run.
  static void noteFeedbackCardShown() => _feedbackCardShown = true;

  /// Asks the platform for its review sheet when every rule above allows it.
  ///
  /// Answers whether the platform was asked; whether a sheet actually appeared
  /// is never known. The prompt instant is stored BEFORE asking, so a crash in
  /// the native sheet cannot turn into a prompt on every launch.
  static Future<bool> maybeRequest() async {
    if (_requesting) return false;
    _requesting = true;

    try {
      // 1. The cheap, synchronous rules first.
      if (!_mayAsk()) return false;

      // 2. The device's own memory of the last prompt.
      if (!await _intervalElapsed()) return false;

      // 3. The platform has the final say on whether a sheet can show.
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return false;

      await Vault.put(lastPromptKey, DateTime.now().toUtc().toIso8601String());
      await review.requestReview();

      return true;
    } finally {
      _requesting = false;
    }
  }

  /// Opens this app's store page, for an explicit "Rate us" tap.
  ///
  /// iOS needs [MagicStarterConfig.storeReviewAppStoreId]; Android resolves
  /// the listing from the package name.
  static Future<void> openStoreListing() {
    return InAppReview.instance.openStoreListing(
      appStoreId: MagicStarterConfig.storeReviewAppStoreId(),
    );
  }

  /// Forgets the session flag and the web override between tests.
  @visibleForTesting
  static void resetForTesting() {
    _feedbackCardShown = false;
    _requesting = false;
    debugIsWebOverride = null;
  }

  static bool _mayAsk() {
    if (!MagicStarterConfig.hasStoreReviewFeatures()) return false;
    if (_isWeb || _feedbackCardShown) return false;

    final user = Auth.user();
    if (user == null || user.get<bool>('is_guest') == true) return false;

    // An account whose age is unknown is treated as too young to ask.
    final createdAt = DateTime.tryParse(user.get<String>('created_at') ?? '');
    if (createdAt == null) return false;

    final minimumAge = Duration(
      days: MagicStarterConfig.storeReviewMinAccountDays(),
    );

    return DateTime.now().difference(createdAt) >= minimumAge;
  }

  /// Whether the configured interval has passed since the last prompt.
  ///
  /// An unreadable store answers no: a broken read must never turn into a
  /// prompt on every milestone.
  static Future<bool> _intervalElapsed() async {
    final String? stored;
    try {
      stored = await Vault.get(lastPromptKey);
    } catch (error) {
      Log.warning('[MagicStarterStoreReview] vault read failed: $error');

      return false;
    }

    final lastPrompt = DateTime.tryParse(stored ?? '');
    if (lastPrompt == null) return true;

    final interval = Duration(
      days: MagicStarterConfig.storeReviewIntervalDays(),
    );

    return DateTime.now().difference(lastPrompt) >= interval;
  }
}
