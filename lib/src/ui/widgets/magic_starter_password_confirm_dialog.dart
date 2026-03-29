import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

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
    final theme = MagicStarter.manager.modalTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: theme.maxWidth,
          maxHeight: 600,
        ),
        child: SingleChildScrollView(
          child: WDiv(
            className:
                '${theme.containerClassName} flex flex-col w-full overflow-hidden',
            children: [
              // Header
              WDiv(
                className: theme.headerClassName,
                children: [
                  WText(
                    widget.title ?? trans('profile.confirm_password'),
                    className: theme.titleClassName,
                  ),
                  WText(
                    widget.description ??
                        trans('profile.confirm_password_description'),
                    className: theme.descriptionClassName,
                  ),
                ],
              ),

              // Body
              WDiv(
                className: theme.bodyClassName,
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
                    className: '${theme.inputClassName} error:border-red-500',
                  ),
                ],
              ),

              // Inline error message (from async onConfirm)
              if (_errorMessage != null)
                WDiv(
                  className: theme.bodyClassName,
                  child: WText(
                    _errorMessage!,
                    className: theme.errorClassName,
                  ),
                ),

              // Footer
              WDiv(
                className:
                    '${theme.footerClassName} flex flex-row justify-end gap-2 wrap',
                children: [
                  WAnchor(
                    onTap: _isLoading ? null : _onCancel,
                    child: WDiv(
                      className: theme.secondaryButtonClassName,
                      child: WText(trans('common.cancel')),
                    ),
                  ),
                  WButton(
                    onTap: _isLoading ? null : _onConfirm,
                    isLoading: _isLoading,
                    className: theme.primaryButtonClassName,
                    child: WText(trans('common.confirm')),
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
