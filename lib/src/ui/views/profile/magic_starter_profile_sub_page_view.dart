import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_profile_controller.dart';
import '../../components/settings_section/index.dart';
import '../../components/settings_scaffold/index.dart';

/// Profile sub-page view (`profile.profile`).
///
/// The iOS-style Profile sub-page reached by drilling from the Settings hub.
/// It decomposes the largest part of the legacy long-form profile settings
/// view into a single grouped sub-page:
///
/// 1. **Profile Photo** — upload / remove via [doUpdateProfilePhoto] /
///    [doDeleteProfilePhoto].
/// 2. **Email Verification** — a banner with a resend button when the email is
///    unverified, or a verified badge otherwise ([sendEmailVerification]).
/// 3. **Profile Information** — name / email / phone / timezone / language form
///    submitting via [doUpdateProfile] (which calls [Auth.restore]).
/// 4. **Guest upgrade** — shown only for guests; converts a guest account.
/// 5. **Danger** — a destructive Delete Account row that opens the reused
///    password-confirm dialog and calls [doDeleteAccount].
///
/// Sections are gated by both [MagicStarterConfig] feature toggles and
/// `starter.*` [Gate] abilities, identical to the legacy view. Password, 2FA
/// and sessions management now live on their own Security sub-pages.
class MagicStarterProfileSubPageView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterProfileSubPageView({super.key});

  @override
  State<MagicStarterProfileSubPageView> createState() =>
      _MagicStarterProfileSubPageViewState();
}

class _MagicStarterProfileSubPageViewState extends MagicStatefulViewState<
    MagicStarterProfileController, MagicStarterProfileSubPageView> {
  static const _iconVisible = Icons.visibility;
  static const _iconHidden = Icons.visibility_off;

  // -- Forms ------------------------------------------------------------------

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

  // -- Section-level loading notifiers (isolated per section) ----------------

  /// Per-section loading notifiers prevent cross-section spinner leaks.
  ///
  /// The page shares a single [MagicStarterProfileController] whose
  /// [MagicStateMixin.isLoading] flag is global. These per-section notifiers
  /// decouple each section's loading indicator from the controller's global
  /// state, lifted verbatim from the legacy long-form profile view.
  final ValueNotifier<bool> _photoLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _emailVerificationLoading =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _profileSaveLoading = ValueNotifier<bool>(false);

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
  }

  @override
  void onClose() {
    profileForm.dispose();
    upgradeForm.dispose();
    _photoLoading.dispose();
    _emailVerificationLoading.dispose();
    _profileSaveLoading.dispose();
  }

  // -- Shared helpers ---------------------------------------------------------

  /// Execute [action] while driving the given [notifier] to `true`/`false`.
  ///
  /// Wraps the action in a try/finally so the notifier resets even on error.
  Future<T> _trackLoading<T>(
    ValueNotifier<bool> notifier,
    Future<T> Function() action,
  ) async {
    notifier.value = true;
    try {
      return await action();
    } finally {
      notifier.value = false;
    }
  }

  /// Re-triggers a rebuild + validation when the controller suppressed its
  /// own notification (so server-side validation errors surface in the form).
  void _rebuildIfValidationErrors([MagicFormData? form]) {
    if (controller.hasErrors) {
      setState(() {});
      (form ?? profileForm).formKey.currentState?.validate();
    }
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final headerSlot =
        MagicStarter.view.buildSlot('profile.profile', 'header', context);
    final footerSlot =
        MagicStarter.view.buildSlot('profile.profile', 'footer', context);

    final isGuest = Gate.denies('starter.delete-account');

    return MSSettingsScaffold(
      title: trans('profile.settings'),
      subtitle: trans('profile.settings_subtitle'),
      backLabel: trans('magic_starter.nav.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        if (headerSlot != null) headerSlot,

        // 1. Profile photo.
        if (MagicStarterConfig.hasProfilePhotoFeatures() &&
            Gate.allows('starter.update-profile-photo'))
          _buildProfilePhotoSection(),

        // 2. Email verification banner / badge.
        if (MagicStarterConfig.hasEmailVerificationFeatures() &&
            Gate.allows('starter.verify-email'))
          _buildEmailVerificationSection(),

        // 3. Profile information form.
        MagicForm(
          formData: profileForm,
          child: _buildProfileSection(),
        ),

        // 4. Guest upgrade (guests only). Account deletion lives on the
        //    Security > Browser Sessions sub-page (a destructive account action),
        //    not here, to keep the Profile form clean.
        if (isGuest) _buildGuestUpgradeSection(),

        if (footerSlot != null) footerSlot,
      ],
    );
  }

  // -- Profile Photo Section -------------------------------------------------

  Widget _buildProfilePhotoSection() {
    final user = Auth.user();
    final photoUrl = user?.get<String>('profile_photo_url');

    return MSSettingsSection(
      header: trans('profile.profile_photo'),
      children: [
        WDiv(
          className:
              'w-full flex flex-col sm:flex-row items-center gap-6 px-5 py-4',
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
                        className: 'w-full h-full bg-surface-container-high '
                            'flex items-center justify-center',
                        child: WIcon(
                          Icons.person_outline,
                          className: 'text-fg-muted text-3xl',
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
                    className: 'flex flex-col sm:flex-row items-stretch '
                        'sm:items-center gap-2 sm:gap-3',
                    children: [
                      WButton(
                        onTap: isLoading ? null : _handlePhotoUpload,
                        isLoading: isLoading,
                        className: 'px-4 py-2 rounded-lg bg-surface '
                            'border border-color-border hover:bg-surface-container '
                            'text-fg text-sm font-medium',
                        child: WText(trans('common.upload')),
                      ),
                      if (photoUrl != null && photoUrl.isNotEmpty)
                        WButton(
                          onTap: isLoading ? null : _handlePhotoRemove,
                          isLoading: isLoading,
                          className: 'px-4 py-2 rounded-lg bg-surface '
                              'border border-color-border '
                              'hover:bg-surface-container '
                              'text-destructive text-sm font-medium',
                          child: WText(trans('common.remove')),
                        ),
                    ],
                  ),
                ),
                WText(
                  trans('profile.photo_requirements'),
                  className: 'text-xs text-fg-muted',
                ),
              ],
            ),
          ],
        ),
      ],
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

  // -- Email Verification Section -------------------------------------------

  /// Builds the email verification status section.
  ///
  /// Shows a verified badge when the email is confirmed, or a warning banner
  /// with a resend button when unverified.
  Widget _buildEmailVerificationSection() {
    if (controller.isEmailVerified) {
      return MSSettingsSection(
        header: trans('magic_starter.email_verification.section_title'),
        children: [
          WDiv(
            className: 'flex items-center gap-3 px-5 py-4',
            children: [
              WIcon(
                Icons.verified,
                className: 'text-primary text-xl',
              ),
              WText(
                trans('magic_starter.email_verification.verified'),
                className: 'text-sm font-medium text-fg',
              ),
            ],
          ),
        ],
      );
    }

    return MSSettingsSection(
      header: trans('magic_starter.email_verification.section_title'),
      children: [
        WDiv(
          className: 'flex flex-col gap-4 px-5 py-4',
          children: [
            WDiv(
              className: 'flex items-start gap-3 p-3 rounded-lg '
                  'bg-surface-container-high border border-color-border',
              children: [
                WIcon(
                  Icons.warning_amber_rounded,
                  className: 'text-fg-muted text-xl mt-0.5',
                ),
                WDiv(
                  className: 'flex flex-col gap-1 flex-1',
                  children: [
                    WText(
                      trans(
                        'magic_starter.email_verification.unverified_title',
                      ),
                      className: 'text-sm font-semibold text-fg',
                    ),
                    WText(
                      trans(
                        'magic_starter.email_verification.unverified_description',
                      ),
                      className: 'text-sm text-fg-muted',
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
                className: 'self-start px-4 py-2 rounded-lg bg-primary '
                    'hover:bg-primary/80 text-white text-sm font-medium',
                child: WText(
                  trans('magic_starter.email_verification.resend_button'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Sends email verification with isolated loading state.
  Future<void> _handleSendEmailVerification() async {
    await _trackLoading(
      _emailVerificationLoading,
      () => controller.sendEmailVerification(),
    );
  }

  // -- Profile Information Section -------------------------------------------

  Widget _buildProfileSection() {
    final formTheme = MagicStarter.formTheme;
    final hasExtended = MagicStarterConfig.hasExtendedProfileFeatures();

    return WDiv(
      className: 'flex flex-col gap-6',
      children: [
        MSSettingsSection(
          header: trans('profile.profile_information'),
          children: [
            WDiv(
              className: 'flex flex-col gap-4 px-5 py-4',
              children: [
                WFormInput(
                  controller: profileForm['name'],
                  label: trans('attributes.name'),
                  validator: rules([Required(), Min(2)], field: 'name'),
                  labelClassName: formTheme.labelClassName,
                  className: formTheme.inputClassName,
                ),
                // Gate: guests cannot see/edit their email.
                if (Gate.allows('starter.update-email'))
                  WFormInput(
                    controller: profileForm['email'],
                    label: trans('attributes.email'),
                    type: InputType.email,
                    validator: rules([Required(), Email()], field: 'email'),
                    labelClassName: formTheme.labelClassName,
                    className: formTheme.inputClassName,
                  ),
                // Phone is part of the identity form; timezone and language are
                // their own dedicated Preferences sub-pages (reached from the
                // hub), so they are intentionally NOT duplicated here.
                if (hasExtended && Gate.allows('starter.update-phone'))
                  WFormInput(
                    controller: profileForm['phone'],
                    label: trans('profile.phone_label'),
                    placeholder: '+905301234567',
                    validator: rules([], field: 'phone'),
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
              listenable: _profileSaveLoading,
              builder: (isProcessing) => WButton(
                onTap: isProcessing ? null : _submitProfile,
                isLoading: isProcessing,
                className: 'px-4 py-2 rounded-lg bg-primary '
                    'hover:bg-primary/80 text-white text-sm font-medium',
                child: WText(trans('common.save')),
              ),
            ),
          ],
        ),
      ],
    );
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

  // -- Guest Upgrade Section --------------------------------------------------

  /// Builds the guest account upgrade section (guests only).
  Widget _buildGuestUpgradeSection() {
    final formTheme = MagicStarter.formTheme;

    return MagicForm(
      formData: upgradeForm,
      child: MSSettingsSection(
        header: trans('magic_starter.guest_upgrade.title'),
        children: [
          WDiv(
            className: 'flex flex-col gap-4 px-5 py-4',
            children: [
              WText(
                trans('magic_starter.guest_upgrade.description'),
                className: 'text-sm text-fg-muted',
              ),
              WFormInput(
                controller: upgradeForm['email'],
                label: trans('attributes.email'),
                type: InputType.email,
                validator: rules([Required(), Email()], field: 'email'),
                labelClassName: formTheme.labelClassName,
                className: formTheme.inputClassName,
              ),
              WFormInput(
                controller: upgradeForm['password'],
                label: trans('attributes.password'),
                type: _obscureUpgradePassword
                    ? InputType.password
                    : InputType.text,
                validator: rules([Required(), Min(8)], field: 'password'),
                suffix: WAnchor(
                  onTap: () => setState(
                    () => _obscureUpgradePassword = !_obscureUpgradePassword,
                  ),
                  child: WIcon(
                    _obscureUpgradePassword ? _iconVisible : _iconHidden,
                    className: 'text-fg-muted text-xl',
                  ),
                ),
                labelClassName: formTheme.labelClassName,
                className: formTheme.inputClassName,
              ),
              WFormInput(
                controller: upgradeForm['password_confirmation'],
                label: trans('attributes.password_confirmation'),
                type: _obscureUpgradeConfirmation
                    ? InputType.password
                    : InputType.text,
                validator: rules([Required()], field: 'password_confirmation'),
                suffix: WAnchor(
                  onTap: () => setState(
                    () => _obscureUpgradeConfirmation =
                        !_obscureUpgradeConfirmation,
                  ),
                  child: WIcon(
                    _obscureUpgradeConfirmation ? _iconVisible : _iconHidden,
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
                    listenable: upgradeForm.processingListenable,
                    builder: (isProcessing) => WButton(
                      onTap: isProcessing ? null : _submitGuestUpgrade,
                      isLoading: isProcessing,
                      className: 'px-4 py-2 rounded-lg bg-primary '
                          'hover:bg-primary/80 text-white text-sm font-medium',
                      child: WText(trans('magic_starter.guest_upgrade.button')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Submits the guest upgrade form — converts the guest to a full account.
  Future<void> _submitGuestUpgrade() async {
    if (!upgradeForm.validate()) return;
    final success = await upgradeForm.process(
      () => controller.withoutNotifying(
        () => controller.doUpdateProfile(
          name: profileForm.get('name'),
          email: upgradeForm.get('email'),
          phone: profileForm.get('phone'),
          timezone: profileForm.get('timezone'),
          language: profileForm.get('language'),
          password: upgradeForm.get('password'),
          passwordConfirmation: upgradeForm.get('password_confirmation'),
        ),
      ),
    );
    if (success) {
      Magic.reload();
      return;
    }
    _rebuildIfValidationErrors();
  }
}
