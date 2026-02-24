import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../http/controllers/profile_controller.dart';
import '../../widgets/starter_page_header.dart';
import '../../widgets/starter_card.dart';
import '../../../configuration/magic_starter_config.dart';

class MagicStarterProfileSettingsView
    extends MagicStatefulView<StarterProfileController> {
  const MagicStarterProfileSettingsView({super.key});

  @override
  State<MagicStarterProfileSettingsView> createState() =>
      _MagicStarterProfileSettingsViewState();
}

class _MagicStarterProfileSettingsViewState extends MagicStatefulViewState<
    StarterProfileController, MagicStarterProfileSettingsView> {
  late final profileForm = MagicFormData(
    {'name': '', 'email': ''},
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

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirmation = true;

  @override
  void onInit() {
    final user = Auth.user();
    if (user != null) {
      profileForm.set('name', user.get<String>('name') ?? '');
      profileForm.set('email', user.get<String>('email') ?? '');
    }
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() {
    profileForm.dispose();
    passwordForm.dispose();
  }

  Future<void> _submitProfile() async {
    if (!profileForm.validate()) return;
    await controller.doUpdateProfile(
      name: profileForm.get('name'),
      email: profileForm.get('email'),
    );
  }

  Future<void> _submitPassword() async {
    if (!passwordForm.validate()) return;
    final success = await controller.doUpdatePassword(
      currentPassword: passwordForm.get('current_password'),
      password: passwordForm.get('password'),
      passwordConfirmation: passwordForm.get('password_confirmation'),
    );
    if (success) {
      passwordForm.set('current_password', '');
      passwordForm.set('password', '');
      passwordForm.set('password_confirmation', '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(
          title: trans('profile.settings'),
          subtitle: trans('profile.settings_subtitle'),
        ),
        _buildProfilePhotoSection(),
        _buildProfileSection(),
        _buildPasswordSection(),
      ],
    );
  }

  // -- Profile Photo Section --------------------------------------------------

  Widget _buildProfilePhotoSection() {
    if (!MagicStarterConfig.hasProfilePhotoFeatures()) {
      return const SizedBox.shrink();
    }

    final user = Auth.user();
    final photoUrl = user?.get<String>('profile_photo_url');

    return MagicStarterCard(
      title: trans('profile.profile_photo'),
      child: WDiv(
        className: 'w-full flex flex-col sm:flex-row items-center gap-6',
        children: [
          // Avatar
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
                      className: 'w-full h-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center',
                      child: WIcon(
                        Icons.person_outline,
                        className: 'text-gray-400 text-3xl',
                      ),
                    ),
            ),
          ),
          // Actions
          WDiv(
            className: 'flex flex-col gap-2 min-w-0',
            children: [
              WDiv(
                className: 'flex flex-col sm:flex-row items-stretch sm:items-center gap-2 sm:gap-3',
                children: [
                  WButton(
                    onTap: _handlePhotoUpload,
                    isLoading: controller.isLoading,
                    className:
                        'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium',
                    child: WText(trans('common.upload')),
                  ),
                  if (photoUrl != null && photoUrl.isNotEmpty)
                    WButton(
                      onTap: _handlePhotoRemove,
                      isLoading: controller.isLoading,
                      className:
                          'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-red-200 dark:border-red-900/50 hover:bg-red-50 dark:hover:bg-red-900/20 text-red-600 dark:text-red-400 text-sm font-medium',
                      child: WText(trans('common.remove')),
                    ),
                ],
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
    await controller.doUpdateProfilePhoto(file: file);
  }

  Future<void> _handlePhotoRemove() async {
    await controller.doDeleteProfilePhoto();
  }

  // -- Profile Section --------------------------------------------------------

  Widget _buildProfileSection() {
    return MagicForm(
      formData: profileForm,
      child: MagicStarterCard(
        title: trans('profile.profile_information'),
        child: WDiv(
          className: 'flex flex-col gap-4',
          children: [
            // Name
          WFormInput(
            controller: profileForm['name'],
            label: trans('attributes.name'),
            validator: rules([Required(), Min(2)], field: 'name'),
            labelClassName: 'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            className: 'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
          ),

          // Email
          WFormInput(
            controller: profileForm['email'],
            label: trans('attributes.email'),
            type: InputType.email,
            validator: rules([Required(), Email()], field: 'email'),
            labelClassName: 'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            className: 'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
          ),

          WDiv(
            className: 'flex justify-end',
            children: [
              WButton(
                onTap: _submitProfile,
                isLoading: controller.isLoading,
                className: 'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
                child: WText(trans('common.save')),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  // -- Password Section -------------------------------------------------------

  Widget _buildPasswordSection() {
    return MagicForm(
      formData: passwordForm,
      child: MagicStarterCard(
        title: trans('profile.update_password'),
        child: WDiv(
          className: 'flex flex-col gap-4',
          children: [
            // Current Password
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
            labelClassName: 'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            className: 'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
          ),

          // New Password
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
            labelClassName: 'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            className: 'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
          ),

          // Confirm Password
          WFormInput(
            controller: passwordForm['password_confirmation'],
            label: trans('attributes.password_confirmation'),
            type: _obscureConfirmation ? InputType.password : InputType.text,
            validator: rules([Required()], field: 'password_confirmation'),
            suffix: WAnchor(
              onTap: () =>
                  setState(() => _obscureConfirmation = !_obscureConfirmation),
              child: WIcon(
                _obscureConfirmation ? Icons.visibility : Icons.visibility_off,
                className: 'text-gray-400 text-xl',
              ),
            ),
            labelClassName: 'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
            className: 'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
          ),

          WDiv(
            className: 'flex justify-end',
            children: [
              WButton(
                onTap: _submitPassword,
                isLoading: controller.isLoading,
                className: 'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
                child: WText(trans('profile.update_password')),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}
