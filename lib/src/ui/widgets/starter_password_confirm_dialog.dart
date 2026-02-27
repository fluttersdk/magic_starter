import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// A reusable dialog widget that prompts the user to confirm their password.
///
/// This dialog maintains its own standalone state for the password input and visibility
/// toggle. It uses Wind UI exclusively for styling and layout.
///
/// Returns the entered password as a [String] if confirmed, or `null` if cancelled.
class MagicStarterPasswordConfirmDialog extends StatefulWidget {
  /// Optional custom title for the dialog.
  /// Defaults to `trans('profile.confirm_password')`.
  final String? title;

  /// Optional custom description for the dialog.
  /// Defaults to `trans('profile.confirm_password_description')`.
  final String? description;

  const MagicStarterPasswordConfirmDialog({
    super.key,
    this.title,
    this.description,
  });

  /// Helper method to display the password confirmation dialog.
  ///
  /// Returns a `Future<String?>` which resolves to the entered password
  /// on confirmation, or `null` on cancellation.
  static Future<String?> show(BuildContext context,
      {String? title, String? description}) {
    return showDialog<String?>(
      context: context,
      builder: (_) => MagicStarterPasswordConfirmDialog(
        title: title,
        description: description,
      ),
    );
  }

  @override
  State<MagicStarterPasswordConfirmDialog> createState() =>
      _MagicStarterPasswordConfirmDialogState();
}

class _MagicStarterPasswordConfirmDialogState
    extends State<MagicStarterPasswordConfirmDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    // Basic validation could happen here before closing
    final password = _passwordController.text;
    if (password.isEmpty) {
      return;
    }
    Navigator.of(context).pop(password);
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: WDiv(
        className:
            'bg-white dark:bg-gray-800 rounded-2xl flex flex-col w-full max-w-md overflow-hidden',
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
            className: 'px-6 pb-6',
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

          // Footer
          WDiv(
            className:
                'px-6 py-4 bg-gray-50 dark:bg-gray-800/50 flex flex-row justify-end gap-3',
            children: [
              WAnchor(
                onTap: _onCancel,
                child: WDiv(
                  className: 'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium',
                  child: WText(trans('common.cancel')),
                ),
              ),
              WButton(
                onTap: _onConfirm,
                className:
                    'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
                child: WText(trans('common.confirm')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
