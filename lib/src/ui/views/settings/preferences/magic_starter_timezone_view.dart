import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../http/controllers/magic_starter_profile_controller.dart';
import '../../../components/settings_scaffold/index.dart';
import '../../../components/settings_section/index.dart';
import '../../../widgets/magic_starter_timezone_select.dart';

/// Timezone settings sub-page — debounced timezone selector persisted to the
/// profile.
///
/// Reuses [MagicStarterTimezoneSelect] (the same debounced, API-backed select
/// from the long-form profile view) and saves the chosen identifier via
/// [MagicStarterProfileController.doUpdateProfile] (the `timezone` field). The
/// controller restores auth state on success.
///
/// `doUpdateProfile` requires `name` and `email`; both are carried over from
/// the current authenticated user so a timezone-only save does not blank them.
class MagicStarterTimezoneView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterTimezoneView({super.key});

  @override
  State<MagicStarterTimezoneView> createState() =>
      _MagicStarterTimezoneViewState();
}

class _MagicStarterTimezoneViewState extends MagicStatefulViewState<
    MagicStarterProfileController, MagicStarterTimezoneView> {
  /// Single-field form for the timezone identifier.
  late final form = MagicFormData(
    {'timezone': ''},
    controller: controller,
  );

  /// Isolated save-button spinner, decoupled from the controller's global
  /// loading flag (mirrors the source view's per-section notifier pattern).
  final ValueNotifier<bool> _saveLoading = ValueNotifier<bool>(false);

  @override
  void onInit() {
    final user = Auth.user();
    form.set('timezone', user?.get<String>('timezone') ?? '');
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() {
    form.dispose();
    _saveLoading.dispose();
  }

  /// Persists the selected timezone through the profile controller.
  ///
  /// Carries `name`/`email` from the current user since `doUpdateProfile`
  /// requires them; the controller restores auth state on success.
  Future<void> _submit() async {
    final user = Auth.user();
    _saveLoading.value = true;
    try {
      await controller.withoutNotifying(
        () => controller.doUpdateProfile(
          name: user?.get<String>('name') ?? '',
          email: user?.get<String>('email') ?? '',
          timezone: form.get('timezone'),
        ),
      );
    } finally {
      _saveLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MSSettingsScaffold(
      title: trans('profile.timezone_label'),
      subtitle: trans('magic_starter.timezone.subtitle'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        MSSettingsSection(
          children: [
            WDiv(
              className: 'flex flex-col gap-4 px-5 py-4',
              children: [
                MagicStarterTimezoneSelect(
                  value: form.get('timezone'),
                  onChanged: (v) =>
                      setState(() => form.set('timezone', v ?? '')),
                  label: trans('profile.timezone_label'),
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
              listenable: _saveLoading,
              builder: (isSaving) => WButton(
                onTap: isSaving ? null : _submit,
                isLoading: isSaving,
                className:
                    'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-on-primary text-sm font-medium',
                child: WText(trans('common.save')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
