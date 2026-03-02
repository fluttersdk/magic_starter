import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_svg/flutter_svg.dart';
import 'package:magic/magic.dart';

/// A multi-step wizard modal widget for Two-Factor Authentication (2FA) setup.
///
/// Handles displaying the QR code, confirming the initial OTP, and subsequently
/// displaying the generated recovery codes.
class MagicStarterTwoFactorModal extends StatefulWidget {
  /// The setup data provided by the backend (contains secret, qr_svg, and recovery_codes).
  final Map<String, dynamic> setupData;

  /// Callback invoked when the user submits an OTP to confirm setup.
  ///
  /// Must return `true` if the code was valid and setup succeeded, `false` otherwise.
  final Future<bool> Function(String code) onConfirm;

  const MagicStarterTwoFactorModal({
    super.key,
    required this.setupData,
    required this.onConfirm,
  });

  /// Helper method to display the 2FA setup modal.
  ///
  /// Returns a `Future<bool>` which resolves to `true` if the wizard was
  /// completed successfully, or `false`/`null` if cancelled.
  static Future<bool> show(
    BuildContext context, {
    required Map<String, dynamic> setupData,
    required Future<bool> Function(String code) onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => MagicStarterTwoFactorModal(
        setupData: setupData,
        onConfirm: onConfirm,
      ),
    ).then((value) => value ?? false);
  }

  @override
  State<MagicStarterTwoFactorModal> createState() =>
      _MagicStarterTwoFactorModalState();
}

class _MagicStarterTwoFactorModalState
    extends State<MagicStarterTwoFactorModal> {
  final TextEditingController _otpController = TextEditingController();

  int _currentStep = 0; // 0 = setup, 1 = recovery codes
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  /// 1. Submits the entered OTP to the caller via [onConfirm].
  /// 2. If successful, advances to the recovery codes step.
  /// 3. If unsuccessful, displays an error message.
  Future<void> _handleConfirm() async {
    if (_isLoading) return;

    final code = _otpController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onConfirm(code);

      if (mounted) {
        if (success) {
          setState(() {
            _currentStep = 1;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = trans('profile.two_factor.invalid_code');
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Log.error('[MagicStarterTwoFactorModal] Setup failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = trans('common.error_occurred');
          _isLoading = false;
        });
      }
    }
  }

  void _handleCancel() {
    Navigator.of(context).pop(false);
  }

  void _handleDone() {
    Navigator.of(context).pop(true);
  }

  Widget _buildSetupStep() {
    final qrSvg = widget.setupData['qr_svg'] as String?;
    final secret = widget.setupData['secret'] as String?;

    return WDiv(
      className: 'flex flex-col gap-5 px-6 pb-6',
      children: [
        WText(
          trans('profile.two_factor_setup_description'),
          className: 'text-sm text-gray-600 dark:text-gray-400',
        ),
        if (qrSvg != null && qrSvg.isNotEmpty)
          WDiv(
            className: 'flex justify-center',
            child: WDiv(
              className:
                  'p-3 bg-white dark:bg-white rounded-xl border border-gray-200 dark:border-gray-200',
              child: SvgPicture.string(
                qrSvg,
                width: 192,
                height: 192,
              ),
            ),
          ),
        if (secret != null) ...[
          WText(
            trans('profile.two_factor_manual_entry'),
            className: 'text-sm font-medium text-gray-700 dark:text-gray-300',
          ),
          WDiv(
            className: 'bg-gray-100 dark:bg-gray-700 rounded-lg px-4 py-3',
            child: WText(
              secret,
              className: 'font-mono text-sm text-gray-800 dark:text-gray-200',
            ),
          ),
        ],
        WFormInput(
          controller: _otpController,
          label: trans('profile.two_factor_code_label'),
          placeholder: trans('profile.two_factor_code_placeholder'),
          type: InputType.number,
          labelClassName:
              'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
          className:
              'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary',
        ),
        if (_errorMessage != null)
          WText(
            _errorMessage!,
            className: 'text-red-500 dark:text-red-400 text-sm',
          ),
        WDiv(
          className: 'flex flex-row justify-end gap-2 wrap mt-2',
          children: [
            WAnchor(
              onTap: _handleCancel,
              child: WDiv(
                className:
                    'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium',
                child: WText(trans('common.cancel')),
              ),
            ),
            WButton(
              onTap: _isLoading ? null : _handleConfirm,
              isLoading: _isLoading,
              className:
                  'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
              child: WText(trans('common.confirm')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecoveryStep() {
    final recoveryCodes = (widget.setupData['recovery_codes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return WDiv(
      className: 'flex flex-col gap-5 px-6 pb-6',
      children: [
        WText(
          trans('profile.two_factor_recovery_codes_description'),
          className: 'text-sm text-gray-600 dark:text-gray-400',
        ),
        WDiv(
          className: 'wrap gap-2',
          children: [
            ...recoveryCodes.map(
              (code) => WDiv(
                className:
                    'font-mono text-sm bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200 px-2 py-1 rounded',
                child: WText(code),
              ),
            ),
            WDiv(
              className: 'w-full mt-2',
              children: [
                WButton(
                  onTap: () async {
                    final codes = recoveryCodes.join('\n');
                    await Clipboard.setData(ClipboardData(text: codes));
                    Magic.toast(trans('profile.copy_recovery_codes_success'));
                  },
                  className:
                      'w-full flex justify-center text-primary dark:text-primary border border-primary/30 dark:border-primary/30 hover:bg-primary/5 dark:hover:bg-primary/10 rounded-lg px-4 py-2 text-sm font-medium',
                  child: WText(
                    trans('profile.two_factor.copy_codes'),
                    className: 'text-center',
                  ),
                ),
              ],
            ),
          ],
        ),
        WDiv(
          className: 'flex flex-row justify-end gap-2 wrap mt-2',
          children: [
            WButton(
              onTap: _handleDone,
              className:
                  'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
              child: WText(trans('common.done')),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 448,
          maxHeight: 800,
        ),
        child: SingleChildScrollView(
          child: WDiv(
            className:
                'bg-white dark:bg-gray-800 rounded-2xl flex flex-col w-full overflow-hidden',
            children: [
              WDiv(
                className: 'px-6 pt-6 pb-4',
                children: [
                  WText(
                    trans('profile.two_factor_auth'),
                    className:
                        'text-xl font-semibold text-gray-900 dark:text-white mb-2',
                  ),
                ],
              ),
              _currentStep == 0 ? _buildSetupStep() : _buildRecoveryStep(),
            ],
          ),
        ),
      ),
    );
  }
}
