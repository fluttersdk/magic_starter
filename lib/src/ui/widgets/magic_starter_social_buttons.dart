import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../contracts/magic_starter_social_auth.dart';
import '../../facades/magic_starter.dart';
import '../components/button/index.dart';

/// One "Continue with" button per provider the social login bridge offers.
///
/// Renders [MagicStarterSocialAuth.providers] in order, each with the
/// provider's icon and label, and hands the tapped provider to [onSelected]
/// synchronously, so a web provider popup still opens inside the tap.
///
/// [isLoading] disables every button while another submission runs.
/// [busyProvider] marks the provider whose flow is open: its icon becomes a
/// spinner, but it stays tappable, since a newer tap supersedes a pending flow
/// and a web popup the user closed never reports back.
class MagicStarterSocialButtons extends StatelessWidget {
  /// Creates the buttons for [socialAuth].
  const MagicStarterSocialButtons({
    super.key,
    required this.socialAuth,
    required this.onSelected,
    this.isLoading = false,
    this.busyProvider,
  });

  /// The bridge whose providers are offered.
  final MagicStarterSocialAuth socialAuth;

  /// Called with the provider the user tapped.
  final void Function(String provider) onSelected;

  /// Whether another submission is running; disables every button.
  final bool isLoading;

  /// The provider whose flow is open, if any.
  final String? busyProvider;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col items-stretch gap-3',
      children: [
        for (final provider in socialAuth.providers())
          MSButton(
            onPressed: () => onSelected(provider),
            disabled: isLoading,
            className: MagicStarter.formTheme.secondaryButtonClassName,
            child: WDiv(
              className: 'flex flex-row items-center justify-center gap-2',
              children: [
                if (provider == busyProvider)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  socialAuth.icon(provider),
                WText(
                  trans('social.continue_with', {
                    'provider': socialAuth.label(provider),
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
