import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_team_controller.dart';
import '../../widgets/magic_starter_card.dart';
import '../../widgets/magic_starter_confirm_dialog.dart';
import '../../widgets/magic_starter_page_header.dart';

class MagicStarterTeamSettingsView
    extends MagicStatefulView<MagicStarterTeamController> {
  const MagicStarterTeamSettingsView({super.key});

  @override
  State<MagicStarterTeamSettingsView> createState() =>
      _MagicStarterTeamSettingsViewState();
}

class _MagicStarterTeamSettingsViewState extends MagicStatefulViewState<
    MagicStarterTeamController, MagicStarterTeamSettingsView> {
  late final MagicFormData form = MagicFormData(
    {'name': ''},
    controller: controller,
  );

  late final MagicFormData inviteForm = MagicFormData(
    {'email': '', 'role': 'member'},
    controller: controller,
  );

  @override
  void onInit() {
    final teamName = controller.activeTeamName;
    if (teamName != null && teamName.isNotEmpty) {
      form.set('name', teamName);
    }
    controller.loadMembersAndInvitations();
  }

  @override
  void onClose() {
    form.dispose();
    inviteForm.dispose();
  }

  Future<void> _submit() async {
    if (!form.validate()) return;
    await controller.doUpdate(name: form.get('name'));
  }

  Future<void> _sendInvite() async {
    if (!inviteForm.validate()) return;

    final success = await controller.doInvite(
      email: inviteForm.get('email'),
      role: inviteForm.get('role'),
    );

    if (success) {
      inviteForm.set('email', '');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!MagicStarterConfig.hasTeamFeatures()) {
      return WDiv(
        key: const ValueKey('teams-feature-disabled'),
        className: 'flex items-center justify-center p-6',
        child: WText(
          trans('teams.feature_disabled'),
          className: 'text-sm text-gray-600 dark:text-gray-300',
        ),
      );
    }

    final headerSlot =
        MagicStarter.view.buildSlot('teams.settings', 'header', context);
    final footerSlot =
        MagicStarter.view.buildSlot('teams.settings', 'footer', context);
    final afterMembersSlot = MagicStarter.view
        .buildSlot('teams.settings', 'afterSection:members', context);

    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        if (headerSlot != null) headerSlot,
        MagicStarterPageHeader(
          title: trans('teams.settings'),
          subtitle: trans('teams.settings_subtitle'),
        ),
        _buildGeneralSection(),
        _buildMembersSection(),
        if (afterMembersSlot != null) afterMembersSlot,
        if (footerSlot != null) footerSlot,
      ],
    );
  }

  // -- General Section --------------------------------------------------------

  Widget _buildGeneralSection() {
    final formTheme = MagicStarter.formTheme;

    return MagicForm(
      formData: form,
      child: MagicStarterCard(
        title: trans('teams.general_settings'),
        child: WDiv(
          className: 'flex flex-col gap-4',
          children: [
            WFormInput(
              controller: form['name'],
              label: trans('teams.team_name'),
              validator: rules([Required(), Min(2), Max(255)], field: 'name'),
              labelClassName: formTheme.labelClassName,
              className: formTheme.inputClassName,
            ),
            WDiv(
              className: 'flex justify-end',
              children: [
                WButton(
                  onTap: _submit,
                  isLoading: controller.isLoading,
                  className:
                      'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
                  child: WText(trans('common.save')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -- Members Section --------------------------------------------------------

  Widget _buildMembersSection() {
    return WDiv(
      className: 'flex flex-col gap-6',
      children: [
        // Members list
        ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: controller.members,
          builder: (context, members, _) {
            if (members.isEmpty) {
              return MagicStarterCard(
                child: WDiv(
                  className: 'w-full flex flex-col items-center gap-2 py-4',
                  children: [
                    WIcon(
                      Icons.group_outlined,
                      className: 'text-[32px] text-gray-300 dark:text-gray-600',
                    ),
                    WText(
                      trans('teams.no_members'),
                      className: 'text-sm text-gray-500 dark:text-gray-400',
                    ),
                  ],
                ),
              );
            }

            return MagicStarterCard(
              title: trans('teams.current_members'),
              noPadding: true,
              child: WDiv(
                className: 'flex flex-col',
                children: [
                  ...members.map((member) => _buildMemberRow(member)),
                ],
              ),
            );
          },
        ),

        // Pending invitations
        ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: controller.invitations,
          builder: (context, invitations, _) {
            if (invitations.isEmpty) {
              return MagicStarterCard(
                child: WDiv(
                  className: 'w-full flex flex-col items-center gap-2 py-4',
                  children: [
                    WIcon(
                      Icons.mail_outline,
                      className: 'text-[32px] text-gray-300 dark:text-gray-600',
                    ),
                    WText(
                      trans('teams.no_invitations'),
                      className: 'text-sm text-gray-500 dark:text-gray-400',
                    ),
                  ],
                ),
              );
            }

            return MagicStarterCard(
              title: trans('teams.pending_invitations'),
              noPadding: true,
              child: WDiv(
                className: 'flex flex-col',
                children: [
                  ...invitations
                      .map((invitation) => _buildInvitationRow(invitation)),
                ],
              ),
            );
          },
        ),

        // Invite form
        Builder(
          builder: (context) {
            final formTheme = MagicStarter.formTheme;

            return MagicForm(
              formData: inviteForm,
              child: MagicStarterCard(
                title: trans('teams.invite_member'),
                child: WDiv(
                  className: 'flex flex-col gap-4',
                  children: [
                    WFormInput(
                      controller: inviteForm['email'],
                      label: trans('attributes.email'),
                      type: InputType.email,
                      validator: rules([Required(), Email()], field: 'email'),
                      labelClassName: formTheme.labelClassName,
                      className: formTheme.inputClassName,
                    ),
                    WFormSelect<String>(
                      value: inviteForm.get('role'),
                      label: trans('attributes.role'),
                      options: [
                        SelectOption(
                          value: 'member',
                          label: trans('teams.role_member'),
                        ),
                        SelectOption(
                          value: 'admin',
                          label: trans('teams.role_admin'),
                        ),
                      ],
                      onChange: (value) =>
                          inviteForm.set('role', value ?? 'member'),
                      labelClassName: formTheme.labelClassName,
                      className: formTheme.inputClassName,
                      menuClassName:
                          'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700',
                    ),
                    WDiv(
                      className: 'flex justify-end',
                      children: [
                        WButton(
                          onTap: _sendInvite,
                          isLoading: controller.isLoading,
                          className:
                              MagicStarter.modalTheme.primaryButtonClassName,
                          child: WText(trans('teams.send_invite')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // -- Member Row -------------------------------------------------------------

  Widget _buildMemberRow(Map<String, dynamic> member) {
    final name = member['name'] as String? ?? '';
    final email = member['email'] as String? ?? '';
    final role = member['role'] as String? ?? 'member';
    final memberId = member['id'];
    final isOwner = role == 'owner';

    return WDiv(
      className:
          'px-6 py-4 flex items-center justify-between border-b border-gray-100 dark:border-gray-700',
      children: [
        Expanded(
          child: WDiv(
            className: 'flex items-center gap-3 min-w-0',
            children: [
              WDiv(
                className:
                    'w-10 h-10 rounded-full bg-gray-200 dark:bg-gray-700 flex items-center justify-center',
                child: WText(
                  name.isNotEmpty
                      ? name[0].toUpperCase()
                      : trans('common.unknown'),
                  className:
                      'text-sm font-semibold text-gray-600 dark:text-gray-300',
                ),
              ),
              Expanded(
                child: WDiv(
                  className: 'flex flex-col min-w-0',
                  children: [
                    WText(
                      name,
                      className:
                          'text-sm font-medium text-gray-900 dark:text-white truncate',
                    ),
                    WText(
                      email,
                      className:
                          'text-xs text-gray-500 dark:text-gray-400 truncate',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        WDiv(
          className: 'flex items-center gap-2',
          children: [
            WDiv(
              className: isOwner
                  ? 'px-2 py-1 rounded-md text-xs font-medium bg-primary/10 dark:bg-primary/10 text-primary dark:text-primary'
                  : 'px-2 py-1 rounded-md text-xs font-medium bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300',
              child: WText(_roleLabel(role)),
            ),
            if (!isOwner)
              WAnchor(
                onTap: () async {
                  final confirmed = await MagicStarterConfirmDialog.show(
                    context,
                    title: trans('teams.remove_member_label'),
                    description: trans('teams.confirm_remove_member'),
                    confirmLabel: trans('teams.remove'),
                    variant: ConfirmDialogVariant.danger,
                  );
                  if (confirmed == true) {
                    controller.removeMember(memberId);
                  }
                },
                child: WIcon(
                  Icons.close,
                  semanticLabel: trans('teams.remove_member_label'),
                  className: 'text-[18px] text-gray-400 hover:text-red-500',
                ),
              ),
          ],
        ),
      ],
    );
  }

  // -- Invitation Row ---------------------------------------------------------

  Widget _buildInvitationRow(Map<String, dynamic> invitation) {
    final email = invitation['email'] as String? ?? '';
    final role = invitation['role'] as String? ?? 'member';
    final invitationId = invitation['id'];

    return WDiv(
      className:
          'px-6 py-4 flex items-center justify-between border-b border-gray-100 dark:border-gray-700',
      children: [
        Expanded(
          child: WDiv(
            className: 'flex items-center gap-3 min-w-0',
            children: [
              WDiv(
                className:
                    'w-10 h-10 rounded-full bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center',
                child: WIcon(
                  Icons.mail_outline,
                  className: 'text-[18px] text-amber-600 dark:text-amber-400',
                ),
              ),
              Expanded(
                child: WDiv(
                  className: 'flex flex-col min-w-0',
                  children: [
                    WText(
                      email,
                      className:
                          'text-sm font-medium text-gray-900 dark:text-white truncate',
                    ),
                    WText(
                      trans('teams.pending'),
                      className: 'text-xs text-amber-600 dark:text-amber-400',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        WDiv(
          className: 'flex items-center gap-2',
          children: [
            WDiv(
              className:
                  'px-2 py-1 rounded-md bg-gray-100 dark:bg-gray-700 text-xs font-medium text-gray-600 dark:text-gray-300',
              child: WText(_roleLabel(role)),
            ),
            WAnchor(
              onTap: () async {
                final confirmed = await MagicStarterConfirmDialog.show(
                  context,
                  title: trans('teams.cancel_invite_label'),
                  description: trans('teams.confirm_cancel_invite'),
                  variant: ConfirmDialogVariant.danger,
                );
                if (confirmed == true) {
                  controller.cancelInvitation(invitationId);
                }
              },
              child: WIcon(
                Icons.close,
                semanticLabel: trans('teams.cancel_invite_label'),
                className: 'text-[18px] text-gray-400 hover:text-red-500',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _roleLabel(String role) {
    final key = 'teams.role_$role';
    final translated = trans(key);

    if (translated == key) {
      if (role.isEmpty) return role;
      return '${role[0].toUpperCase()}${role.substring(1)}';
    }

    return translated;
  }
}
