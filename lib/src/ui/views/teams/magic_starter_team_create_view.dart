import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_team_controller.dart';
import '../../widgets/magic_starter_page_header.dart';
import '../../widgets/magic_starter_card.dart';

class MagicStarterTeamCreateView
    extends MagicStatefulView<MagicStarterTeamController> {
  const MagicStarterTeamCreateView({super.key});

  @override
  State<MagicStarterTeamCreateView> createState() =>
      _MagicStarterTeamCreateViewState();
}

class _MagicStarterTeamCreateViewState extends MagicStatefulViewState<
    MagicStarterTeamController, MagicStarterTeamCreateView> {
  late final form = MagicFormData(
    {'name': ''},
    controller: controller,
  );

  @override
  void onInit() {
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() => form.dispose();

  Future<void> _submit() async {
    if (!form.validate()) return;

    final success = await controller.doCreate(name: form.get('name'));
    if (success) {
      MagicRoute.to(MagicStarterConfig.teamSettingsRoute());
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerSlot =
        MagicStarter.view.buildSlot('teams.create', 'header', context);
    final footerSlot =
        MagicStarter.view.buildSlot('teams.create', 'footer', context);

    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        if (headerSlot != null) headerSlot,
        MagicStarterPageHeader(
          title: trans('teams.create_team'),
          subtitle: trans('teams.create_team_subtitle'),
        ),
        _buildForm(),
        if (footerSlot != null) footerSlot,
      ],
    );
  }

  Widget _buildForm() {
    final formTheme = MagicStarter.formTheme;

    return MagicForm(
      formData: form,
      child: MagicStarterCard(
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
                  child: WText(trans('teams.create_team')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
