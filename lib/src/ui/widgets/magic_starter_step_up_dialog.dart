import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../contracts/magic_starter_social_auth.dart';
import '../../facades/magic_starter.dart';
import '../../support/social_failure_message.dart';
import '../components/button/index.dart';
import '../components/confirm_dialog/confirm_dialog.dart';
import '../components/dialog/dialog.dart';

/// Asks an account with no password to prove who is calling.
///
/// The backend takes a TOTP `code` when two-factor is confirmed, or a
/// `confirmation_token` minted by re-authenticating with a linked provider.
/// This dialog offers what the signed-in user can send: a code field for a
/// 2FA account, and one "Confirm with <provider>" row per active linked
/// account (one with no `revoked_at`) that the social login bridge offers.
/// With neither it shows only the `social.step_up_required` sentence.
///
/// A proof is minted per attempt and never kept: [onProof] receives each one,
/// and a provider row asks the bridge again on every tap, since a
/// confirmation token is single use.
///
/// Returns the proof (`{code}` or `{confirmation_token}`) or `null` when the
/// user cancels.
class MagicStarterStepUpDialog extends StatefulWidget {
  /// Optional custom title. Defaults to `trans('social.confirm_identity')`.
  final String? title;

  /// Optional custom description. Defaults to
  /// `trans('social.step_up_required')`.
  final String? description;

  /// The proofs the server takes, narrowing what the user's own data offers.
  ///
  /// `null` leaves the dialog to the user's data; a list (the `accepts` of a
  /// `step_up_required` refusal) limits it to those proofs, and a later value
  /// takes effect while the dialog is open.
  final ValueListenable<List<String>?>? accepts;

  /// Called with each proof the user produces. Return null on success (the
  /// dialog closes with that proof) or an error string to show inline and
  /// stay open. Without it the first proof closes the dialog.
  final Future<String?> Function(Map<String, String> proof)? onProof;

  /// Visual variant that controls the confirm button colour.
  final ConfirmDialogVariant variant;

  const MagicStarterStepUpDialog({
    super.key,
    this.title,
    this.description,
    this.accepts,
    this.onProof,
    this.variant = ConfirmDialogVariant.primary,
  });

  /// Shows the dialog and resolves to the proof, or `null` on cancel.
  static Future<Map<String, String>?> show(
    BuildContext context, {
    String? title,
    String? description,
    ValueListenable<List<String>?>? accepts,
    Future<String?> Function(Map<String, String> proof)? onProof,
    ConfirmDialogVariant variant = ConfirmDialogVariant.primary,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MagicStarterStepUpDialog(
        title: title,
        description: description,
        accepts: accepts,
        onProof: onProof,
        variant: variant,
      ),
    );
  }

  @override
  State<MagicStarterStepUpDialog> createState() =>
      _MagicStarterStepUpDialogState();
}

class _MagicStarterStepUpDialogState extends State<MagicStarterStepUpDialog> {
  static const _codeProof = 'code';
  static const _tokenProof = 'confirmation_token';

  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  /// Whether the user is still inside a provider's own flow. Cancel stays
  /// available then: on the web a closed popup only fails after a long
  /// timeout, and a dialog that cannot be dismissed meanwhile is stuck.
  bool _awaitingProvider = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Whether the user can answer with a code: the server's word when it has
  /// spoken, else whether the user has two-factor on.
  bool _offersCode(List<String>? accepts) {
    if (accepts != null) return accepts.contains(_codeProof);

    return Auth.user()?.get<bool>('two_factor_enabled') ?? false;
  }

  /// The linked providers the user can re-authenticate with here: active
  /// links the bridge offers, in the bridge's display order.
  List<String> _offeredProviders(List<String>? accepts) {
    final bridge = MagicStarter.socialAuth;
    if (bridge == null) return const [];
    if (accepts != null && !accepts.contains(_tokenProof)) return const [];

    final linked = <String>{
      for (final account
          in Auth.user()?.get<List<dynamic>>('social_accounts') ?? const [])
        if ((account as Map<String, dynamic>)['revoked_at'] == null)
          account['provider'] as String,
    };

    return [
      for (final provider in bridge.providers())
        if (linked.contains(provider)) provider,
    ];
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _conclude({_codeProof: code});
  }

  /// Re-authenticates with [provider] and submits the token it yields.
  Future<void> _confirmWith(String provider) async {
    if (_isLoading) return;

    // 1. Ask the bridge before anything is awaited: on the web the provider
    //    popup only opens inside the user's tap.
    final pending = MagicStarter.socialAuth!.confirm(provider);

    setState(() {
      _isLoading = true;
      _awaitingProvider = true;
      _errorMessage = null;
    });

    // 2. A cancelled flow shows nothing; any other failure is shown inline.
    //    A result that lands after the dialog closed has no one to tell.
    final String token;
    try {
      token = await pending;
    } on MagicStarterSocialException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _awaitingProvider = false;
        _errorMessage = e.cancelled ? null : socialFailureMessage(e);
      });
      return;
    } catch (e, stackTrace) {
      Log.error('[MagicStarterStepUpDialog._confirmWith] $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _awaitingProvider = false;
        _errorMessage = trans('errors.unexpected');
      });
      return;
    }

    if (!mounted) return;
    setState(() => _awaitingProvider = false);
    await _conclude({_tokenProof: token});
  }

  /// Hands [proof] to [MagicStarterStepUpDialog.onProof] and closes on
  /// success, or shows the refusal and stays open for a fresh proof.
  Future<void> _conclude(Map<String, String> proof) async {
    final error = await widget.onProof?.call(proof);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }

    Navigator.of(context).pop(proof);
  }

  /// Whether Cancel works: not while a request is in flight, but yes while
  /// only a provider's flow is.
  bool get _canCancel => !_isLoading || _awaitingProvider;

  void _onCancel() {
    if (!_canCancel) return;
    Navigator.of(context).pop();
  }

  String _resolveConfirmClassName() {
    final theme = MagicStarter.manager.modalTheme;

    return switch (widget.variant) {
      ConfirmDialogVariant.primary => theme.primaryButtonClassName,
      ConfirmDialogVariant.danger => theme.dangerButtonClassName,
      ConfirmDialogVariant.warning => theme.warningButtonClassName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accepts = widget.accepts;
    if (accepts == null) return _buildDialog(null);

    return ValueListenableBuilder<List<String>?>(
      valueListenable: accepts,
      builder: (context, narrowed, _) => _buildDialog(narrowed),
    );
  }

  Widget _buildDialog(List<String>? accepts) {
    final theme = MagicStarter.manager.modalTheme;
    final offersCode = _offersCode(accepts);
    final providers = _offeredProviders(accepts);
    final offersNothing = !offersCode && providers.isEmpty;

    return MSDialog(
      title: widget.title ?? trans('social.confirm_identity'),
      description: widget.description ?? trans('social.step_up_required'),
      body: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          // A custom description hides the sentence that explains an empty
          // dialog, so it is repeated here.
          if (offersNothing && widget.description != null)
            WText(
              trans('social.step_up_required'),
              className: theme.descriptionClassName,
            ),
          if (offersCode)
            WFormInput(
              controller: _codeController,
              label: trans('profile.two_factor_code_label'),
              placeholder: trans('profile.two_factor_code_placeholder'),
              type: InputType.number,
              labelClassName: 'text-sm font-medium text-fg mb-1',
              className: '${theme.inputClassName} error:border-red-500',
            ),
          if (providers.isNotEmpty)
            WDiv(
              className: 'flex flex-col items-stretch gap-3',
              children: [
                for (final provider in providers) _buildProviderRow(provider),
              ],
            ),
          if (_errorMessage != null)
            WText(_errorMessage!, className: theme.errorClassName),
        ],
      ),
      footerBuilder: (_) => WDiv(
        className: 'flex flex-row w-full justify-end gap-2 wrap',
        children: [
          WAnchor(
            onTap: _canCancel ? _onCancel : null,
            child: WDiv(
              className: theme.secondaryButtonClassName,
              child: WText(trans('common.cancel')),
            ),
          ),
          if (offersCode)
            WButton(
              onTap: _isLoading ? null : _submitCode,
              isLoading: _isLoading,
              className: _resolveConfirmClassName(),
              child: WText(trans('common.confirm')),
            ),
        ],
      ),
    );
  }

  Widget _buildProviderRow(String provider) {
    final bridge = MagicStarter.socialAuth!;

    return MSButton(
      onPressed: _isLoading ? null : () => _confirmWith(provider),
      className: MagicStarter.formTheme.secondaryButtonClassName,
      child: WDiv(
        className: 'flex flex-row items-center justify-center gap-2',
        children: [
          bridge.icon(provider),
          WText(
            trans('social.confirm_with', {'provider': bridge.label(provider)}),
          ),
        ],
      ),
    );
  }
}
