import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/profile_controller.dart';
import '../../widgets/starter_card.dart';
import '../../widgets/starter_page_header.dart';
import '../../widgets/starter_password_confirm_dialog.dart';
import '../../widgets/magic_starter_two_factor_modal.dart';
import '../../../http/controllers/newsletter_controller.dart';
import '../../widgets/magic_starter_timezone_select.dart';

/// Profile settings view --- multi-section page for managing user profile.
///
/// Sections are gated by two mechanisms:
///
/// 1. **Feature toggles** via [MagicStarterConfig] (e.g. `hasProfilePhotoFeatures`)
/// 2. **Gate abilities** (e.g. `starter.update-password`) — guests are denied by
///    default; host apps can override by re-defining any `starter.*` ability.
///
/// See [MagicStarterServiceProvider] for the default Gate ability definitions.
class MagicStarterProfileSettingsView
    extends MagicStatefulView<StarterProfileController> {
  const MagicStarterProfileSettingsView({super.key});

  @override
  State<MagicStarterProfileSettingsView> createState() =>
      _MagicStarterProfileSettingsViewState();
}

class _MagicStarterProfileSettingsViewState extends MagicStatefulViewState<
    StarterProfileController, MagicStarterProfileSettingsView> {
  // -- Profile & password forms -----------------------------------------------

  late final profileForm = MagicFormData(
    {
      'name': '',
      'email': '',
      'phone': '',
      'timezone': '',
      'language': '',
    },
    controller: controller,
  );

  late final passwordForm = MagicFormData(
    {
      'current_password': '',
      'password': '',
      'password_confirmation': '',
    },
    controller: controller,
  );

  late final deleteAccountForm = MagicFormData(
    {'password': ''},
    controller: controller,
  );

  late final upgradeForm = MagicFormData(
    {
      'email': '',
      'password': '',
      'password_confirmation': '',
    },
    controller: controller,
  );

  bool _obscureUpgradePassword = true;
  bool _obscureUpgradeConfirmation = true;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirmation = true;

  // -- 2FA UI state: 'disabled' | 'enabled' ----------------------------------

  String _twoFactorState = 'disabled';
  List<String> _recoveryCodes = [];

  // -- Section-level loading notifiers (isolated per section) ----------------

  /// Per-section loading notifiers prevent cross-section spinner leaks.
  ///
  /// The profile page shares a single [StarterProfileController] whose
  /// [MagicStateMixin.isLoading] flag is global. When any controller
  /// method calls [setLoading], the parent [MagicStarterAppLayout]
  /// rebuilds (via [Auth.stateNotifier] bumped by [Auth.restore]),
  /// causing every button bound to [controller.isLoading] to show a
  /// spinner simultaneously. These per-section notifiers decouple each
  /// section's loading indicator from the controller's global state.
  final ValueNotifier<bool> _photoLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _emailVerificationLoading =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _twoFactorLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _sessionActionLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _profileSaveLoading = ValueNotifier<bool>(false);

  // -- Sessions state --------------------------------------------------------

  List<Map<String, dynamic>> _sessions = [];
  bool _sessionsLoading = false;
  // -- Lifecycle -------------------------------------------------------------

  @override
  void onInit() {
    final user = Auth.user();
    if (user != null) {
      profileForm.set('name', user.get<String>('name') ?? '');
      profileForm.set('email', user.get<String>('email') ?? '');
      profileForm.set('phone', user.get<String>('phone') ?? '');
      profileForm.set('timezone', user.get<String>('timezone') ?? '');
      profileForm.set('language', user.get<String>('locale') ?? '');
    }
    controller.clearErrors();
    controller.setEmpty();

    if (MagicStarterConfig.hasSessionsFeatures()) {
      _loadSessions();
    }

    if (MagicStarterConfig.hasNewsletterFeatures()) {
      StarterNewsletterController.instance.getNewsletterStatus();
    }
    if (controller.isTwoFactorEnabled) {
      _twoFactorState = 'enabled';
    }
  }

  @override
  void onClose() {
    profileForm.dispose();
    passwordForm.dispose();
    deleteAccountForm.dispose();
    upgradeForm.dispose();
    _photoLoading.dispose();
    _emailVerificationLoading.dispose();
    _twoFactorLoading.dispose();
    _sessionActionLoading.dispose();
    _profileSaveLoading.dispose();
  }

  // -- Profile actions --------------------------------------------------------

  /// Execute [action] while driving the given [notifier] to `true`/`false`.
  ///
  /// Wraps the action in a try/finally so the notifier resets even on error.
  /// Use this instead of [controller.isLoading] to isolate loading indicators
  /// to a single section of the profile page.
  Future<T> _trackLoading<T>(
      ValueNotifier<bool> notifier, Future<T> Function() action) async {
    notifier.value = true;
    try {
      return await action();
    } finally {
      notifier.value = false;
    }
  }

  /// Triggers a rebuild when [controller.withoutNotifying] suppresses the
  /// [notifyListeners] call inside [handleApiError] / [setErrorsFromResponse].
  ///
  /// Without this, validation errors are set on the controller but the UI
  /// never rebuilds to display them.
  void _rebuildIfValidationErrors() {
    if (controller.hasErrors) {
      setState(() {});
      // Re-trigger form validators so FormField picks up server errors
      // via controller.getError(field) inside the rules() helper.
      profileForm.formKey.currentState?.validate();
    }
  }

  Future<void> _submitProfile() async {
    if (!profileForm.validate()) return;
    await _trackLoading(
      _profileSaveLoading,
      () => controller.withoutNotifying(
        () => controller.doUpdateProfile(
          name: profileForm.get('name'),
          email: profileForm.get('email'),
          phone: profileForm.get('phone'),
          timezone: profileForm.get('timezone'),
          language: profileForm.get('language'),
        ),
      ),
    );
    _rebuildIfValidationErrors();
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

  // -- 2FA actions -----------------------------------------------------------

  /// Enable 2FA flow with password confirmation and setup modal.
  Future<void> _enableTwoFactor(BuildContext context) async {
    Map<String, dynamic>? setupData;

    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    await MagicStarterPasswordConfirmDialog.show(
      context,
      onConfirm: (password) async {
        final data = await _trackLoading(
          _twoFactorLoading,
          () => controller.doEnableTwoFactor(password: password),
        );
        if (data == null) {
          final error = controller.rxStatus.message ?? trans('common.error_occurred');
          controller.clearErrors();
          return error;
        }
        setupData = data;
        return null;  // success → dialog closes
      },
    );

    if (setupData == null) return;  // user cancelled or all attempts failed

    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    final confirmed = await MagicStarterTwoFactorModal.show(
      context,
      setupData: setupData!,
      onConfirm: (code) => controller.doConfirmTwoFactor(code: code),
    );

    if (confirmed) {
      setState(() => _twoFactorState = 'enabled');
    }
  }

  /// Disable 2FA --- requires password confirmation.
  Future<void> _disableTwoFactor(BuildContext context) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    final success = await MagicStarterPasswordConfirmDialog.show(
      context,
      onConfirm: (password) async {
        final ok = await _trackLoading(
          _twoFactorLoading,
          () => controller.doDisableTwoFactor(password: password),
        );
        if (!ok) {
          final error = controller.rxStatus.message ?? trans('common.error_occurred');
          controller.clearErrors();
          return error;
        }
        return null;
      },
    );

    if (success) {
      setState(() {
        _twoFactorState = 'disabled';
        _recoveryCodes = [];
      });
    }
  }

  /// Show current recovery codes from server.
  Future<void> _showRecoveryCodes(BuildContext context) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;
    await MagicStarterPasswordConfirmDialog.show(
      context,
      onConfirm: (password) async {
        final codes = await _trackLoading(
          _twoFactorLoading,
          () => controller.getRecoveryCodes(password: password),
        );
        if (codes == null) {
          final error = controller.rxStatus.message ?? trans('common.error_occurred');
          controller.clearErrors();
          return error;
        }
        setState(() => _recoveryCodes = codes);
        return null;
      },
    );
  }

  /// Regenerate recovery codes on the server.
  Future<void> _regenerateRecoveryCodes(BuildContext context) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;
    await MagicStarterPasswordConfirmDialog.show(
      context,
      onConfirm: (password) async {
        final codes = await _trackLoading(
          _twoFactorLoading,
          () => controller.doRegenerateRecoveryCodes(password: password),
        );
        if (codes == null) {
          final error = controller.rxStatus.message ?? trans('common.error_occurred');
          controller.clearErrors();
          return error;
        }
        setState(() => _recoveryCodes = codes);
        return null;
      },
    );
  }

  // -- Sessions actions -------------------------------------------------------

  Future<void> _loadSessions() async {
    setState(() => _sessionsLoading = true);
    final result = await controller.getSessions();
    setState(() {
      _sessions = result ?? [];
      _sessionsLoading = false;
    });
  }

  Future<void> _revokeSession(String tokenId) async {
    final success = await _trackLoading(
      _sessionActionLoading,
      () => controller.doRevokeSession(tokenId: tokenId),
    );
    if (success) {
      _loadSessions();
    }
  }

  Future<void> _revokeOtherSessions(BuildContext context) async {
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    final success = await MagicStarterPasswordConfirmDialog.show(
      context,
      onConfirm: (password) async {
        final ok = await _trackLoading(
          _sessionActionLoading,
          () => controller.doRevokeOtherSessions(password: password),
        );
        if (!ok) {
          return controller.rxStatus.message ?? trans('common.error_occurred');
        }
        return null;
      },
    );

    if (success) {
      _loadSessions();
    }
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(
          title: trans('profile.settings'),
          subtitle: trans('profile.settings_subtitle'),
        ),
        if (MagicStarterConfig.hasProfilePhotoFeatures() &&
            Gate.allows('starter.update-profile-photo'))
          _buildProfilePhotoSection(),
        // Email verification banner right after photo when unverified.
        if (MagicStarterConfig.hasEmailVerificationFeatures() &&
            Gate.allows('starter.verify-email') &&
            !controller.isEmailVerified)
          _buildEmailVerificationSection(),
        MagicForm(
          formData: profileForm,
          child: _buildProfileSection(),
        ),
        if (Gate.allows('starter.update-password')) _buildPasswordSection(),
        // Verified badge shown inline (not at top).
        if (MagicStarterConfig.hasEmailVerificationFeatures() &&
            Gate.allows('starter.verify-email') &&
            controller.isEmailVerified)
          _buildEmailVerificationSection(),
        if (MagicStarterConfig.hasNewsletterFeatures() &&
            Gate.allows('starter.manage-newsletter'))
          _buildNewsletterSection(),
        if (MagicStarterConfig.hasTwoFactorFeatures() &&
            Gate.allows('starter.manage-two-factor'))
          _buildTwoFactorSection(),
        if (Gate.denies('starter.delete-account')) _buildGuestUpgradeSection(),
        if (MagicStarterConfig.hasSessionsFeatures()) _buildSessionsSection(),
        _buildDeleteAccountSection(),
      ],
    );
  }
  // -- Profile Photo Section -------------------------------------------------

  Widget _buildProfilePhotoSection() {
    final user = Auth.user();
    final photoUrl = user?.get<String>('profile_photo_url');

    return MagicStarterCard(
      title: trans('profile.profile_photo'),
      child: WDiv(
        className: 'w-full flex flex-col sm:flex-row items-center gap-6',
        children: [
          ClipOval(
            child: SizedBox(
              width: 80,
              height: 80,
              child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? WImage(
                      src: photoUrl,
                      className: 'w-full h-full object-cover',
                    )
                  : WDiv(
                      className:
                          'w-full h-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center',
                      child: WIcon(
                        Icons.person_outline,
                        className: 'text-gray-400 text-3xl',
                      ),
                    ),
            ),
          ),
          WDiv(
            className: 'flex flex-col gap-2 min-w-0',
            children: [
              MagicBuilder<bool>(
                listenable: _photoLoading,
                builder: (isLoading) => WDiv(
                  className:
                      'flex flex-col sm:flex-row items-stretch sm:items-center gap-2 sm:gap-3',
                  children: [
                    WButton(
                      onTap: isLoading ? null : _handlePhotoUpload,
                      isLoading: isLoading,
                      className:
                          'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium',
                      child: WText(trans('common.upload')),
                    ),
                    if (photoUrl != null && photoUrl.isNotEmpty)
                      WButton(
                        onTap: isLoading ? null : _handlePhotoRemove,
                        isLoading: isLoading,
                        className:
                            'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-red-200 dark:border-red-900/50 hover:bg-red-50 dark:hover:bg-red-900/20 text-red-600 dark:text-red-400 text-sm font-medium',
                        child: WText(trans('common.remove')),
                      ),
                  ],
                ),
              ),
              WText(
                trans('profile.photo_requirements'),
                className: 'text-xs text-gray-500 dark:text-gray-400',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handlePhotoUpload() async {
    final file = await Pick.image();
    if (file == null) return;
    await _trackLoading(
      _photoLoading,
      () => controller.doUpdateProfilePhoto(file: file),
    );
  }

  Future<void> _handlePhotoRemove() async {
    await _trackLoading(
      _photoLoading,
      () => controller.doDeleteProfilePhoto(),
    );
  }

  // -- Profile Section -------------------------------------------------------

  Widget _buildProfileSection() {
    // Resolve locale options for extended profile fields.
    final locales = MagicStarter.manager.localeOptions;

    final finalLocales = locales.isNotEmpty
        ? locales
        : [
            SelectOption<String>(value: 'en', label: 'English'),
            SelectOption<String>(value: 'tr', label: 'Türkçe'),
          ];
    final hasExtended = MagicStarterConfig.hasExtendedProfileFeatures();

    return MagicStarterCard(
      title: trans('profile.profile_information'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          WFormInput(
            controller: profileForm['name'],
            label: trans('attributes.name'),
            validator: rules([Required(), Min(2)], field: 'name'),
            labelClassName:
                'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            className:
                'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
          ),
          // Gate: guests cannot see/edit their email.
          if (Gate.allows('starter.update-email'))
            WFormInput(
              controller: profileForm['email'],
              label: trans('attributes.email'),
              type: InputType.email,
              validator: rules([Required(), Email()], field: 'email'),
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
            ),
          // Extended fields: phone, timezone, language — feature-gated.
          if (hasExtended && Gate.allows('starter.update-phone'))
            WFormInput(
              controller: profileForm['phone'],
              label: trans('profile.phone_label'),
              placeholder: '+905301234567',
              validator: rules([], field: 'phone'),
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
            ),
          if (MagicStarterConfig.hasTimezoneOrExtendedProfileFeatures())
            MagicStarterTimezoneSelect(
              value: profileForm.get('timezone'),
              onChanged: (v) => profileForm.set('timezone', v ?? ''),
              label: trans('profile.timezone_label'),
            ),
          if (hasExtended)
            WFormSelect<String>(
              value: profileForm.get('language'),
              onChange: (v) => profileForm.set('language', v ?? ''),
              label: trans('profile.language_label'),
              options: finalLocales,
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white text-sm border border-gray-200 dark:border-gray-700 focus:border-primary focus:ring-2 focus:ring-primary/20 error:border-red-500 duration-150',
              menuClassName:
                  'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl shadow-xl',
            ),
          WDiv(
            className: 'flex justify-end',
            children: [
              MagicBuilder<bool>(
                listenable: _profileSaveLoading,
                builder: (isProcessing) => WButton(
                  onTap: isProcessing ? null : _submitProfile,
                  isLoading: isProcessing,
                  className:
                      'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
                  child: WText(trans('common.save')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -- Password Section ------------------------------------------------------

  Widget _buildPasswordSection() {
    return MagicForm(
      formData: passwordForm,
      child: MagicStarterCard(
        title: trans('profile.update_password'),
        child: WDiv(
          className: 'flex flex-col gap-4',
          children: [
            WFormInput(
              controller: passwordForm['current_password'],
              label: trans('attributes.current_password'),
              type: _obscureCurrent ? InputType.password : InputType.text,
              validator: rules([Required()], field: 'current_password'),
              suffix: WAnchor(
                onTap: () => setState(() => _obscureCurrent = !_obscureCurrent),
                child: WIcon(
                  _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
            ),
            WFormInput(
              controller: passwordForm['password'],
              label: trans('attributes.new_password'),
              type: _obscureNew ? InputType.password : InputType.text,
              validator: rules([Required(), Min(8)], field: 'password'),
              suffix: WAnchor(
                onTap: () => setState(() => _obscureNew = !_obscureNew),
                child: WIcon(
                  _obscureNew ? Icons.visibility : Icons.visibility_off,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
            ),
            WFormInput(
              controller: passwordForm['password_confirmation'],
              label: trans('attributes.password_confirmation'),
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
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
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
      ),
    );
  }

  // -- Email Verification Section -------------------------------------------

  /// Builds the email verification status section.
  ///
  /// Gated behind [MagicStarterConfig.hasEmailVerificationFeatures].
  /// Shows a green verified badge when the user's email is confirmed,
  /// or a yellow warning banner with a resend button when unverified.
  Widget _buildEmailVerificationSection() {
    if (controller.isEmailVerified) {
      return MagicStarterCard(
        title: trans('magic_starter.email_verification.section_title'),
        child: WDiv(
          className: 'flex items-center gap-3 py-1',
          children: [
            WIcon(
              Icons.verified,
              className: 'text-green-500 dark:text-green-400 text-xl',
            ),
            WText(
              trans('magic_starter.email_verification.verified'),
              className:
                  'text-sm font-medium text-green-700 dark:text-green-300',
            ),
          ],
        ),
      );
    }

    return MagicStarterCard(
      title: trans('magic_starter.email_verification.section_title'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          WDiv(
            className:
                'flex items-start gap-3 p-3 rounded-lg bg-yellow-50 dark:bg-yellow-900/20'
                ' border border-yellow-200 dark:border-yellow-700',
            children: [
              WIcon(
                Icons.warning_amber_rounded,
                className:
                    'text-yellow-500 dark:text-yellow-400 text-xl mt-0.5',
              ),
              WDiv(
                className: 'flex flex-col gap-1 flex-1',
                children: [
                  WText(
                    trans('magic_starter.email_verification.unverified_title'),
                    className:
                        'text-sm font-semibold text-yellow-800 dark:text-yellow-200',
                  ),
                  WText(
                    trans(
                        'magic_starter.email_verification.unverified_description'),
                    className: 'text-sm text-yellow-700 dark:text-yellow-300',
                  ),
                ],
              ),
            ],
          ),
          MagicBuilder<bool>(
            listenable: _emailVerificationLoading,
            builder: (isLoading) => WButton(
              onTap: isLoading ? null : _handleSendEmailVerification,
              isLoading: isLoading,
              className:
                  'self-start px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
              child: WText(
                  trans('magic_starter.email_verification.resend_button')),
            ),
          ),
        ],
      ),
    );
  }

  /// Sends email verification with isolated loading state.
  Future<void> _handleSendEmailVerification() async {
    await _trackLoading(
      _emailVerificationLoading,
      () => controller.sendEmailVerification(),
    );
  }

  // -- Two-Factor Section ----------------------------------------------------

  /// Builds the two-factor authentication management section.
  ///
  /// Gated behind [MagicStarterConfig.hasTwoFactorFeatures].
  /// Renders one of two states: disabled, enabled.
  Widget _buildTwoFactorSection() {
    return MagicStarterCard(
      title: trans('profile.two_factor_authentication'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          if (_twoFactorState == 'disabled') _buildTwoFactorDisabled(),
          if (_twoFactorState == 'enabled') _buildTwoFactorEnabled(),
        ],
      ),
    );
  }

  /// Disabled state: description + Enable button.
  Widget _buildTwoFactorDisabled() {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        WText(
          trans('profile.two_factor_disabled_description'),
          className: 'text-sm text-gray-600 dark:text-gray-400',
        ),
        MagicBuilder<bool>(
          listenable: _twoFactorLoading,
          builder: (isLoading) => Builder(
            builder: (context) => WButton(
              onTap: isLoading ? null : () => _enableTwoFactor(context),
              isLoading: isLoading,
              className:
                  'self-start px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
              child: WText(trans('profile.two_factor_enable')),
            ),
          ),
        ),
      ],
    );
  }

  /// Enabled state: green status badge, recovery codes, management buttons.
  Widget _buildTwoFactorEnabled() {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WDiv(
              className: 'w-3 h-3 rounded-full bg-green-500 dark:bg-green-400',
            ),
            WText(
              trans('profile.two_factor_enabled'),
              className:
                  'text-sm font-medium text-green-700 dark:text-green-400',
            ),
          ],
        ),
        WText(
          trans('profile.two_factor_enabled_description'),
          className: 'text-sm text-gray-600 dark:text-gray-400',
        ),
        if (_recoveryCodes.isNotEmpty) ...[
          WText(
            trans('profile.two_factor_recovery_codes_description'),
            className: 'text-sm font-medium text-gray-700 dark:text-gray-300',
          ),
          WDiv(
            className: 'wrap gap-2',
            children: [
              ..._recoveryCodes.map(
                (code) => WDiv(
                  className:
                      'font-mono text-sm bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200 px-2 py-1 rounded',
                  child: WText(code),
                ),
              ),
              WDiv(
                className: 'w-full mt-2 flex flex-row gap-2 wrap',
                children: [
                  WButton(
                    onTap: () async {
                      final codes = _recoveryCodes.join('\n');
                      await Clipboard.setData(ClipboardData(text: codes));
                    },
                    className:
                        'text-primary dark:text-primary border border-primary/30 dark:border-primary/30 hover:bg-primary/5 dark:hover:bg-primary/10 rounded-lg px-4 py-2 text-sm font-medium',
                    child: WText(
                      trans('profile.copy_recovery_codes'),
                      className: 'text-center',
                    ),
                  ),
                  MagicBuilder<bool>(
                    listenable: _twoFactorLoading,
                    builder: (isLoading) => Builder(
                      builder: (context) => WButton(
                        onTap: isLoading
                            ? null
                            : () => _regenerateRecoveryCodes(context),
                        isLoading: isLoading,
                        className:
                            'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium',
                        child: WText(trans('profile.two_factor_regenerate_codes')),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
        MagicBuilder<bool>(
          listenable: _twoFactorLoading,
          builder: (isLoading) => WDiv(
            className: 'wrap gap-3',
            children: [
              Builder(
                builder: (context) => WButton(
                  onTap: isLoading ? null : () => _showRecoveryCodes(context),
                  isLoading: isLoading,
                  className:
                      'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium',
                  child: WText(trans('profile.two_factor_show_recovery_codes')),
                ),
              ),
              Builder(
                builder: (context) => WButton(
                  onTap: isLoading ? null : () => _disableTwoFactor(context),
                  isLoading: isLoading,
                  className:
                      'text-red-600 dark:text-red-400 border border-red-200 dark:border-red-700 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg px-4 py-2 text-sm font-medium',
                  child: WText(trans('profile.two_factor_disable')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// -- Newsletter Section ------------------------------------------------------

  Widget _buildNewsletterSection() {
    return MagicStarterCard(
      title: trans('magic_starter.newsletter.section_title'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          WText(
            trans('magic_starter.newsletter.section_description'),
            className: 'text-sm text-gray-600 dark:text-gray-400',
          ),
          Builder(
            builder: (context) {
              final newsletterController = StarterNewsletterController.instance;
              return newsletterController.renderState(
                (data) {
                  final isSubscribed = data?['subscribed'] as bool? ?? false;
                  return WButton(
                    onTap: () async {
                      await newsletterController.updateNewsletterSubscription(
                        subscribe: !isSubscribed,
                      );
                    },
                    isLoading: newsletterController.isLoading,
                    className:
                        'self-start px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
                    child:
                        WText(trans('magic_starter.newsletter.toggle_button')),
                  );
                },
                onEmpty: WDiv(
                  className: 'flex items-center justify-start py-2',
                  children: [
                    WIcon(
                      Icons.refresh,
                      className:
                          'text-gray-400 dark:text-gray-500 animate-spin text-2xl',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

// -- Sessions Section ------------------------------------------------------

  /// Builds the browser sessions management section.
  ///
  /// Gated behind [MagicStarterConfig.hasSessionsFeatures].
  /// Shows a loading indicator, empty state, or a list of active sessions.
  Widget _buildSessionsSection() {
    return MagicStarterCard(
      title: trans('profile.browser_sessions'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          WText(
            trans('profile.browser_sessions_description'),
            className: 'text-sm text-gray-600 dark:text-gray-400',
          ),
          if (_sessionsLoading)
            WDiv(
              className: 'flex flex-row justify-center py-4',
              children: [
                WIcon(
                  Icons.refresh,
                  className:
                      'text-gray-400 dark:text-gray-500 animate-spin text-2xl',
                ),
              ],
            )
          else if (_sessions.isEmpty)
            WText(
              trans('profile.no_active_sessions'),
              className:
                  'text-sm text-gray-500 dark:text-gray-400 text-center py-4',
            )
          else
            WDiv(
              className: 'flex flex-col gap-3',
              children: _sessions.map(_buildSessionItem).toList(),
            ),
          // Gate: guests cannot logout/revoke sessions.
          if (Gate.allows('starter.logout-sessions'))
            MagicBuilder<bool>(
              listenable: _sessionActionLoading,
              builder: (isLoading) => WDiv(
                className: 'mt-2',
                children: [
                  Builder(
                    builder: (context) => WButton(
                      onTap: isLoading
                          ? null
                          : () => _revokeOtherSessions(context),
                      isLoading: isLoading,
                      className:
                          'text-red-600 dark:text-red-400 border border-red-200 dark:border-red-700 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg px-4 py-2 w-full flex justify-center',
                      child: WText(trans('profile.logout_other_sessions')),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Renders a single session row with device icon, info, and action.
  Widget _buildSessionItem(Map<String, dynamic> session) {
    final agent = session['agent'] as Map<String, dynamic>? ?? {};
    final locationMap = session['location'] as Map<String, dynamic>? ?? {};
    final isDesktop = agent['is_desktop'] as bool? ?? true;
    final platform = agent['platform'] as String? ?? '';
    final browser = agent['browser'] as String? ?? '';
    final ip = session['ip_address'] as String? ?? '';
    final city = locationMap['city'] as String? ?? '';
    final country = locationMap['country'] as String? ?? '';
    final isCurrent = session['is_current_device'] as bool? ?? false;
    final tokenId = session['id']?.toString() ?? '';
    final locationText = [city, country].where((s) => s.isNotEmpty).join(', ');

    return WDiv(
      className:
          'flex flex-row items-start gap-3 p-3 rounded-lg bg-gray-50 dark:bg-gray-800/50 border border-gray-200 dark:border-gray-700',
      children: [
        WIcon(
          isDesktop ? Icons.computer : Icons.phone_android,
          className: 'text-gray-500 dark:text-gray-400 mt-1 text-xl',
        ),
        WDiv(
          className: 'flex flex-col flex-1 gap-1',
          children: [
            WDiv(
              className: 'flex flex-row items-center gap-2 flex-wrap',
              children: [
                WText(
                  [platform, browser].where((s) => s.isNotEmpty).join(' - '),
                  className:
                      'text-sm font-medium text-gray-900 dark:text-white',
                ),
                if (isCurrent)
                  WDiv(
                    className:
                        'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 text-xs font-medium px-2 py-0.5 rounded-full',
                    children: [WText(trans('profile.current_device'))],
                  ),
              ],
            ),
            if (ip.isNotEmpty)
              WText(
                ip,
                className: 'text-xs text-gray-500 dark:text-gray-400',
              ),
            if (locationText.isNotEmpty)
              WText(
                locationText,
                className: 'text-xs text-gray-500 dark:text-gray-400',
              ),
          ],
        ),
        if (!isCurrent)
          MagicBuilder<bool>(
            listenable: _sessionActionLoading,
            builder: (isLoading) => WButton(
              onTap: isLoading ? null : () => _revokeSession(tokenId),
              isLoading: isLoading,
              className:
                  'text-red-600 dark:text-red-400 text-sm px-3 py-1 rounded border border-red-200 dark:border-red-700 hover:bg-red-50 dark:hover:bg-red-900/20',
              child: WText(trans('profile.revoke')),
            ),
          ),
      ],
    );
  }

  /// Builds the delete account section with password confirmation.
  ///
  /// When the user is a guest (denied `starter.delete-account`), renders an
  /// upgrade prompt instead of the destructive delete form.
  Widget _buildDeleteAccountSection() {
    // Gate: guests see an upgrade prompt instead of the delete form.
    if (Gate.denies('starter.delete-account')) {
      return MagicStarterCard(
        title: trans('magic_starter.profile.delete_account.title'),
        child: WDiv(
          className: 'flex flex-col gap-4',
          children: [
            WDiv(
              className:
                  'flex items-start gap-3 p-3 rounded-lg bg-blue-50 dark:bg-blue-900/20'
                  ' border border-blue-200 dark:border-blue-700',
              children: [
                WIcon(
                  Icons.info_outline,
                  className: 'text-blue-500 dark:text-blue-400 text-xl mt-0.5',
                ),
                WDiv(
                  className: 'flex flex-col gap-1 flex-1',
                  children: [
                    WText(
                      trans(
                        'magic_starter.profile.delete_account.guest_upgrade_title',
                      ),
                      className:
                          'text-sm font-semibold text-blue-800 dark:text-blue-200',
                    ),
                    WText(
                      trans(
                        'magic_starter.profile.delete_account.guest_upgrade_description',
                      ),
                      className: 'text-sm text-blue-700 dark:text-blue-300',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    return MagicForm(
      formData: deleteAccountForm,
      child: MagicStarterCard(
        title: trans('magic_starter.profile.delete_account.title'),
        child: WDiv(
          className: 'flex flex-col gap-4',
          children: [
            WText(
              trans('magic_starter.profile.delete_account.description'),
              className: 'text-sm text-gray-600 dark:text-gray-400',
            ),
            WFormInput(
              controller: deleteAccountForm['password'],
              label:
                  trans('magic_starter.profile.delete_account.password_label'),
              type: InputType.password,
              validator: rules(
                [Required()],
                field: 'password',
              ),
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
            ),
            WDiv(
              className: 'flex justify-end',
              children: [
                MagicBuilder<bool>(
                  listenable: deleteAccountForm.processingListenable,
                  builder: (isProcessing) => WButton(
                    onTap: isProcessing ? null : _submitDeleteAccount,
                    isLoading: isProcessing,
                    className:
                        'px-4 py-2 rounded-lg bg-red-600 hover:bg-red-700 dark:bg-red-700 dark:hover:bg-red-600 text-white text-sm font-medium',
                    child: WText(
                      trans('magic_starter.profile.delete_account.button'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Submit delete account form.
  Future<void> _submitDeleteAccount() async {
    if (!deleteAccountForm.validate()) return;
    await deleteAccountForm.process(() => controller.withoutNotifying(
          () => controller.doDeleteAccount(
            password: deleteAccountForm.get('password'),
          ),
        ));
  }

  // -- Email Verification Section -----------------------------------------------

  // -- Guest Upgrade Section --------------------------------------------------

  /// Builds the guest account upgrade section.
  ///
  /// Visible only when the user is denied `starter.delete-account` (i.e. is a
  /// guest). Allows the guest to set an email and password to convert their
  /// account into a full membership.
  Widget _buildGuestUpgradeSection() {
    // Only show for guests — inverse of the delete-account Gate.
    if (Gate.allows('starter.delete-account')) {
      return const SizedBox.shrink();
    }

    return MagicForm(
      formData: upgradeForm,
      child: MagicStarterCard(
        title: trans('magic_starter.guest_upgrade.title'),
        child: WDiv(
          className: 'flex flex-col gap-4',
          children: [
            WText(
              trans('magic_starter.guest_upgrade.description'),
              className: 'text-sm text-gray-600 dark:text-gray-400',
            ),
            WFormInput(
              controller: upgradeForm['email'],
              label: trans('attributes.email'),
              type: InputType.email,
              validator: rules([Required(), Email()], field: 'email'),
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
            ),
            WFormInput(
              controller: upgradeForm['password'],
              label: trans('attributes.password'),
              type:
                  _obscureUpgradePassword ? InputType.password : InputType.text,
              validator: rules([Required(), Min(8)], field: 'password'),
              suffix: WAnchor(
                onTap: () => setState(
                    () => _obscureUpgradePassword = !_obscureUpgradePassword),
                child: WIcon(
                  _obscureUpgradePassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
            ),
            WFormInput(
              controller: upgradeForm['password_confirmation'],
              label: trans('attributes.password_confirmation'),
              type: _obscureUpgradeConfirmation
                  ? InputType.password
                  : InputType.text,
              validator: rules([Required()], field: 'password_confirmation'),
              suffix: WAnchor(
                onTap: () => setState(() =>
                    _obscureUpgradeConfirmation = !_obscureUpgradeConfirmation),
                child: WIcon(
                  _obscureUpgradeConfirmation
                      ? Icons.visibility
                      : Icons.visibility_off,
                  className: 'text-gray-400 text-xl',
                ),
              ),
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
            ),
            WDiv(
              className: 'flex justify-end',
              children: [
                MagicBuilder<bool>(
                  listenable: upgradeForm.processingListenable,
                  builder: (isProcessing) => WButton(
                    onTap: isProcessing ? null : _submitGuestUpgrade,
                    isLoading: isProcessing,
                    className:
                        'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
                    child: WText(trans('magic_starter.guest_upgrade.button')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Submits the guest upgrade form — converts the guest to a full account.
  Future<void> _submitGuestUpgrade() async {
    if (!upgradeForm.validate()) return;
    final success = await upgradeForm.process(() => controller.withoutNotifying(
          () => controller.doUpdateProfile(
            name: profileForm.get('name'),
            email: upgradeForm.get('email'),
            phone: profileForm.get('phone'),
            timezone: profileForm.get('timezone'),
            language: profileForm.get('language'),
            password: upgradeForm.get('password'),
            passwordConfirmation: upgradeForm.get('password_confirmation'),
          ),
        ));
    if (success) {
      Magic.reload();
      return;
    }
    _rebuildIfValidationErrors();
  }
}
