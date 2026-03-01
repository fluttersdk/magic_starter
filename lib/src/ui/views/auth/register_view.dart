import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/auth_controller.dart';
import '../../widgets/auth_form_card.dart';
import '../../widgets/social_login_divider.dart';

/// Registration view with dynamic identity field support.
///
/// Renders the appropriate identity input (email, phone with country, or a
/// toggle between both) based on [MagicStarterConfig.emailIdentity] and
/// [MagicStarterConfig.phoneIdentity] at runtime.
///
/// When phone mode is active, `phone_country` is automatically shown and
/// included in the registration payload.
class MagicStarterRegisterView
    extends MagicStatefulView<StarterAuthController> {
  const MagicStarterRegisterView({super.key});

  @override
  State<MagicStarterRegisterView> createState() =>
      _MagicStarterRegisterViewState();
}

class _MagicStarterRegisterViewState extends MagicStatefulViewState<
    StarterAuthController, MagicStarterRegisterView> {
  /// Both email and phone fields are always declared — the controller decides
  /// which one to include in the payload based on identity mode.
  late final form = MagicFormData(
    {
      'name': '',
      'email': '',
      'phone': '',
      'phone_country': '',
      'password': '',
      'password_confirmation': '',
    },
    controller: controller,
  );

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  /// Tracks whether the user has toggled to phone input in "both" mode.
  bool _usePhone = false;

  bool _subscribeNewsletter = false;

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() => form.dispose();

  Future<void> _submit() async {
    if (!form.validate()) return;

    await controller.doRegister(
      name: form.get('name'),
      email: form.get('email'),
      phone: form.get('phone'),
      phoneCountry: form.get('phone_country'),
      subscribeNewsletter: _subscribeNewsletter,
      password: form.get('password'),
      passwordConfirmation: form.get('password_confirmation'),
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
      title: trans('auth.register_title'),
      subtitle: trans('auth.register_subtitle'),
      errorMessage: errorMessage,
      child: MagicForm(
        formData: form,
        child: WDiv(
          className: 'flex flex-col items-stretch',
          children: [
            // Name
            WFormInput(
              label: trans('attributes.name'),
              controller: form['name'],
              placeholder: trans('fields.name_placeholder'),
              validator: rules([Required(), Min(2)], field: 'name'),
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
              placeholderClassName: 'text-gray-400 dark:text-gray-500',
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            ),
            const WSpacer(className: 'h-4'),

            // Identity field — dynamic based on mode.
            _buildIdentityField(),
            const WSpacer(className: 'h-4'),

            // Password
            WFormInput(
              label: trans('attributes.password'),
              controller: form['password'],
              placeholder: trans('fields.password_placeholder'),
              type: _obscurePassword ? InputType.password : InputType.text,
              validator: rules([Required(), Min(8)], field: 'password'),
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
            const WSpacer(className: 'h-4'),

            // Password Confirmation
            WFormInput(
              label: trans('attributes.password_confirmation'),
              controller: form['password_confirmation'],
              placeholder: trans('fields.password_confirmation_placeholder'),
              type: _obscureConfirmation ? InputType.password : InputType.text,
              validator: rules([Required()], field: 'password_confirmation'),
              suffix: WAnchor(
                onTap: () => setState(
                    () => _obscureConfirmation = !_obscureConfirmation),
                child: WIcon(
                  _obscureConfirmation
                      ? Icons.visibility
                      : Icons.visibility_off,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
              placeholderClassName: 'text-gray-400 dark:text-gray-500',
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            ),
            const WSpacer(className: 'h-6'),

            if (MagicStarterConfig.hasNewsletterFeatures()) ...[
              WDiv(
                className: 'flex flex-row items-center gap-2 mb-6',
                children: [
                  Checkbox(
                    value: _subscribeNewsletter,
                    onChanged: (val) =>
                        setState(() => _subscribeNewsletter = val ?? false),
                    activeColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: WText(
                      MagicStarter.manager.newsletterLabel ??
                          trans('magic_starter.newsletter.subscribe_label'),
                      className: 'text-sm text-gray-600 dark:text-gray-400',
                    ),
                  ),
                ],
              ),
            ],

            // Submit
            WButton(
              isLoading: isLoading,
              onTap: _submit,
              className:
                  'w-full bg-primary hover:bg-primary/80 text-white text-base font-semibold py-3 rounded-lg',
              child: WText(
                trans('auth.register_title'),
                className: 'text-center',
              ),
            ),

            // Social login slot
            if (MagicStarterConfig.hasSocialLoginFeatures() &&
                MagicStarter.hasSocialLogin) ...[
              const MagicStarterSocialDivider(),
              MagicStarter.socialLoginBuilder!(context, isLoading),
            ],

            // Login link
            const WSpacer(className: 'h-6'),
            WAnchor(
              onTap: () => MagicRoute.to('/auth/login'),
              child: WDiv(
                className: 'flex flex-row justify-center gap-1',
                children: [
                  WText(
                    trans('auth.already_have_account'),
                    className: 'text-sm text-gray-500 dark:text-gray-400',
                  ),
                  WText(
                    trans('auth.sign_in'),
                    className: 'text-sm font-semibold text-primary',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the identity input section based on the active mode.
  ///
  /// - Email-only: renders a single email `WFormInput`.
  /// - Phone-only: renders phone + phone_country `WFormInput` pair.
  /// - Both: renders a tab-style toggle and the selected input below.
  Widget _buildIdentityField() {
    final emailMode = MagicStarterConfig.emailIdentity();
    final phoneMode = MagicStarterConfig.phoneIdentity();

    if (emailMode && phoneMode) {
      return _buildIdentityToggle();
    }

    if (phoneMode) {
      return _buildPhoneFields();
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

  /// Phone input + country code pair.
  Widget _buildPhoneFields() {
    return WDiv(
      className: 'space-y-4',
      children: [
        WFormInput(
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
        ),
        WFormInput(
          label: trans('attributes.phone_country'),
          controller: form['phone_country'],
          placeholder: trans('fields.phone_country_placeholder'),
          validator: rules([Required()], field: 'phone_country'),
          className:
              'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
          placeholderClassName: 'text-gray-400 dark:text-gray-500',
          labelClassName:
              'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
        ),
      ],
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
        if (_usePhone) _buildPhoneFields() else _buildEmailInput(),
      ],
    );
  }
}
