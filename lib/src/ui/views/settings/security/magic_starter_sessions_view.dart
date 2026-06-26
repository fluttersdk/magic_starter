import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../http/controllers/magic_starter_profile_controller.dart';
import '../../../components/settings_row/index.dart';
import '../../../components/settings_scaffold/settings_scaffold.dart';
import '../../../components/settings_section/settings_section.dart';
import '../../../widgets/magic_starter_password_confirm_dialog.dart';
import '../../../widgets/magic_starter_confirm_dialog.dart';

/// Active sessions settings sub-page.
///
/// Drilled into from the Settings hub. Wraps the browser-sessions list in a
/// [SettingsScaffold] with a unified back affordance returning to the hub.
///
/// Each device is rendered as a [SettingsRow] (destructive-tone revoke control
/// for non-current devices). The load + revoke wiring is lifted verbatim from
/// the original long-form profile settings view: it reuses
/// [MagicStarterProfileController.getSessions] / `doRevokeSession` /
/// `doRevokeOtherSessions` and the [MagicStarterPasswordConfirmDialog] widget
/// unchanged — no endpoint or controller signature is altered here.
class MagicStarterSessionsView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterSessionsView({super.key});

  @override
  State<MagicStarterSessionsView> createState() =>
      _MagicStarterSessionsViewState();
}

class _MagicStarterSessionsViewState extends MagicStatefulViewState<
    MagicStarterProfileController, MagicStarterSessionsView> {
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
    controller.clearErrors();
    controller.setEmpty();
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
      ValueNotifier<bool> notifier, Future<T> Function() action) async {
    notifier.value = true;
    try {
      return await action();
    } finally {
      notifier.value = false;
    }
  }

  Future<void> _loadSessions() async {
    setState(() => _sessionsLoading = true);
    final result = await controller.getSessions();
    if (!mounted) return;
    setState(() {
      _sessions = result ?? [];
      _sessionsLoading = false;
    });
  }

  Future<void> _revokeSession(BuildContext context, String tokenId) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    final success = await MagicStarterPasswordConfirmDialog.show(
      context,
      variant: ConfirmDialogVariant.danger,
      onConfirm: (password) async {
        final ok = await _trackLoading(
          _sessionActionLoading,
          () => controller.doRevokeSession(
            tokenId: tokenId,
            password: password,
          ),
        );
        if (!ok) {
          final error =
              controller.rxStatus.message ?? trans('common.error_occurred');
          controller.clearErrors();
          return error;
        }
        return null;
      },
    );

    if (success) {
      _loadSessions();
    }
  }

  Future<void> _revokeOtherSessions(BuildContext context) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    final success = await MagicStarterPasswordConfirmDialog.show(
      context,
      variant: ConfirmDialogVariant.danger,
      onConfirm: (password) async {
        final ok = await _trackLoading(
          _sessionActionLoading,
          () => controller.doRevokeOtherSessions(password: password),
        );
        if (!ok) {
          final error =
              controller.rxStatus.message ?? trans('common.error_occurred');
          controller.clearErrors();
          return error;
        }
        return null;
      },
    );

    if (success) {
      _loadSessions();
    }
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: trans('profile.browser_sessions'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        SettingsSection(
          footer: trans('profile.browser_sessions_description'),
          children: _buildSessionRows(),
        ),
        // Gate: guests cannot logout/revoke sessions.
        if (Gate.allows('starter.logout-sessions'))
          SettingsSection(
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
          SettingsSection(
            footer: trans('magic_starter.profile.delete_account.description'),
            children: [
              SettingsRow(
                title: trans('magic_starter.profile.delete_account.button'),
                icon: Icons.delete_outline,
                tone: SettingsRowTone.destructive,
                onTap: () => _confirmDeleteAccount(context),
              ),
            ],
          ),
      ],
    );
  }

  /// Opens the password-confirm dialog and deletes the account on confirm.
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    if (!context.mounted) return;
    await MagicStarterPasswordConfirmDialog.show(
      context,
      title: trans('magic_starter.profile.delete_account.title'),
      description: trans('magic_starter.profile.delete_account.description'),
      variant: ConfirmDialogVariant.danger,
      onConfirm: (password) async {
        final ok = await controller.doDeleteAccount(password: password);
        if (!ok) {
          final error =
              controller.rxStatus.message ?? trans('common.error_occurred');
          controller.clearErrors();
          return error;
        }
        return null;
      },
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

  /// Renders a single session as a [SettingsRow] with a device icon, the
  /// platform/browser title, location subtitle, and a destructive revoke
  /// trailing control for non-current devices.
  Widget _buildSessionRow(Map<String, dynamic> session) {
    final agent = session['agent'] as Map<String, dynamic>? ?? {};
    final locationMap = session['location'] as Map<String, dynamic>? ?? {};
    final isDesktop = agent['is_desktop'] as bool? ?? true;
    final platform = agent['platform'] as String? ?? '';
    final browser = agent['browser'] as String? ?? '';
    final ip = session['ip_address'] as String? ?? '';
    final city = locationMap['city'] as String? ?? '';
    final country = locationMap['country'] as String? ?? '';
    final isCurrent = session['is_current_device'] as bool? ?? false;
    final tokenId = session['id']?.toString() ?? '';

    final title = [platform, browser].where((s) => s.isNotEmpty).join(' - ');
    final locationText = [city, country].where((s) => s.isNotEmpty).join(', ');
    final subtitleText =
        [ip, locationText].where((s) => s.isNotEmpty).join('  ');

    return SettingsRow(
      icon: isDesktop ? _iconDesktop : _iconMobile,
      title: title.isNotEmpty ? title : trans('profile.browser_sessions'),
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
                  onTap:
                      isLoading ? null : () => _revokeSession(context, tokenId),
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
