import 'package:flutter/material.dart' show Icons, CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_notification_controller.dart';
import '../../components/switch/switch.dart';
import '../../components/card/card.dart';
import '../../components/page_scaffold/page_scaffold.dart';

/// Notification preferences view for Magic Starter.
///
/// Displays a type × channel preference matrix loaded from [MagicStarterNotificationController].
/// Each notification type shows its available channels as toggle switches with icons.
class MagicStarterNotificationPreferencesView
    extends MagicStatefulView<MagicStarterNotificationController> {
  const MagicStarterNotificationPreferencesView({
    super.key,
    this.pushProvisioned,
  });

  /// Host override for the push-provisioning state, or `null` (the default) to
  /// read it from the backend.
  ///
  /// The preference responses carry `meta.push_provisioned`, so the controller
  /// already knows whether the app configured its OneSignal `app_id`; when that
  /// is `false`, a subtle "push not yet configured" hint renders beneath the
  /// push channel toggle so the user understands it cannot deliver yet. Pass a
  /// bool here only to force the hint on or off (a host that resolves push
  /// provisioning some other way, or a test).
  final bool? pushProvisioned;

  @override
  State<MagicStarterNotificationPreferencesView> createState() =>
      _MagicStarterNotificationPreferencesViewState();
}

class _MagicStarterNotificationPreferencesViewState
    extends
        MagicStatefulViewState<
          MagicStarterNotificationController,
          MagicStarterNotificationPreferencesView
        > {
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

    return MSPageScaffold(
      title: trans('notifications.preferences_title'),
      subtitle: trans('notifications.preferences_description'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        if (headerSlot != null) headerSlot,
        _buildMatrixSettings(),
        if (footerSlot != null) footerSlot,
      ],
    );
  }

  Widget _buildMatrixSettings() {
    // Both the matrix and the push-provisioning flag are published by the same
    // preference response, so one merged listenable rebuilds the toggles and
    // their heads-up together.
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.matrixNotifier,
        controller.pushProvisionedNotifier,
      ]),
      builder: (context, _) {
        final Map<String, dynamic> matrix = controller.matrixNotifier.value;

        if (matrix.isEmpty) {
          return MSCard(
            title: '',
            child: WDiv(
              className:
                  'w-full py-12 flex flex-col items-center justify-center gap-3',
              children: [
                WIcon(
                  Icons.notifications_off_outlined,
                  className: 'text-4xl text-fg-disabled',
                ),
                WText(
                  trans('notifications.no_preferences'),
                  className: 'text-sm text-fg-muted',
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

  Widget _buildNotificationType(String typeKey, Map<String, dynamic> typeData) {
    final title = typeData['label']?.toString() ?? typeKey;
    final channels = typeData['channels'] as Map<String, dynamic>? ?? {};
    final channelKeys = channels.keys.toList();

    return MSCard(
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
    // The push channel toggle cannot deliver until the app provisions its push
    // integration; surface a subtle heads-up beneath its label when it has not.
    // The backend-reported flag drives it, unless the host forced a value.
    final bool pushProvisioned =
        widget.pushProvisioned ?? controller.pushProvisionedNotifier.value;
    final bool showPushHint =
        channel.toLowerCase() == 'push' && !pushProvisioned;

    return WDiv(
      className: '''
        px-6 py-4 flex items-center justify-between
        border-b border-color-border-subtle
        last:border-b-0
      ''',
      children: [
        WDiv(
          // `flex-1 min-w-0` so the icon-plus-text half yields to the switch
          // instead of demanding its intrinsic width. Without it the row
          // overflowed by 14 pixels at 430px on any channel carrying the push
          // hint below (measured in the uptizm app: Flutter painted the "RIGHT
          // OVERFLOWED BY 14 PIXELS" stripe over every Push row), because a
          // two-line text column is wider than a one-line one and nothing told
          // it to shrink.
          className: 'flex-1 min-w-0 flex items-center gap-4',
          children: [
            WDiv(
              className:
                  '''
                w-10 h-10 rounded-full flex items-center justify-center
                ${isEnabled && !isLocked ? 'bg-primary/10 dark:bg-primary/10' : 'bg-surface-container-high'}
              ''',
              child: WIcon(
                isLocked ? _iconLocked : icon,
                className:
                    '''
                  text-[18px]
                  ${isEnabled && !isLocked ? 'text-primary' : 'text-fg-muted'}
                ''',
              ),
            ),
            WDiv(
              // `min-w-0` so the label and the hint can wrap rather than force
              // the row wider than its container.
              className: 'flex-1 min-w-0 flex flex-col gap-1',
              children: [
                // The switch below carries this same text as its semanticLabel,
                // so exclude the visible copy from semantics: otherwise the row
                // exposes TWO nodes with the same name (this paragraph AND the
                // switch) and a getByLabel / E2E lookup resolves the
                // non-interactive text first, landing the tap on the label
                // instead of the toggle. The hint below stays OUT of the
                // exclusion: it carries information the switch label does not,
                // so a screen reader has to announce it.
                ExcludeSemantics(
                  child: WText(
                    _channelLabel(channel),
                    className: 'text-sm font-medium text-fg',
                  ),
                ),
                if (showPushHint)
                  WText(
                    trans('notifications.channel_push_unconfigured'),
                    className: 'text-xs text-fg-muted',
                  ),
              ],
            ),
          ],
        ),
        MSSwitch(
          value: isEnabled,
          disabled: isLocked,
          // Label the toggle with its visible channel name: the channel text is
          // a sibling WText, so without this the switch had no accessible name
          // (a screen reader announced a bare "switch") and no stable handle
          // for an E2E driver to resolve.
          semanticLabel: _channelLabel(channel),
          onChanged: (newValue) {
            controller.updateTypePreference(type, channel, newValue);
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
