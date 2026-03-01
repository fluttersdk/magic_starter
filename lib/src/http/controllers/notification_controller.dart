import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Notification controller for Magic Starter plugin.
///
/// Manages notification preferences state and delegates view rendering
/// to the ViewRegistry. Follows the same singleton + MagicController pattern
/// as [StarterAuthController] and [StarterTeamController].
class StarterNotificationController extends MagicController {
  /// Singleton accessor.
  static StarterNotificationController get instance =>
      Magic.findOrPut(StarterNotificationController.new);

  /// Preference matrix from backend.
  /// Structure: { "type_key": { "label": "...", "channels": { "channel": { "enabled": bool, "locked": bool } } } }
  final matrixNotifier = ValueNotifier<Map<String, dynamic>>({});

  final isLoadingNotifier = ValueNotifier<bool>(false);
  final isSavingNotifier = ValueNotifier<bool>(false);

  /// Render notifications list view via registry key.
  Widget index() => MagicStarter.view.make('notifications.list');

  /// Render notification preferences view via registry key.
  Widget preferences() => MagicStarter.view.make('notifications.preferences');

  /// Fetch notification preferences from API.
  Future<void> fetchPreferences() async {
    isLoadingNotifier.value = true;
    try {
      final response = await Http.get('/notification-preferences');
      if (response.successful) {
        final data = response.data['data'];
        if (data is Map) {
          matrixNotifier.value = _normalizeMap(data);
        }
      }
    } catch (e, stackTrace) {
      Log.error(
          '[StarterNotificationController.fetchPreferences] $e\n$stackTrace');
    } finally {
      isLoadingNotifier.value = false;
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
    // 1. Snapshot for rollback.
    final oldMatrix = Map<String, dynamic>.from(matrixNotifier.value);

    // 2. Apply optimistic update.
    final newMatrix = Map<String, dynamic>.from(matrixNotifier.value);
    if (newMatrix.containsKey(type)) {
      final typeData =
          Map<String, dynamic>.from(newMatrix[type] as Map<String, dynamic>);
      if (typeData.containsKey('channels')) {
        final channelsData = Map<String, dynamic>.from(
            typeData['channels'] as Map<String, dynamic>);
        if (channelsData.containsKey(channel)) {
          final channelData = Map<String, dynamic>.from(
              channelsData[channel] as Map<String, dynamic>);
          channelData['enabled'] = isEnabled;
          channelsData[channel] = channelData;
        }
        typeData['channels'] = channelsData;
      }
      newMatrix[type] = typeData;
    }
    matrixNotifier.value = newMatrix;

    // 3. Send to backend.
    try {
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
            '[StarterNotificationController.updateTypePreference] PUT failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      matrixNotifier.value = oldMatrix;
      Log.error(
          '[StarterNotificationController.updateTypePreference] $e\n$stackTrace');
    }
  }

  @override
  void dispose() {
    matrixNotifier.dispose();
    isLoadingNotifier.dispose();
    isSavingNotifier.dispose();
    super.dispose();
  }
}
