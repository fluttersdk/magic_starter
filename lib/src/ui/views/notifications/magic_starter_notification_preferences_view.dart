import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import '../../widgets/magic_starter_page_header.dart';
import '../../widgets/magic_starter_card.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_notification_controller.dart';

/// Notification preferences view for Magic Starter.
///
/// Displays a type × channel preference matrix loaded from [MagicStarterNotificationController].
/// Each notification type shows its available channels as toggle switches with icons.
class MagicStarterNotificationPreferencesView
    extends MagicStatefulView<MagicStarterNotificationController> {
  const MagicStarterNotificationPreferencesView({super.key});

  @override
  State<MagicStarterNotificationPreferencesView> createState() =>
      _MagicStarterNotificationPreferencesViewState();
}

class _MagicStarterNotificationPreferencesViewState
    extends MagicStatefulViewState<MagicStarterNotificationController,
        MagicStarterNotificationPreferencesView> {
  static const _iconLocked = Icons.lock_outline;
  static const _channelIcons = <String, IconData>{
    'mail': Icons.mail_outline,
    'database': Icons.inbox_outlined,
    'push': Icons.notifications_outlined,
  };
  static const _defaultChannelIcon = Icons.circle_notifications_outlined;

  @override
  void onInit() {
    super.onInit();
    controller.fetchPreferences();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const WDiv(
        className: 'py-12 flex items-center justify-center',
        child: CircularProgressIndicator(),
      );
    }

    final headerSlot = MagicStarter.view.buildSlot(
      'notifications.preferences',
      'header',
      context,
    );
    final footerSlot = MagicStarter.view.buildSlot(
      'notifications.preferences',
      'footer',
      context,
    );

    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        if (headerSlot != null) headerSlot,
        MagicStarterPageHeader(
          title: trans('notifications.preferences_title'),
          subtitle: trans('notifications.preferences_description'),
        ),
        _buildMatrixSettings(),
        if (footerSlot != null) footerSlot,
      ],
    );
  }

  Widget _buildMatrixSettings() {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: controller.matrixNotifier,
      builder: (context, matrix, _) {
        if (matrix.isEmpty) {
          return MagicStarterCard(
            title: '',
            child: WDiv(
              className:
                  'w-full py-12 flex flex-col items-center justify-center gap-3',
              children: [
                WIcon(
                  Icons.notifications_off_outlined,
                  className: 'text-4xl text-gray-300 dark:text-gray-600',
                ),
                WText(
                  trans('notifications.no_preferences'),
                  className: 'text-sm text-gray-500 dark:text-gray-400',
                ),
              ],
            ),
          );
        }

        final types = matrix.keys.toList();

        return WDiv(
          className: 'flex flex-col gap-6',
          children: [
            for (var i = 0; i < types.length; i++)
              _buildNotificationType(
                types[i],
                matrix[types[i]] as Map<String, dynamic>,
              ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationType(
    String typeKey,
    Map<String, dynamic> typeData,
  ) {
    final title = typeData['label']?.toString() ?? typeKey;
    final channels = typeData['channels'] as Map<String, dynamic>? ?? {};
    final channelKeys = channels.keys.toList();

    return MagicStarterCard(
      title: title,
      noPadding: true,
      child: WDiv(
        className: 'flex flex-col',
        children: [
          for (var i = 0; i < channelKeys.length; i++)
            _buildChannelToggle(
              typeKey,
              channelKeys[i],
              channels[channelKeys[i]] as Map<String, dynamic>,
            ),
        ],
      ),
    );
  }

  Widget _buildChannelToggle(
    String type,
    String channel,
    Map<String, dynamic> channelData,
  ) {
    final bool isEnabled = channelData['enabled'] as bool? ?? false;
    final bool isLocked = channelData['locked'] as bool? ?? false;
    final icon = _channelIcon(channel);

    return WDiv(
      className: '''
        px-6 py-4 flex items-center justify-between
        border-b border-gray-100 dark:border-gray-700
        last:border-b-0
      ''',
      children: [
        WDiv(
          className: 'flex items-center gap-4',
          children: [
            WDiv(
              className: '''
                w-10 h-10 rounded-full flex items-center justify-center
                ${isEnabled && !isLocked ? 'bg-primary/10 dark:bg-primary/10' : 'bg-gray-100 dark:bg-gray-700'}
              ''',
              child: WIcon(
                isLocked ? _iconLocked : icon,
                className: '''
                  text-[18px]
                  ${isEnabled && !isLocked ? 'text-primary' : 'text-gray-500 dark:text-gray-400'}
                ''',
              ),
            ),
            WText(
              _channelLabel(channel),
              className: 'text-sm font-medium text-gray-900 dark:text-white',
            ),
          ],
        ),
        Switch.adaptive(
          value: isEnabled,
          activeThumbColor: Theme.of(context).colorScheme.onPrimary,
          activeTrackColor: Theme.of(context).colorScheme.primary,
          onChanged: isLocked
              ? null
              : (newValue) {
                  controller.updateTypePreference(
                    type,
                    channel,
                    newValue,
                  );
                },
        ),
      ],
    );
  }

  /// Returns the appropriate icon for a notification channel.
  IconData _channelIcon(String channel) {
    return _channelIcons[channel.toLowerCase()] ?? _defaultChannelIcon;
  }

  /// Returns a user-friendly label for a notification channel.
  String _channelLabel(String channel) {
    return switch (channel.toLowerCase()) {
      'mail' => trans('notifications.channel_email'),
      'database' => trans('notifications.channel_in_app'),
      'push' => trans('notifications.channel_push'),
      _ => _capitalize(channel),
    };
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).replaceAll('_', ' ');
  }
}
