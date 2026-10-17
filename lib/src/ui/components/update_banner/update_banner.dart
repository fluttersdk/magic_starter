import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../button/index.dart';
import 'update_banner.recipe.dart';

/// **Non-modal strip announcing that a newer version of the app is available.**
///
/// An icon and a message that wraps, a primary action and a ghost dismiss
/// button. Below `md:` the message and the buttons stack vertically; from `md:`
/// up they share one row.
///
/// Presentation only: it holds no state, reads no storage, starts no timer and
/// calls no `trans()`. The caller decides when it shows, supplies every string
/// already translated, and owns what the action and the dismissal do.
///
/// The strip is a polite live region, so a screen reader announces it when it
/// appears without taking focus.
///
/// ### Example:
/// ```dart
/// MSUpdateBanner(
///   message: 'A new version is available.',
///   actionLabel: 'Reload',
///   onAction: reloadPage,
///   dismissLabel: 'Later',
///   onDismiss: hideForThisBuild,
/// )
/// ```
@immutable
class MSUpdateBanner extends StatelessWidget {
  /// What happened, already translated. Wraps instead of truncating.
  final String message;

  /// Label of the primary button, already translated.
  final String actionLabel;

  /// Tapped when the primary button is pressed.
  final VoidCallback onAction;

  /// Label of the ghost button, already translated.
  final String dismissLabel;

  /// Tapped when the ghost button is pressed.
  final VoidCallback onDismiss;

  /// Leading glyph; defaults to a system-update icon.
  final IconData icon;

  /// Creates an [MSUpdateBanner].
  const MSUpdateBanner({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.dismissLabel,
    required this.onDismiss,
    this.icon = _defaultIcon,
  });

  static const IconData _defaultIcon = Icons.system_update_alt;

  @override
  Widget build(BuildContext context) {
    final slots = updateBannerRecipe(variants: const <String, String>{});

    return Semantics(
      liveRegion: true,
      container: true,
      child: WDiv(
        className: slots['root'],
        children: [
          WDiv(
            className: slots['body'],
            children: [
              WIcon(icon, className: slots['icon']),
              WText(message, className: slots['message']),
            ],
          ),
          WDiv(
            className: slots['actions'],
            children: [
              MSButton(
                intent: ButtonIntent.primary,
                size: ButtonSize.sm,
                onPressed: onAction,
                child: WText(actionLabel),
              ),
              MSButton(
                intent: ButtonIntent.ghost,
                size: ButtonSize.sm,
                onPressed: onDismiss,
                child: WText(dismissLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
