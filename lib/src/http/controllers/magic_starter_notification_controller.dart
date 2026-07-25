import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Notification controller for Magic Starter plugin.
///
/// Manages notification preferences state and delegates view rendering
/// to the ViewRegistry. Follows the same singleton + MagicController pattern
/// as [MagicStarterAuthController] and [MagicStarterTeamController].
class MagicStarterNotificationController extends MagicController
    with MagicStateMixin<bool>, ValidatesRequests {
  /// Singleton accessor.
  static MagicStarterNotificationController get instance =>
      Magic.findOrPut(MagicStarterNotificationController.new);

  /// Preference matrix from backend.
  /// Structure: { "type_key": { "label": "...", "channels": { "channel": { "enabled": bool, "locked": bool } } } }
  final matrixNotifier = ValueNotifier<Map<String, dynamic>>({});

  /// Whether the backend reports its push integration as provisioned, read
  /// from the preference responses' `meta.push_provisioned`.
  ///
  /// A push preference is offered as soon as the backend enables its
  /// `onesignal` feature flag, but without a configured OneSignal `app_id` the
  /// channel is dropped at send time, so a `false` here means the toggle cannot
  /// deliver yet. Starts `true` and only moves on a response that actually
  /// carries the flag, so a backend that predates it (or a degraded payload)
  /// never renders a false "not configured" claim.
  final pushProvisionedNotifier = ValueNotifier<bool>(true);

  bool _isSubmitting = false;
  bool _isSaving = false;

  /// Render notifications list view via registry key.
  Widget index() => MagicStarter.view.make('notifications.list');

  /// Render notification preferences view via registry key.
  Widget preferences() => MagicStarter.view.make('notifications.preferences');

  /// Fetch notification preferences from API.
  Future<void> fetchPreferences() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setLoading();

    try {
      // 1. Fetch the current notification preference matrix.
      final response = await Http.get('/notification-preferences');

      // 2. Stop early when backend returns an unsuccessful response.
      if (!response.successful) {
        setError(trans('magic_starter.notifications.fetch_error'));
        return;
      }

      // 3. Publish the push-provisioning flag the same response carries.
      _publishPushProvisioned(response);

      // 4. Normalize and publish matrix payload for reactive UI updates.
      final data = response.data['data'];
      if (data is Map) {
        matrixNotifier.value = _normalizeMap(data);
      }
      setSuccess(true);
    } catch (e, stackTrace) {
      Log.error(
        '[MagicStarterNotificationController.fetchPreferences] $e\n$stackTrace',
      );
      setError(trans('errors.unexpected'));
    } finally {
      _isSubmitting = false;
    }
  }

  /// Publish `meta.push_provisioned` from [response] into
  /// [pushProvisionedNotifier], leaving the last known value untouched when the
  /// payload does not carry the flag as a bool.
  ///
  /// A missing flag is a backend that predates it or a degraded payload, not a
  /// statement that push became unconfigured, so it must never flip the value.
  void _publishPushProvisioned(MagicResponse response) {
    final data = response.data;
    if (data is! Map) return;

    final meta = data['meta'];
    if (meta is! Map) return;

    final provisioned = meta['push_provisioned'];
    if (provisioned is bool) {
      pushProvisionedNotifier.value = provisioned;
    }
  }

  /// Normalize dynamic map payloads to `Map<String, dynamic>` recursively.
  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> source) {
    return source.map(
      (key, value) => MapEntry(
        key.toString(),
        value is Map ? _normalizeMap(value) : value,
      ),
    );
  }

  /// Update a single channel preference with optimistic UI update.
  ///
  /// 1. Snapshot current matrix as rollback state.
  /// 2. Apply optimistic update locally.
  /// 3. Send PUT request to backend.
  /// 4. Revert to snapshot on failure.
  Future<void> updateTypePreference(
    String type,
    String channel,
    bool isEnabled,
  ) async {
    if (_isSaving) return;
    _isSaving = true;

    // 1. Snapshot for rollback.
    final oldMatrix = Map<String, dynamic>.from(matrixNotifier.value);

    try {
      // 2. Apply optimistic update.
      final newMatrix = Map<String, dynamic>.from(matrixNotifier.value);
      if (newMatrix.containsKey(type)) {
        final typeData =
            Map<String, dynamic>.from(newMatrix[type] as Map<String, dynamic>);
        if (typeData.containsKey('channels')) {
          final channelsData = Map<String, dynamic>.from(
            typeData['channels'] as Map<String, dynamic>,
          );
          if (channelsData.containsKey(channel)) {
            final channelData = Map<String, dynamic>.from(
              channelsData[channel] as Map<String, dynamic>,
            );
            channelData['enabled'] = isEnabled;
            channelsData[channel] = channelData;
          }
          typeData['channels'] = channelsData;
        }
        newMatrix[type] = typeData;
      }
      matrixNotifier.value = newMatrix;

      // 3. Send to backend.
      final response = await Http.put(
        '/notification-preferences',
        data: {
          'type': type,
          'channel': channel,
          'is_enabled': isEnabled,
        },
      );

      // 4. Revert on failure.
      if (!response.successful) {
        matrixNotifier.value = oldMatrix;
        Log.error(
          '[MagicStarterNotificationController.updateTypePreference] PUT failed: ${response.statusCode}',
        );

        return;
      }

      // 5. The write response republishes the provisioning flag, so a save
      // keeps the heads-up in sync without a second fetch.
      _publishPushProvisioned(response);
    } catch (e, stackTrace) {
      matrixNotifier.value = oldMatrix;
      Log.error(
        '[MagicStarterNotificationController.updateTypePreference] $e\n$stackTrace',
      );
    } finally {
      _isSaving = false;
    }
  }

  @override
  void dispose() {
    matrixNotifier.dispose();
    pushProvisionedNotifier.dispose();
    super.dispose();
  }
}
