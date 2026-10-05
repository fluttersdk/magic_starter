import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../http/controllers/magic_starter_profile_controller.dart';
import '../ui/components/confirm_dialog/confirm_dialog.dart';
import '../ui/widgets/magic_starter_password_confirm_dialog.dart';
import '../ui/widgets/magic_starter_step_up_dialog.dart';

/// Asks the signed-in user to prove who is calling, with the proof the
/// backend accepts for that account, and answers it as request fields.
///
/// - An account with a password is asked for it: `{password}`.
/// - A guest (`is_guest`, no password) passes with no dialog: `{}`.
/// - Any other password-less account gets [MagicStarterStepUpDialog]: a
///   `{code}` when two-factor is on, or a `{confirmation_token}` from
///   re-authenticating with a linked provider.
///
/// Answers `null` when the user cancels. The proof is minted per call and
/// never kept; a retry asks again, because a confirmation token is single
/// use.
///
/// With [attempt], each proof the user gives is handed to it before the
/// dialog closes: a returned error string is shown inline and the dialog
/// stays open for the next, fresh proof; `null` accepts it. A guest has no
/// dialog to show an error in, so a refusal there is a toast. [accepts]
/// narrows the step-up dialog to the proofs the server takes.
Future<Map<String, String>?> confirmIdentity(
  BuildContext context, {
  ConfirmDialogVariant variant = ConfirmDialogVariant.primary,
  String? title,
  String? description,
  ValueListenable<List<String>?>? accepts,
  Future<String?> Function(Map<String, String> proof)? attempt,
}) async {
  final user = Auth.user();
  final hasPassword = user?.get<bool>('has_password') ?? true;

  // 1. A guest has nothing to confirm with, and the backend lets it through.
  if (!hasPassword && user?.get<bool>('is_guest') == true) {
    final error = await attempt?.call(const <String, String>{});
    if (error == null) return const <String, String>{};

    Magic.toast(error);
    return null;
  }

  // 2. Otherwise the proof is a dialog away.
  if (!context.mounted) return null;

  if (!hasPassword) {
    return MagicStarterStepUpDialog.show(
      context,
      title: title,
      description: description,
      accepts: accepts,
      onProof: attempt,
      variant: variant,
    );
  }

  Map<String, String>? proof;
  final confirmed = await MagicStarterPasswordConfirmDialog.show(
    context,
    title: title,
    description: description,
    variant: variant,
    onConfirm: (password) async {
      final candidate = {'password': password};
      final error = await attempt?.call(candidate);
      if (error != null) return error;

      proof = candidate;
      return null;
    },
  );

  return confirmed ? proof : null;
}

/// Confirms identity, then runs a gated [action] with the proof, inside the
/// confirmation dialog.
///
/// The dialog stays open while the server refuses the proof itself, so the
/// user can retry with a fresh one: the refusal is read off [controller] and
/// shown inline, and a `step_up_required` refusal narrows the step-up dialog
/// to the proofs the server takes ([MagicStarterProfileController.stepUpAccepts]).
/// Any other refusal (a 422 on the new password, `password_already_set`,
/// `owns_shared_teams`, `subscription_active`) is not something a new proof
/// fixes: the dialog closes, the controller's error is kept, and a refusal
/// with no field errors to show is announced with a toast.
///
/// [action] calls a gated controller method with the proof and answers
/// whether it succeeded; it keeps whatever the call returned. Resolves to
/// `true` when the action succeeded, `false` when the user cancelled or the
/// action was refused for a reason other than the proof.
Future<bool> confirmAndRun(
  BuildContext context,
  MagicStarterProfileController controller, {
  required Future<bool> Function(Map<String, String> proof) action,
  ConfirmDialogVariant variant = ConfirmDialogVariant.primary,
  String? title,
  String? description,
}) async {
  final accepts = ValueNotifier<List<String>?>(null);
  var succeeded = false;

  try {
    await confirmIdentity(
      context,
      variant: variant,
      title: title,
      description: description,
      accepts: accepts,
      attempt: (proof) async {
        succeeded = await action(proof);
        if (succeeded) return null;

        // 1. A refusal of the proof itself: a step-up one, or a field error
        //    keyed by a field this proof sent (`password`, `code`,
        //    `confirmation_token`). The key alone is not enough: a 422 on a
        //    new `password` is the form's, not the proof's.
        final proofRefused =
            controller.stepUpAccepts != null ||
            proof.keys.any(controller.hasError);
        if (!proofRefused) {
          // Nothing on the pages that call this renders the controller's
          // error, so a refusal without field errors would pass unseen.
          final message = controller.rxStatus.message;
          if (message != null && controller.validationErrors.isEmpty) {
            Magic.toast(message);
          }

          return null;
        }

        // 2. Read before clearing: clearing the errors clears the refusal.
        accepts.value = controller.stepUpAccepts ?? accepts.value;
        final message =
            controller.rxStatus.message ?? trans('common.error_occurred');
        controller.clearErrors();

        return message;
      },
    );

    return succeeded;
  } finally {
    accepts.dispose();
  }
}
