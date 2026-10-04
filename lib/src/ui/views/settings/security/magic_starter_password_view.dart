import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../facades/magic_starter.dart';
import '../../../../http/controllers/magic_starter_profile_controller.dart';
import '../../../../support/confirms_identity.dart';
import '../../../components/page_scaffold/page_scaffold.dart';
import '../../../components/settings_section/settings_section.dart';

/// Password update settings sub-page.
///
/// Drilled into from the Settings hub. Wraps the current/new/confirm password
/// form in a [MSPageScaffold] with a unified back affordance returning to
/// the hub.
///
/// An account created through a provider has no password to change, so
/// `has_password` false renders new/confirm only and sets the first one
/// through [MagicStarterProfileController.doSetPassword], after the account
/// confirms its identity. The page reads the user on every build, so a
/// `password_already_set` or `password_not_set` refusal (the cached user was
/// stale) shows the other form once the controller has restored it.
class MagicStarterPasswordView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterPasswordView({super.key});

  @override
  State<MagicStarterPasswordView> createState() =>
      _MagicStarterPasswordViewState();
}

class _MagicStarterPasswordViewState
    extends
        MagicStatefulViewState<
          MagicStarterProfileController,
          MagicStarterPasswordView
        > {
  static const _iconVisible = Icons.visibility;
  static const _iconHidden = Icons.visibility_off;

  late final passwordForm = MagicFormData({
    'current_password': '',
    'password': '',
    'password_confirmation': '',
  }, controller: controller);

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirmation = true;

  // -- Lifecycle -------------------------------------------------------------

  @override
  void onInit() {
    controller.resetQuietly();
  }

  @override
  void onClose() {
    passwordForm.dispose();
  }

  // -- Actions ---------------------------------------------------------------

  /// Triggers a rebuild when [controller.withoutNotifying] suppresses the
  /// [notifyListeners] call inside [handleApiError] / [setErrorsFromResponse].
  void _rebuildIfValidationErrors() {
    if (controller.hasErrors) {
      setState(() {});
      passwordForm.formKey.currentState?.validate();
    }
  }

  /// Whether the signed-in account has a password to change. Absent on a
  /// backend that predates social login, where every account has one.
  bool get _hasPassword => Auth.user()?.get<bool>('has_password') ?? true;

  Future<void> _submitPassword() async {
    if (!passwordForm.validate()) return;
    final success = await passwordForm.process(
      () => controller.withoutNotifying(
        () => controller.doUpdatePassword(
          currentPassword: passwordForm.get('current_password'),
          password: passwordForm.get('password'),
          passwordConfirmation: passwordForm.get('password_confirmation'),
        ),
      ),
    );
    _rebuildIfValidationErrors();
    if (success) {
      _clearPasswordFields();
    }

    // A `password_not_set` refusal restores the user; rebuild so the page
    // shows the set-password form when the account turned out to have none.
    if (mounted) setState(() {});
  }

  Future<void> _submitSetPassword() async {
    if (!passwordForm.validate()) return;

    // The form only spins while a request is in flight, not while the
    // confirmation dialog waits for the user.
    final success = await confirmAndRun(
      context,
      controller,
      title: trans('profile.set_password'),
      action: (proof) => passwordForm.process(
        () => controller.withoutNotifying(
          () => controller.doSetPassword(
            password: passwordForm.get('password'),
            passwordConfirmation: passwordForm.get('password_confirmation'),
            proof: proof,
          ),
        ),
      ),
    );

    if (!mounted) return;

    // The controller restored the user on success and on a stale-mode
    // refusal; rebuilding reads it and shows the form that now applies.
    setState(() {});
    if (success) {
      _clearPasswordFields();
    }
  }

  void _clearPasswordFields() {
    passwordForm.set('current_password', '');
    passwordForm.set('password', '');
    passwordForm.set('password_confirmation', '');
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final formTheme = MagicStarter.formTheme;
    final hasPassword = _hasPassword;

    return MSPageScaffold(
      title: trans(
        hasPassword ? 'profile.update_password' : 'profile.set_password',
      ),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        MagicForm(
          formData: passwordForm,
          child: WDiv(
            className: 'flex flex-col gap-6',
            children: [
              MSSettingsSection(
                footer: hasPassword
                    ? null
                    : trans('profile.set_password_description'),
                children: [
                  WDiv(
                    className: 'flex flex-col gap-4 px-5 py-4',
                    children: [
                      if (hasPassword)
                        WFormInput(
                          controller: passwordForm['current_password'],
                          label: trans('attributes.current_password'),
                          type: _obscureCurrent
                              ? InputType.password
                              : InputType.text,
                          validator: rules([
                            Required(),
                          ], field: 'current_password'),
                          suffix: WAnchor(
                            onTap: () => setState(
                              () => _obscureCurrent = !_obscureCurrent,
                            ),
                            child: WIcon(
                              _obscureCurrent ? _iconVisible : _iconHidden,
                              className: 'text-fg-muted text-xl',
                            ),
                          ),
                          labelClassName: formTheme.labelClassName,
                          className: formTheme.inputClassName,
                        ),
                      WFormInput(
                        controller: passwordForm['password'],
                        label: trans('attributes.new_password'),
                        type: _obscureNew ? InputType.password : InputType.text,
                        validator: rules([
                          Required(),
                          Min(8),
                        ], field: 'password'),
                        suffix: WAnchor(
                          onTap: () =>
                              setState(() => _obscureNew = !_obscureNew),
                          child: WIcon(
                            _obscureNew ? _iconVisible : _iconHidden,
                            className: 'text-fg-muted text-xl',
                          ),
                        ),
                        labelClassName: formTheme.labelClassName,
                        className: formTheme.inputClassName,
                      ),
                      WFormInput(
                        controller: passwordForm['password_confirmation'],
                        label: trans('attributes.password_confirmation'),
                        type: _obscureConfirmation
                            ? InputType.password
                            : InputType.text,
                        validator: rules([
                          Required(),
                        ], field: 'password_confirmation'),
                        suffix: WAnchor(
                          onTap: () => setState(
                            () => _obscureConfirmation = !_obscureConfirmation,
                          ),
                          child: WIcon(
                            _obscureConfirmation ? _iconVisible : _iconHidden,
                            className: 'text-fg-muted text-xl',
                          ),
                        ),
                        labelClassName: formTheme.labelClassName,
                        className: formTheme.inputClassName,
                      ),
                    ],
                  ),
                ],
              ),
              // Save action sits BELOW the card (outside the grouped section).
              WDiv(
                className: 'flex justify-end',
                children: [
                  MagicBuilder<bool>(
                    listenable: passwordForm.processingListenable,
                    builder: (isProcessing) => WButton(
                      onTap: isProcessing
                          ? null
                          : (hasPassword
                                ? _submitPassword
                                : _submitSetPassword),
                      isLoading: isProcessing,
                      className:
                          'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
                      child: WText(
                        trans(
                          hasPassword
                              ? 'profile.update_password'
                              : 'profile.set_password',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
