import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// A reusable dialog widget that prompts the user to confirm their password.
///
/// This dialog maintains its own standalone state for the password input,
/// visibility toggle, and async confirm flow. It shows a loading spinner during
/// the API call and displays inline errors without closing.
///
/// The [onConfirm] callback receives the entered password and should return:
/// - `null` on success (dialog closes automatically)
/// - An error string on failure (error displayed inline, dialog remains open)
///
/// Uses Wind UI exclusively for styling and layout.
///
/// Returns `true` if confirmed, `false` if cancelled.
class MagicStarterPasswordConfirmDialog extends StatefulWidget {
  /// Optional custom title for the dialog.
  /// Defaults to `trans('profile.confirm_password')`.
  final String? title;

  /// Optional custom description for the dialog.
  /// Defaults to `trans('profile.confirm_password_description')`.
  final String? description;

  /// Called with the entered password. Return null on success, error string on
  /// failure.
  final Future<String?> Function(String password)? onConfirm;

  const MagicStarterPasswordConfirmDialog({
    super.key,
    this.title,
    this.description,
    this.onConfirm,
  });

  /// Helper method to display the password confirmation dialog.
  ///
  /// Returns a `Future<bool>` which resolves to `true` if confirmed
  /// (password validated via [onConfirm]), or `false` if cancelled.
  ///
  /// The dialog stays open during loading and displays API errors inline.
  static Future<bool> show(
    BuildContext context, {
    String? title,
    String? description,
    Future<String?> Function(String password)? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MagicStarterPasswordConfirmDialog(
        title: title,
        description: description,
        onConfirm: onConfirm,
      ),
    ).then((v) => v ?? false);
  }

  @override
  State<MagicStarterPasswordConfirmDialog> createState() =>
      _MagicStarterPasswordConfirmDialogState();
}

class _MagicStarterPasswordConfirmDialogState
    extends State<MagicStarterPasswordConfirmDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await widget.onConfirm?.call(password);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _onCancel() {
    if (_isLoading) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 448,
          maxHeight: 600,
        ),
        child: SingleChildScrollView(
          child: WDiv(
            className:
                'bg-white dark:bg-gray-800 rounded-2xl flex flex-col w-full overflow-hidden',
            children: [
              // Header
              WDiv(
                className: 'px-6 pt-6 pb-4',
                children: [
                  WText(
                    widget.title ?? trans('profile.confirm_password'),
                    className:
                        'text-xl font-semibold text-gray-900 dark:text-white mb-2',
                  ),
                  WText(
                    widget.description ??
                        trans('profile.confirm_password_description'),
                    className: 'text-sm text-gray-600 dark:text-gray-400',
                  ),
                ],
              ),

              // Body
              WDiv(
                className: 'px-6 pb-4',
                children: [
                  WFormInput(
                    controller: _passwordController,
                    type: _obscure ? InputType.password : InputType.text,
                    suffix: WAnchor(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: WIcon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        className: 'text-gray-400 text-xl',
                      ),
                    ),
                    className:
                        'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
                  ),
                ],
              ),

              // Inline error message (from async onConfirm)
              if (_errorMessage != null)
                WDiv(
                  className: 'px-6 pb-4',
                  child: WText(
                    _errorMessage!,
                    className: 'text-sm text-red-600 dark:text-red-400',
                  ),
                ),

              // Footer
              WDiv(
                className:
                    'px-6 py-4 bg-gray-50 dark:bg-gray-800/50 flex flex-row gap-2 w-full',
                children: [
                  WDiv(
                    className: 'flex-1',
                    child: WAnchor(
                      onTap: _isLoading ? null : _onCancel,
                      child: WDiv(
                        className:
                            'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium text-center',
                        child: WText(trans('common.cancel')),
                      ),
                    ),
                  ),
                  WDiv(
                    className: 'flex-1',
                    child: WButton(
                      onTap: _isLoading ? null : _onConfirm,
                      isLoading: _isLoading,
                      className:
                          'w-full px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium text-center',
                      child: WText(trans('common.confirm')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
