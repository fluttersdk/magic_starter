import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../http/controllers/magic_starter_newsletter_controller.dart';
import '../../../components/settings_row/index.dart';
import '../../../components/page_scaffold/index.dart';
import '../../../components/settings_section/index.dart';
import '../../../components/switch/index.dart';

/// Newsletter settings sub-page — a single toggle row bound to the optimistic
/// newsletter controller.
///
/// Lifts the long-form profile view's newsletter section verbatim: a
/// [MSSettingsRow] with a trailing [MSSwitch] wired to
/// [MagicStarterNewsletterController.updateNewsletterSubscription] (optimistic
/// update). The current status is fetched on init via `getNewsletterStatus`
/// and surfaced through the controller's `renderState`.
class MagicStarterNewsletterView
    extends MagicStatefulView<MagicStarterNewsletterController> {
  const MagicStarterNewsletterView({super.key});

  @override
  State<MagicStarterNewsletterView> createState() =>
      _MagicStarterNewsletterViewState();
}

class _MagicStarterNewsletterViewState extends MagicStatefulViewState<
    MagicStarterNewsletterController, MagicStarterNewsletterView> {
  static const _iconNewsletter = Icons.mail_outline;
  static const _iconLoading = Icons.refresh;

  /// Isolated switch spinner, decoupled from the controller's global loading
  /// flag (mirrors the source view's per-section notifier pattern).
  final ValueNotifier<bool> _toggleLoading = ValueNotifier<bool>(false);

  @override
  void onInit() {
    controller.getNewsletterStatus();
  }

  @override
  void onClose() {
    _toggleLoading.dispose();
  }

  /// Toggles the subscription optimistically through the controller.
  Future<void> _toggle(bool subscribe) async {
    _toggleLoading.value = true;
    try {
      await controller.updateNewsletterSubscription(subscribe: subscribe);
    } finally {
      _toggleLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MSPageScaffold(
      title: trans('magic_starter.newsletter.section_title'),
      subtitle: trans('magic_starter.newsletter.section_description'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        MSSettingsSection(
          footer: trans('magic_starter.newsletter.section_description'),
          children: [
            controller.renderState(
              (data) {
                final isSubscribed = data?['subscribed'] as bool? ?? false;
                return ValueListenableBuilder<bool>(
                  valueListenable: _toggleLoading,
                  builder: (context, isLoading, _) => MSSettingsRow(
                    icon: _iconNewsletter,
                    title: trans('magic_starter.newsletter.toggle_label'),
                    subtitle: isSubscribed
                        ? trans('magic_starter.newsletter.subscribed_status')
                        : trans('magic_starter.newsletter.unsubscribed_status'),
                    trailing: MSSwitch(
                      value: isSubscribed,
                      disabled: isLoading,
                      onChanged: (newValue) => _toggle(newValue),
                    ),
                  ),
                );
              },
              onEmpty: MSSettingsRow(
                icon: _iconNewsletter,
                title: trans('magic_starter.newsletter.toggle_label'),
                trailing: WIcon(
                  _iconLoading,
                  className: 'text-fg-muted animate-spin text-xl',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
