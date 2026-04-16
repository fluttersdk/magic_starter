import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_auth_controller.dart';
import '../../widgets/magic_starter_auth_form_card.dart';
import '../../widgets/magic_starter_social_divider.dart';

/// Registration view with dynamic identity field support.
///
/// Renders the appropriate identity input (email, phone, or both fields
/// together) based on [MagicStarterConfig.emailIdentity] and
/// [MagicStarterConfig.phoneIdentity] at runtime.
class MagicStarterRegisterView
    extends MagicStatefulView<MagicStarterAuthController> {
  const MagicStarterRegisterView({super.key});

  @override
  State<MagicStarterRegisterView> createState() =>
      _MagicStarterRegisterViewState();
}

class _MagicStarterRegisterViewState extends MagicStatefulViewState<
    MagicStarterAuthController, MagicStarterRegisterView> {
  static const _iconVisible = Icons.visibility;
  static const _iconHidden = Icons.visibility_off;

  /// Both email and phone fields are always declared — the controller decides
  /// which one to include in the payload based on identity mode.
  late final form = MagicFormData(
    {
      'name': '',
      'email': '',
      'phone': '',
      'password': '',
      'password_confirmation': '',
    },
    controller: controller,
  );

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

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

    final headerSlot =
        MagicStarter.view.buildSlot('auth.register', 'header', context);
    final formFooterSlot =
        MagicStarter.view.buildSlot('auth.register', 'formFooter', context);
    final footerSlot =
        MagicStarter.view.buildSlot('auth.register', 'footer', context);

    return MagicStarterAuthFormCard(
      title: trans('auth.register_title'),
      subtitle: trans('auth.register_subtitle'),
      errorMessage: errorMessage,
      child: MagicForm(
        formData: form,
        child: WDiv(
          className: 'flex flex-col items-stretch',
          children: [
            if (headerSlot != null) headerSlot,

            // Name
            WFormInput(
              label: trans('attributes.name'),
              controller: form['name'],
              placeholder: trans('fields.name_placeholder'),
              validator: rules([Required(), Min(2)], field: 'name'),
              className: MagicStarter.formTheme.inputClassName,
              placeholderClassName: MagicStarter.formTheme.placeholderClassName,
              labelClassName: MagicStarter.formTheme.labelClassName,
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
                  _obscurePassword ? _iconVisible : _iconHidden,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              className: MagicStarter.formTheme.inputClassName,
              placeholderClassName: MagicStarter.formTheme.placeholderClassName,
              labelClassName: MagicStarter.formTheme.labelClassName,
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
                  _obscureConfirmation ? _iconVisible : _iconHidden,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              className: MagicStarter.formTheme.inputClassName,
              placeholderClassName: MagicStarter.formTheme.placeholderClassName,
              labelClassName: MagicStarter.formTheme.labelClassName,
            ),
            const WSpacer(className: 'h-6'),

            if (MagicStarterConfig.hasNewsletterFeatures()) ...[
              WDiv(
                className: 'flex flex-row items-center gap-2 mb-6',
                children: [
                  WFormCheckbox(
                    value: _subscribeNewsletter,
                    onChanged: (value) =>
                        setState(() => _subscribeNewsletter = value),
                    label: WText(
                      MagicStarter.manager.newsletterLabel ??
                          trans('magic_starter.newsletter.subscribe_label'),
                      className:
                          'text-sm text-gray-600 dark:text-gray-400 ml-1',
                    ),
                  ),
                ],
              ),
            ],

            // Legal links (Terms / Privacy)
            _buildLegalLinks(),
            const WSpacer(className: 'h-6'),

            // Submit
            WButton(
              isLoading: isLoading,
              onTap: _submit,
              className: MagicStarter.formTheme.primaryButtonClassName,
              child: WText(
                trans('auth.register_title'),
                className: 'text-center',
              ),
            ),

            if (formFooterSlot != null) formFooterSlot,

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
                    className: MagicStarter.authTheme.registrationLinkClassName,
                  ),
                  WText(
                    trans('auth.sign_in'),
                    className:
                        MagicStarter.authTheme.registrationLinkTextClassName,
                  ),
                ],
              ),
            ),
            if (footerSlot != null) footerSlot,
          ],
        ),
      ),
    );
  }

  /// Builds the identity input section based on the active mode.
  ///
  /// - Email-only: renders a single email [WFormInput].
  /// - Phone-only: renders a single phone [WFormInput].
  /// - Both: renders email AND phone fields together and lets backend enforce
  ///   either-or requirement.
  Widget _buildIdentityField() {
    final emailMode = MagicStarterConfig.emailIdentity();
    final phoneMode = MagicStarterConfig.phoneIdentity();

    if (emailMode && phoneMode) {
      return WDiv(
        className: 'space-y-4',
        children: [
          _buildEmailInput(required: false),
          _buildPhoneInput(required: false),
        ],
      );
    }

    if (phoneMode) {
      return _buildPhoneInput();
    }

    // Default: email-only.
    return _buildEmailInput();
  }

  /// Email input field.
  Widget _buildEmailInput({bool required = true}) {
    return WFormInput(
      label: trans('attributes.email'),
      controller: form['email'],
      placeholder: trans('fields.email_placeholder'),
      type: InputType.email,
      validator: rules(
        required ? [Required(), Email()] : [Email()],
        field: 'email',
      ),
      className: MagicStarter.formTheme.inputClassName,
      placeholderClassName: MagicStarter.formTheme.placeholderClassName,
      labelClassName: MagicStarter.formTheme.labelClassName,
    );
  }

  /// Phone input field.
  Widget _buildPhoneInput({bool required = true}) {
    return WFormInput(
      label: trans('attributes.phone'),
      controller: form['phone'],
      placeholder: trans('fields.phone_placeholder'),
      type: InputType.text,
      validator: rules(
        required ? [Required()] : [],
        field: 'phone',
      ),
      className: MagicStarter.formTheme.inputClassName,
      placeholderClassName: MagicStarter.formTheme.placeholderClassName,
      labelClassName: MagicStarter.formTheme.labelClassName,
    );
  }

  /// Builds the legal links section (Terms of Service / Privacy Policy).
  ///
  /// Returns [SizedBox.shrink] when no legal URLs are configured.
  Widget _buildLegalLinks() {
    if (!MagicStarterConfig.hasLegalLinks()) {
      return const SizedBox.shrink();
    }

    final termsUrl = MagicStarterConfig.termsUrl();
    final privacyUrl = MagicStarterConfig.privacyUrl();

    return WDiv(
      className: 'flex flex-row justify-center gap-1 wrap',
      children: [
        WText(
          trans('auth.agree_to_legal'),
          className: 'text-xs text-gray-500 dark:text-gray-400',
        ),
        if (termsUrl != null)
          WAnchor(
            onTap: () => Launch.url(termsUrl),
            child: WText(
              trans('auth.terms_of_service'),
              className:
                  'text-xs font-semibold text-primary dark:text-primary/80',
            ),
          ),
        if (termsUrl != null && privacyUrl != null)
          WText(
            trans('auth.legal_and'),
            className: 'text-xs text-gray-500 dark:text-gray-400',
          ),
        if (privacyUrl != null)
          WAnchor(
            onTap: () => Launch.url(privacyUrl),
            child: WText(
              trans('auth.privacy_policy'),
              className:
                  'text-xs font-semibold text-primary dark:text-primary/80',
            ),
          ),
      ],
    );
  }
}
