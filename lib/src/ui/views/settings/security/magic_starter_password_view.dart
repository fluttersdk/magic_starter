import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../facades/magic_starter.dart';
import '../../../../http/controllers/magic_starter_profile_controller.dart';
import '../../../components/settings_scaffold/settings_scaffold.dart';
import '../../../components/settings_section/settings_section.dart';

/// Password update settings sub-page.
///
/// Drilled into from the Settings hub. Wraps the current/new/confirm password
/// form in a [SettingsScaffold] with a unified back affordance returning to
/// the hub.
///
/// The form wiring is lifted verbatim from the original long-form profile
/// settings view: the [passwordForm] (current/new/confirm) plus the
/// [MagicStarterProfileController.doUpdatePassword] call are reused unchanged —
/// no endpoint or controller signature is altered here.
class MagicStarterPasswordView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterPasswordView({super.key});

  @override
  State<MagicStarterPasswordView> createState() =>
      _MagicStarterPasswordViewState();
}

class _MagicStarterPasswordViewState extends MagicStatefulViewState<
    MagicStarterProfileController, MagicStarterPasswordView> {
  static const _iconVisible = Icons.visibility;
  static const _iconHidden = Icons.visibility_off;

  late final passwordForm = MagicFormData(
    {
      'current_password': '',
      'password': '',
      'password_confirmation': '',
    },
    controller: controller,
  );

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirmation = true;

  // -- Lifecycle -------------------------------------------------------------

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
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

  Future<void> _submitPassword() async {
    if (!passwordForm.validate()) return;
    final success =
        await passwordForm.process(() => controller.withoutNotifying(
              () => controller.doUpdatePassword(
                currentPassword: passwordForm.get('current_password'),
                password: passwordForm.get('password'),
                passwordConfirmation: passwordForm.get('password_confirmation'),
              ),
            ));
    _rebuildIfValidationErrors();
    if (success) {
      passwordForm.set('current_password', '');
      passwordForm.set('password', '');
      passwordForm.set('password_confirmation', '');
    }
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final formTheme = MagicStarter.formTheme;

    return SettingsScaffold(
      title: trans('profile.update_password'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        MagicForm(
          formData: passwordForm,
          child: SettingsSection(
            children: [
              WDiv(
                className: 'flex flex-col gap-4 px-5 py-4',
                children: [
                  WFormInput(
                    controller: passwordForm['current_password'],
                    label: trans('attributes.current_password'),
                    type: _obscureCurrent ? InputType.password : InputType.text,
                    validator: rules([Required()], field: 'current_password'),
                    suffix: WAnchor(
                      onTap: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
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
                    validator: rules([Required(), Min(8)], field: 'password'),
                    suffix: WAnchor(
                      onTap: () => setState(() => _obscureNew = !_obscureNew),
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
                    validator:
                        rules([Required()], field: 'password_confirmation'),
                    suffix: WAnchor(
                      onTap: () => setState(
                          () => _obscureConfirmation = !_obscureConfirmation),
                      child: WIcon(
                        _obscureConfirmation ? _iconVisible : _iconHidden,
                        className: 'text-fg-muted text-xl',
                      ),
                    ),
                    labelClassName: formTheme.labelClassName,
                    className: formTheme.inputClassName,
                  ),
                  WDiv(
                    className: 'flex justify-end',
                    children: [
                      MagicBuilder<bool>(
                        listenable: passwordForm.processingListenable,
                        builder: (isProcessing) => WButton(
                          onTap: isProcessing ? null : _submitPassword,
                          isLoading: isProcessing,
                          className:
                              'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
                          child: WText(trans('profile.update_password')),
                        ),
                      ),
                    ],
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
