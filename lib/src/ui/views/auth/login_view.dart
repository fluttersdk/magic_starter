import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/auth_controller.dart';
import '../../../http/controllers/guest_auth_controller.dart';
import '../../widgets/auth_form_card.dart';
import '../../widgets/social_login_divider.dart';

/// Login view with dynamic identity field support.
///
/// Renders the appropriate identity input (email, phone, or a toggle between
/// both) based on [MagicStarterConfig.emailIdentity] and
/// [MagicStarterConfig.phoneIdentity] at runtime.
class MagicStarterLoginView extends MagicStatefulView<StarterAuthController> {
  const MagicStarterLoginView({super.key});

  @override
  State<MagicStarterLoginView> createState() => _MagicStarterLoginViewState();
}

class _MagicStarterLoginViewState extends MagicStatefulViewState<
    StarterAuthController, MagicStarterLoginView> {
  /// Both email and phone fields are always declared — the controller decides
  /// which one to include in the payload based on identity mode.
  late final form = MagicFormData(
    {
      'email': '',
      'phone': '',
      'password': '',
      'remember_me': false,
    },
    controller: controller,
  );

  bool _obscurePassword = true;

  /// Tracks whether the user has toggled to phone input in "both" mode.
  bool _usePhone = false;

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() => form.dispose();

  Future<void> _submit() async {
    if (!form.validate()) return;

    await controller.doLogin(
      email: form.get('email'),
      phone: form.get('phone'),
      password: form.get('password'),
      rememberMe: form.value<bool>('remember_me'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (_) => _buildForm(),
      onEmpty: _buildForm(),
      onError: (message) => _buildForm(errorMessage: message),
    );
  }

  Widget _buildForm({String? errorMessage}) {
    final isLoading = controller.isLoading;

    return MagicStarterAuthFormCard(
      title: trans('auth.login_title'),
      subtitle: trans('auth.login_subtitle'),
      errorMessage: errorMessage,
      child: MagicForm(
        formData: form,
        child: WDiv(
          className: 'flex flex-col items-stretch',
          children: [
            _buildIdentityField(),
            const WSpacer(className: 'h-4'),
            WFormInput(
              label: trans('attributes.password'),
              controller: form['password'],
              placeholder: trans('fields.password_placeholder'),
              type: _obscurePassword ? InputType.password : InputType.text,
              validator: rules([Required()], field: 'password'),
              suffix: WAnchor(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: WIcon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
              placeholderClassName: 'text-gray-400 dark:text-gray-500',
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            ),
            const WSpacer(className: 'h-5'),
            WDiv(
              className: 'flex flex-row items-center justify-between',
              children: [
                WFormCheckbox(
                  value: form.value<bool>('remember_me'),
                  onChanged: (value) => form.setValue('remember_me', value),
                  label: WText(
                    trans('auth.remember_me'),
                    className:
                        'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200 ml-1',
                  ),
                ),
                WAnchor(
                  onTap: () => MagicRoute.to('/auth/forgot-password'),
                  child: WText(
                    trans('auth.forgot_password'),
                    className: 'text-sm font-medium text-primary',
                  ),
                ),
              ],
            ),
            const WSpacer(className: 'h-6'),
            WButton(
              isLoading: isLoading,
              onTap: _submit,
              className:
                  'w-full bg-primary hover:bg-primary/80 text-white text-base font-semibold py-3 rounded-lg',
              child: WText(trans('auth.login_title'), className: 'text-center'),
            ),
            if (MagicStarterConfig.hasGuestAuthFeatures()) ...[
              const WSpacer(className: 'h-4'),
              WButton(
                onTap: StarterGuestAuthController.instance.doGuestLogin,
                isLoading: isLoading,
                className:
                    'w-full bg-transparent border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 py-3 rounded-lg text-sm font-medium',
                child: WText(
                  trans('magic_starter.auth.continue_as_guest'),
                  className: 'text-center',
                ),
              ),
            ],
            if (MagicStarterConfig.hasSocialLoginFeatures() &&
                MagicStarter.hasSocialLogin) ...[
              const MagicStarterSocialDivider(),
              MagicStarter.socialLoginBuilder!(context, isLoading),
            ],
            if (MagicStarterConfig.hasRegistrationFeatures()) ...[
              const WSpacer(className: 'h-6'),
              WAnchor(
                onTap: () => MagicRoute.to('/auth/register'),
                child: WDiv(
                  className: 'flex flex-row justify-center gap-1',
                  children: [
                    WText(
                      trans('auth.dont_have_account'),
                      className: 'text-sm text-gray-500 dark:text-gray-400',
                    ),
                    WText(
                      trans('auth.sign_up'),
                      className: 'text-sm font-semibold text-primary',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the identity input section based on the active mode.
  ///
  /// - Email-only: renders a single email `WFormInput`.
  /// - Phone-only: renders a single phone `WFormInput`.
  /// - Both: renders a tab-style toggle and the selected input below.
  Widget _buildIdentityField() {
    final emailMode = MagicStarterConfig.emailIdentity();
    final phoneMode = MagicStarterConfig.phoneIdentity();

    if (emailMode && phoneMode) {
      return _buildIdentityToggle();
    }

    if (phoneMode) {
      return _buildPhoneInput();
    }

    // Default: email-only.
    return _buildEmailInput();
  }

  /// Email input field.
  Widget _buildEmailInput() {
    return WFormInput(
      label: trans('attributes.email'),
      controller: form['email'],
      placeholder: trans('fields.email_placeholder'),
      type: InputType.email,
      validator: rules([Required(), Email()], field: 'email'),
      className:
          'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
      placeholderClassName: 'text-gray-400 dark:text-gray-500',
      labelClassName:
          'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
    );
  }

  /// Phone input field.
  Widget _buildPhoneInput() {
    return WFormInput(
      label: trans('attributes.phone'),
      controller: form['phone'],
      placeholder: '+905301234567',
      type: InputType.text,
      validator: rules([Required()], field: 'phone'),
      className:
          'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
      placeholderClassName: 'text-gray-400 dark:text-gray-500',
      labelClassName:
          'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
    );
  }

  /// Tab toggle + dynamic input for "both" identity mode.
  Widget _buildIdentityToggle() {
    return WDiv(
      className: 'space-y-3',
      children: [
        // Toggle row — [Email] [Phone].
        WDiv(
          className: 'flex flex-row gap-2',
          children: [
            WButton(
              onTap: () => setState(() => _usePhone = false),
              className: _usePhone
                  ? 'flex-1 py-2 rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 text-sm font-medium'
                  : 'flex-1 py-2 rounded-lg bg-primary dark:bg-primary text-white text-sm font-medium',
              child: WText(
                trans('attributes.email'),
                className: 'text-center',
              ),
            ),
            WButton(
              onTap: () => setState(() => _usePhone = true),
              className: _usePhone
                  ? 'flex-1 py-2 rounded-lg bg-primary dark:bg-primary text-white text-sm font-medium'
                  : 'flex-1 py-2 rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 text-sm font-medium',
              child: WText(
                trans('attributes.phone'),
                className: 'text-center',
              ),
            ),
          ],
        ),
        if (_usePhone) _buildPhoneInput() else _buildEmailInput(),
      ],
    );
  }
}
