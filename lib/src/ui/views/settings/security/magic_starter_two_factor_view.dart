import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../http/controllers/magic_starter_profile_controller.dart';
import '../../../components/page_scaffold/page_scaffold.dart';
import '../../../components/settings_section/settings_section.dart';
import '../../../widgets/magic_starter_password_confirm_dialog.dart';
import '../../../widgets/magic_starter_two_factor_modal.dart';
import '../../../widgets/magic_starter_confirm_dialog.dart';

/// Two-factor authentication settings sub-page.
///
/// Drilled into from the Settings hub. Wraps the 2FA management surface in a
/// [MSPageScaffold] with a unified back affordance returning to the hub.
///
/// The interaction wiring (enable / disable / show + regenerate recovery codes)
/// is lifted verbatim from the original long-form profile settings view: it
/// reuses the [MagicStarterProfileController] security methods and the
/// [MagicStarterTwoFactorModal] / [MagicStarterPasswordConfirmDialog] widgets
/// unchanged — no endpoint, controller, or modal internals are altered here.
class MagicStarterTwoFactorView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterTwoFactorView({super.key});

  @override
  State<MagicStarterTwoFactorView> createState() =>
      _MagicStarterTwoFactorViewState();
}

class _MagicStarterTwoFactorViewState
    extends
        MagicStatefulViewState<
          MagicStarterProfileController,
          MagicStarterTwoFactorView
        > {
  // -- 2FA UI state: 'disabled' | 'enabled' ----------------------------------

  String _twoFactorState = 'disabled';
  List<String> _recoveryCodes = [];

  /// Per-section loading notifier — decouples the 2FA section's spinner from
  /// the controller's global [MagicStateMixin.isLoading] flag.
  final ValueNotifier<bool> _twoFactorLoading = ValueNotifier<bool>(false);

  // -- Lifecycle -------------------------------------------------------------

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
    if (controller.isTwoFactorEnabled) {
      _twoFactorState = 'enabled';
    }
  }

  @override
  void onClose() {
    _twoFactorLoading.dispose();
  }

  // -- 2FA actions -----------------------------------------------------------

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

  /// Enable 2FA flow with password confirmation and setup modal.
  Future<void> _enableTwoFactor(BuildContext context) async {
    Map<String, dynamic>? setupData;

    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    await MagicStarterPasswordConfirmDialog.show(
      context,
      onConfirm: (password) async {
        final data = await _trackLoading(
          _twoFactorLoading,
          () => controller.doEnableTwoFactor(password: password),
        );
        if (data == null) {
          final error =
              controller.rxStatus.message ?? trans('common.error_occurred');
          controller.clearErrors();
          return error;
        }
        setupData = data;
        return null; // success → dialog closes
      },
    );

    if (setupData == null) return; // user cancelled or all attempts failed

    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    final confirmed = await MagicStarterTwoFactorModal.show(
      context,
      setupData: setupData!,
      onConfirm: (code) => controller.doConfirmTwoFactor(code: code),
    );

    if (confirmed) {
      setState(() => _twoFactorState = 'enabled');
    }
  }

  /// Disable 2FA --- requires password confirmation.
  Future<void> _disableTwoFactor(BuildContext context) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    final success = await MagicStarterPasswordConfirmDialog.show(
      context,
      variant: ConfirmDialogVariant.warning,
      onConfirm: (password) async {
        final ok = await _trackLoading(
          _twoFactorLoading,
          () => controller.doDisableTwoFactor(password: password),
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
      setState(() {
        _twoFactorState = 'disabled';
        _recoveryCodes = [];
      });
    }
  }

  /// Show current recovery codes from server.
  Future<void> _showRecoveryCodes(BuildContext context) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;
    await MagicStarterPasswordConfirmDialog.show(
      context,
      onConfirm: (password) async {
        final codes = await _trackLoading(
          _twoFactorLoading,
          () => controller.getRecoveryCodes(password: password),
        );
        if (codes == null) {
          final error =
              controller.rxStatus.message ?? trans('common.error_occurred');
          controller.clearErrors();
          return error;
        }
        setState(() => _recoveryCodes = codes);
        return null;
      },
    );
  }

  /// Regenerate recovery codes on the server.
  Future<void> _regenerateRecoveryCodes(BuildContext context) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;
    await MagicStarterPasswordConfirmDialog.show(
      context,
      variant: ConfirmDialogVariant.warning,
      onConfirm: (password) async {
        final codes = await _trackLoading(
          _twoFactorLoading,
          () => controller.doRegenerateRecoveryCodes(password: password),
        );
        if (codes == null) {
          final error =
              controller.rxStatus.message ?? trans('common.error_occurred');
          controller.clearErrors();
          return error;
        }
        setState(() => _recoveryCodes = codes);
        return null;
      },
    );
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MSPageScaffold(
      title: trans('profile.two_factor_authentication'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        MSSettingsSection(
          children: [
            WDiv(
              className: 'flex flex-col gap-4 px-5 py-4',
              children: [
                if (_twoFactorState == 'disabled') _buildTwoFactorDisabled(),
                if (_twoFactorState == 'enabled') _buildTwoFactorEnabled(),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Disabled state: description + Enable button.
  Widget _buildTwoFactorDisabled() {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        WText(
          trans('profile.two_factor_disabled_description'),
          className: 'text-sm text-fg-muted',
        ),
        MagicBuilder<bool>(
          listenable: _twoFactorLoading,
          builder: (isLoading) => Builder(
            builder: (context) => WButton(
              onTap: isLoading ? null : () => _enableTwoFactor(context),
              isLoading: isLoading,
              className:
                  'self-start px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
              child: WText(trans('profile.two_factor_enable')),
            ),
          ),
        ),
      ],
    );
  }

  /// Enabled state: green status badge, recovery codes, management buttons.
  Widget _buildTwoFactorEnabled() {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WDiv(
              className: 'w-3 h-3 rounded-full bg-green-500 dark:bg-green-400',
            ),
            WText(
              trans('profile.two_factor_enabled'),
              className:
                  'text-sm font-medium text-green-700 dark:text-green-400',
            ),
          ],
        ),
        WText(
          trans('profile.two_factor_enabled_description'),
          className: 'text-sm text-fg-muted',
        ),
        if (_recoveryCodes.isNotEmpty) ...[
          WText(
            trans('profile.two_factor_recovery_codes_description'),
            className: 'text-sm font-medium text-fg',
          ),
          WDiv(
            className: 'wrap gap-2',
            children: [
              ..._recoveryCodes.map(
                (code) => WDiv(
                  className:
                      'font-mono text-sm bg-surface-container-high text-fg px-2 py-1 rounded',
                  child: WText(code),
                ),
              ),
              WDiv(
                className: 'w-full mt-2 flex flex-row gap-2 wrap',
                children: [
                  WButton(
                    onTap: () async {
                      final codes = _recoveryCodes.join('\n');
                      await Clipboard.setData(ClipboardData(text: codes));
                    },
                    className:
                        'text-primary dark:text-primary border border-primary/30 dark:border-primary/30 hover:bg-primary/5 dark:hover:bg-primary/10 rounded-lg px-4 py-2 text-sm font-medium',
                    child: WText(
                      trans('profile.copy_recovery_codes'),
                      className: 'text-center',
                    ),
                  ),
                  MagicBuilder<bool>(
                    listenable: _twoFactorLoading,
                    builder: (isLoading) => Builder(
                      builder: (context) => WButton(
                        onTap: isLoading
                            ? null
                            : () => _regenerateRecoveryCodes(context),
                        isLoading: isLoading,
                        className:
                            'px-4 py-2 rounded-lg bg-surface-container border border-color-border hover:bg-surface-container-high text-fg text-sm font-medium',
                        child: WText(
                          trans('profile.two_factor_regenerate_codes'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
        MagicBuilder<bool>(
          listenable: _twoFactorLoading,
          builder: (isLoading) => WDiv(
            className: 'wrap gap-3',
            children: [
              Builder(
                builder: (context) => WButton(
                  onTap: isLoading ? null : () => _showRecoveryCodes(context),
                  isLoading: isLoading,
                  className:
                      'px-4 py-2 rounded-lg bg-surface-container border border-color-border hover:bg-surface-container-high text-fg text-sm font-medium',
                  child: WText(trans('profile.two_factor_show_recovery_codes')),
                ),
              ),
              Builder(
                builder: (context) => WButton(
                  onTap: isLoading ? null : () => _disableTwoFactor(context),
                  isLoading: isLoading,
                  className:
                      'text-destructive border border-color-border hover:bg-surface-container rounded-lg px-4 py-2 text-sm font-medium',
                  child: WText(trans('profile.two_factor_disable')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
