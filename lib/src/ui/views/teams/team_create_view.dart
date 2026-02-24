import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/team_controller.dart';
import '../../widgets/starter_page_header.dart';
import '../../widgets/starter_card.dart';

class MagicStarterTeamCreateView
    extends MagicStatefulView<StarterTeamController> {
  const MagicStarterTeamCreateView({super.key});

  @override
  State<MagicStarterTeamCreateView> createState() =>
      _MagicStarterTeamCreateViewState();
}

class _MagicStarterTeamCreateViewState extends MagicStatefulViewState<
    StarterTeamController, MagicStarterTeamCreateView> {
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
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(
          title: trans('teams.create_team'),
          subtitle: trans('teams.create_team_subtitle'),
        ),
        _buildForm(),
      ],
    );
  }

  Widget _buildForm() {
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
              labelClassName:
                  'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
              className:
                  'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
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
