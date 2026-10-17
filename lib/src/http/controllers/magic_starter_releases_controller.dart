import 'package:magic/magic.dart';

import '../../models/magic_starter_release.dart';

/// Controller for the release changelog.
///
/// Reads the backend's guest-readable `GET releases`. [fetchReleases] drives
/// the changelog view's state; [readFeed] is the stateless read the update
/// banner uses.
class MagicStarterReleasesController extends MagicController
    with MagicStateMixin<MagicStarterReleaseFeed> {
  /// Singleton accessor: use this instead of constructing directly.
  static MagicStarterReleasesController get instance =>
      Magic.findOrPut(MagicStarterReleasesController.new);

  bool _isFetching = false;

  /// Reads the release feed once, without touching any controller state.
  ///
  /// Answers `null` when the backend refuses (the feature is off server side,
  /// a 5xx) or the request throws; the cause is logged as a warning. Never
  /// throws, so a background check cannot reach the widget tree.
  static Future<MagicStarterReleaseFeed?> readFeed() async {
    try {
      final response = await Http.get('/releases');
      final Object? payload = response.data;

      if (!response.successful || payload is! Map<String, dynamic>) {
        Log.warning(
          '[MagicStarterReleasesController.readFeed] '
          'status ${response.statusCode}',
        );

        return null;
      }

      return MagicStarterReleaseFeed.fromJson(payload);
    } catch (e, stackTrace) {
      Log.warning('[MagicStarterReleasesController.readFeed] $e\n$stackTrace');

      return null;
    }
  }

  /// Loads the feed into the controller state: success with the feed, empty
  /// when there are no releases, an error with the `fetch_error` copy when the
  /// read fails. A call while a read is in flight is ignored.
  Future<void> fetchReleases() async {
    if (_isFetching) return;
    _isFetching = true;
    setLoading();

    try {
      final MagicStarterReleaseFeed? feed = await readFeed();

      if (feed == null) {
        setError(trans('magic_starter.releases.fetch_error'));
        return;
      }

      if (feed.releases.isEmpty) {
        setEmpty();
        return;
      }

      setSuccess(feed);
    } finally {
      _isFetching = false;
    }
  }
}
