import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../http/controllers/profile_controller.dart';
import '../../widgets/starter_page_header.dart';

class MagicStarterProfileSettingsView
    extends MagicStatefulView<ProfileController> {
  const MagicStarterProfileSettingsView({super.key});

  @override
  State<MagicStarterProfileSettingsView> createState() =>
      _MagicStarterProfileSettingsViewState();
}

class _MagicStarterProfileSettingsViewState extends MagicStatefulViewState<
    ProfileController, MagicStarterProfileSettingsView> {
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
        _buildProfileSection(),
        _buildPasswordSection(),
      ],
    );
  }

  // -- Profile Section --------------------------------------------------------

  Widget _buildProfileSection() {
    return MagicForm(
      formData: profileForm,
      child: WDiv(
        className:
            'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl p-6 flex flex-col gap-4',
        children: [
          WText(
            trans('profile.profile_information'),
            className: 'text-lg font-semibold text-gray-900 dark:text-white',
          ),

          // Name
          WFormInput(
            controller: profileForm['name'],
            label: trans('attributes.name'),
            validator: rules([Required(), Min(2)], field: 'name'),
            prefix: WIcon(
              Icons.person_outline,
              className: 'text-primary text-xl',
            ),
            labelClassName:
                'text-sm font-medium text-gray-700 dark:text-gray-300 mb-2',
            className:
                'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 focus:border-primary error:border-red-500',
          ),

          // Email
          WFormInput(
            controller: profileForm['email'],
            label: trans('attributes.email'),
            type: InputType.email,
            validator: rules([Required(), Email()], field: 'email'),
            prefix: WIcon(
              Icons.mail_outline,
              className: 'text-primary text-xl',
            ),
            labelClassName:
                'text-sm font-medium text-gray-700 dark:text-gray-300 mb-2',
            className:
                'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 focus:border-primary error:border-red-500',
          ),

          WDiv(
            className: 'flex justify-end',
            children: [
              WButton(
                onTap: _submitProfile,
                isLoading: controller.isLoading,
                className:
                    'px-4 py-2 rounded-lg bg-primary hover:bg-green-600 dark:hover:bg-green-500 text-white text-sm font-medium',
                child: WText(trans('common.save')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -- Password Section -------------------------------------------------------

  Widget _buildPasswordSection() {
    return MagicForm(
      formData: passwordForm,
      child: WDiv(
        className:
            'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl p-6 flex flex-col gap-4',
        children: [
          WText(
            trans('profile.update_password'),
            className: 'text-lg font-semibold text-gray-900 dark:text-white',
          ),

          // Current Password
          WFormInput(
            controller: passwordForm['current_password'],
            label: trans('attributes.current_password'),
            type: _obscureCurrent ? InputType.password : InputType.text,
            validator: rules([Required()], field: 'current_password'),
            prefix: WIcon(
              Icons.lock_outline,
              className: 'text-primary text-xl',
            ),
            suffix: WAnchor(
              onTap: () => setState(() => _obscureCurrent = !_obscureCurrent),
              child: WIcon(
                _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                className: 'text-gray-400 text-xl',
              ),
            ),
            labelClassName:
                'text-sm font-medium text-gray-700 dark:text-gray-300 mb-2',
            className:
                'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 focus:border-primary error:border-red-500',
          ),

          // New Password
          WFormInput(
            controller: passwordForm['password'],
            label: trans('attributes.new_password'),
            type: _obscureNew ? InputType.password : InputType.text,
            validator: rules([Required(), Min(8)], field: 'password'),
            prefix: WIcon(
              Icons.lock_outline,
              className: 'text-primary text-xl',
            ),
            suffix: WAnchor(
              onTap: () => setState(() => _obscureNew = !_obscureNew),
              child: WIcon(
                _obscureNew ? Icons.visibility : Icons.visibility_off,
                className: 'text-gray-400 text-xl',
              ),
            ),
            labelClassName:
                'text-sm font-medium text-gray-700 dark:text-gray-300 mb-2',
            className:
                'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 focus:border-primary error:border-red-500',
          ),

          // Confirm Password
          WFormInput(
            controller: passwordForm['password_confirmation'],
            label: trans('attributes.password_confirmation'),
            type: _obscureConfirmation ? InputType.password : InputType.text,
            validator: rules([Required()], field: 'password_confirmation'),
            prefix: WIcon(
              Icons.lock_outline,
              className: 'text-primary text-xl',
            ),
            suffix: WAnchor(
              onTap: () =>
                  setState(() => _obscureConfirmation = !_obscureConfirmation),
              child: WIcon(
                _obscureConfirmation ? Icons.visibility : Icons.visibility_off,
                className: 'text-gray-400 text-xl',
              ),
            ),
            labelClassName:
                'text-sm font-medium text-gray-700 dark:text-gray-300 mb-2',
            className:
                'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 focus:border-primary error:border-red-500',
          ),

          WDiv(
            className: 'flex justify-end',
            children: [
              WButton(
                onTap: _submitPassword,
                isLoading: controller.isLoading,
                className:
                    'px-4 py-2 rounded-lg bg-primary hover:bg-green-600 dark:hover:bg-green-500 text-white text-sm font-medium',
                child: WText(trans('profile.update_password')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
