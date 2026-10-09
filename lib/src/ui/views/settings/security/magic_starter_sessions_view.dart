import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../facades/magic_starter.dart';
import '../../../../http/controllers/magic_starter_profile_controller.dart';
import '../../../components/confirm_dialog/confirm_dialog.dart';
import '../../../components/dialog/dialog.dart';
import '../../../components/settings_row/index.dart';
import '../../../components/page_scaffold/page_scaffold.dart';
import '../../../components/settings_section/settings_section.dart';
import '../../../widgets/magic_starter_confirm_dialog.dart';
import '../../../../support/confirms_identity.dart';
import '../../../../support/session_device_title.dart';

/// Asks whether the account goes after the grace period or now, then confirms
/// identity and deletes it.
///
/// Shared by every screen that offers account deletion: the choice is a
/// question about the account, so the screens ask it the same way. Dismissing
/// the choice, or the identity dialog, deletes nothing. The server applies the
/// same refusals and step-up whichever is chosen.
///
/// A refusal that something in the app can clear (a store or card subscription
/// blocking the deletion) is followed by a dialog that carries the refusal's
/// sentence and that one action, so the user is never left with a dead end.
Future<void> confirmAndDeleteAccount(
  BuildContext context,
  MagicStarterProfileController controller,
) async {
  if (!context.mounted) return;

  // 1. The choice comes first: it decides what the proof is spent on.
  final immediately = await MSDialog.show<bool>(
    context,
    title: trans('magic_starter.profile.delete_account.title'),
    description: trans('magic_starter.profile.delete_account.description'),
    body: Builder(
      builder: (dialogContext) {
        final theme = MagicStarter.manager.modalTheme;

        return WDiv(
          className: 'flex flex-col gap-3',
          children: [
            WButton(
              onTap: () => Navigator.of(dialogContext).pop(false),
              className: theme.primaryButtonClassName,
              child: WText(
                trans('magic_starter.profile.delete_account.option_scheduled'),
              ),
            ),
            WButton(
              onTap: () => Navigator.of(dialogContext).pop(true),
              className: theme.dangerButtonClassName,
              child: WText(
                trans('magic_starter.profile.delete_account.option_immediate'),
              ),
            ),
          ],
        );
      },
    ),
    footerBuilder: (dialogContext) => WDiv(
      className: 'flex flex-row justify-end',
      child: WAnchor(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: WDiv(
          className: MagicStarter.manager.modalTheme.secondaryButtonClassName,
          child: WText(trans('common.cancel')),
        ),
      ),
    ),
  );
  if (immediately == null || !context.mounted) return;

  // 2. Both answers are gated by the same proof.
  final deleted = await confirmAndRun(
    context,
    controller,
    title: trans('magic_starter.profile.delete_account.title'),
    description: trans('magic_starter.profile.delete_account.description'),
    variant: ConfirmDialogVariant.danger,
    action: (proof) =>
        controller.doDeleteAccount(proof: proof, immediately: immediately),
  );

  // 3. A refusal the user can clear stays on screen with its way out.
  final action = controller.refusalAction;
  if (deleted || action == null || !context.mounted) return;

  await _showRefusalAction(context, controller.rxStatus.message, action);
}

/// Shows why the deletion was refused next to the [action] that clears it.
///
/// The action runs after the dialog closes, so its own feedback (a toast) is
/// not hidden behind it.
Future<void> _showRefusalAction(
  BuildContext context,
  String? message,
  MagicStarterRefusalAction action,
) {
  return MSDialog.show<void>(
    context,
    title: trans('magic_starter.profile.delete_account.title'),
    description: message,
    body: Builder(
      builder: (dialogContext) {
        return WButton(
          onTap: () async {
            Navigator.of(dialogContext).pop();
            await action.run();
          },
          className: MagicStarter.manager.modalTheme.primaryButtonClassName,
          child: WText(action.label),
        );
      },
    ),
    footerBuilder: (dialogContext) => WDiv(
      className: 'flex flex-row justify-end',
      child: WAnchor(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: WDiv(
          className: MagicStarter.manager.modalTheme.secondaryButtonClassName,
          child: WText(trans('common.cancel')),
        ),
      ),
    ),
  );
}

/// Active sessions settings sub-page.
///
/// Drilled into from the Settings hub. Wraps the browser-sessions list in a
/// [MSPageScaffold] with a unified back affordance returning to the hub.
///
/// Each device is rendered as a [MSSettingsRow] (destructive-tone revoke control
/// for non-current devices). The load + revoke wiring is lifted verbatim from
/// the original long-form profile settings view: it reuses
/// [MagicStarterProfileController.getSessions] / `doRevokeSession` /
/// `doRevokeOtherSessions` unchanged, confirming identity through
/// [confirmAndRun] with whichever proof the account can send.
class MagicStarterSessionsView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterSessionsView({super.key});

  @override
  State<MagicStarterSessionsView> createState() =>
      _MagicStarterSessionsViewState();
}

class _MagicStarterSessionsViewState
    extends
        MagicStatefulViewState<
          MagicStarterProfileController,
          MagicStarterSessionsView
        > {
  static const _iconDesktop = Icons.computer;
  static const _iconMobile = Icons.phone_android;

  /// Per-section loading notifier — decouples the revoke spinner from the
  /// controller's global [MagicStateMixin.isLoading] flag.
  final ValueNotifier<bool> _sessionActionLoading = ValueNotifier<bool>(false);

  List<Map<String, dynamic>> _sessions = [];
  bool _sessionsLoading = false;

  // -- Lifecycle -------------------------------------------------------------

  @override
  void onInit() {
    controller.resetQuietly();
    if (MagicStarterConfig.hasSessionsFeatures()) {
      _loadSessions();
    }
  }

  @override
  void onClose() {
    _sessionActionLoading.dispose();
  }

  // -- Actions ---------------------------------------------------------------

  /// Execute [action] while driving [notifier] to `true`/`false`.
  Future<T> _trackLoading<T>(
    ValueNotifier<bool> notifier,
    Future<T> Function() action,
  ) async {
    notifier.value = true;
    try {
      return await action();
    } finally {
      notifier.value = false;
    }
  }

  Future<void> _loadSessions() async {
    setState(() => _sessionsLoading = true);
    // Quietly: this runs from onInit, while the route is still being built,
    // and `getSessions` sets loading before its first await, which would mark
    // every other view of the shared controller dirty mid-build (the settings
    // hub under this page). This view drives its own spinner.
    final result = await controller.withoutNotifying(controller.getSessions);
    if (!mounted) return;
    setState(() {
      _sessions = result ?? [];
      _sessionsLoading = false;
    });
  }

  Future<void> _revokeSession(BuildContext context, String tokenId) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    final success = await confirmAndRun(
      context,
      controller,
      variant: ConfirmDialogVariant.danger,
      action: (proof) => _trackLoading(
        _sessionActionLoading,
        () => controller.doRevokeSession(tokenId: tokenId, proof: proof),
      ),
    );

    if (success) {
      _loadSessions();
    }
  }

  Future<void> _revokeOtherSessions(BuildContext context) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    final success = await confirmAndRun(
      context,
      controller,
      variant: ConfirmDialogVariant.danger,
      action: (proof) => _trackLoading(
        _sessionActionLoading,
        () => controller.doRevokeOtherSessions(proof: proof),
      ),
    );

    if (success) {
      _loadSessions();
    }
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MSPageScaffold(
      title: trans('profile.browser_sessions'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        MSSettingsSection(
          footer: trans('profile.browser_sessions_description'),
          children: _buildSessionRows(),
        ),
        // Gate: guests cannot logout/revoke sessions.
        if (Gate.allows('starter.logout-sessions'))
          MSSettingsSection(
            children: [
              MagicBuilder<bool>(
                listenable: _sessionActionLoading,
                builder: (isLoading) => WDiv(
                  className: 'px-5 py-4',
                  children: [
                    Builder(
                      builder: (context) => WButton(
                        onTap: isLoading
                            ? null
                            : () => _revokeOtherSessions(context),
                        isLoading: isLoading,
                        className:
                            'text-destructive border border-color-border hover:bg-surface-container rounded-lg px-4 py-2 w-full flex justify-center',
                        child: WText(trans('profile.logout_other_sessions')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        // Danger zone — destructive Delete Account row (full members only).
        // Lives here, on the Security > Sessions sub-page, rather than on the
        // Profile form: account deletion is a security/account action.
        if (Gate.allows('starter.delete-account'))
          MSSettingsSection(
            footer: trans('magic_starter.profile.delete_account.description'),
            children: [
              MSSettingsRow(
                title: trans('magic_starter.profile.delete_account.button'),
                icon: Icons.delete_outline,
                tone: SettingsRowTone.destructive,
                onTap: () => confirmAndDeleteAccount(context, controller),
              ),
            ],
          ),
      ],
    );
  }

  /// Builds the list of session rows (or the loading / empty placeholder).
  List<Widget> _buildSessionRows() {
    if (_sessionsLoading) {
      return [
        WDiv(
          className: 'flex flex-row justify-center px-5 py-6',
          children: [
            WIcon(
              Icons.refresh,
              className: 'text-fg-muted animate-spin text-2xl',
            ),
          ],
        ),
      ];
    }

    if (_sessions.isEmpty) {
      return [
        WDiv(
          className: 'px-5 py-6',
          children: [
            WText(
              trans('profile.no_active_sessions'),
              className: 'text-sm text-fg-muted text-center',
            ),
          ],
        ),
      ];
    }

    return _sessions.map(_buildSessionRow).toList();
  }

  /// Renders a single session as a [MSSettingsRow] with a device icon, the
  /// platform/browser title, location subtitle, and a destructive revoke
  /// trailing control for non-current devices.
  Widget _buildSessionRow(Map<String, dynamic> session) {
    final agent = session['agent'] as Map<String, dynamic>? ?? {};
    final locationMap = session['location'] as Map<String, dynamic>? ?? {};
    final isDesktop = agent['is_desktop'] as bool? ?? true;
    final platform = agent['platform'] as String? ?? '';
    final browser = agent['browser'] as String? ?? '';
    // The native application's name, sent since magic-starter-laravel 0.0.9 for
    // an agent shaped `<App> (Flutter; iOS)`. Absent for a browser, and absent
    // entirely from an older backend, which is why it is read defensively.
    final app = agent['app'] as String? ?? '';
    final ip = session['ip_address'] as String? ?? '';
    final city = locationMap['city'] as String? ?? '';
    final country = locationMap['country'] as String? ?? '';
    final isCurrent = session['is_current_device'] as bool? ?? false;
    final tokenId = session['id']?.toString() ?? '';

    final title = sessionDeviceTitle(
      platform: platform,
      browser: browser,
      app: app,
    );
    final locationText = [city, country].where((s) => s.isNotEmpty).join(', ');
    final subtitleText = [
      ip,
      locationText,
    ].where((s) => s.isNotEmpty).join('  ');

    return MSSettingsRow(
      icon: isDesktop ? _iconDesktop : _iconMobile,
      title: title.isNotEmpty ? title : trans('profile.unknown_device'),
      subtitle: subtitleText.isNotEmpty ? subtitleText : null,
      trailing: isCurrent
          ? WDiv(
              className:
                  'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 text-xs font-medium px-2 py-0.5 rounded-full',
              children: [WText(trans('profile.current_device'))],
            )
          : MagicBuilder<bool>(
              listenable: _sessionActionLoading,
              builder: (isLoading) => Builder(
                builder: (context) => WButton(
                  onTap: isLoading
                      ? null
                      : () => _revokeSession(context, tokenId),
                  isLoading: isLoading,
                  className:
                      'text-destructive text-sm px-3 py-1 rounded border border-color-border hover:bg-surface-container',
                  child: WText(
                    trans('profile.revoke'),
                    className: 'text-destructive',
                  ),
                ),
              ),
            ),
    );
  }
}
