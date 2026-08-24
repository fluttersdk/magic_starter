import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../facades/magic_starter.dart';
import '../../../../http/controllers/magic_starter_profile_controller.dart';
import '../../../components/page_scaffold/index.dart';
import '../../../components/settings_section/index.dart';

/// Language settings sub-page — locale selector persisted to the profile.
///
/// Reuses [WFormSelect] with [MagicStarterManager.localeOptions] (mirroring the
/// long-form profile view's language section) and saves the chosen locale via
/// [MagicStarterProfileController.doUpdateProfile] (the `language` field). The
/// controller calls `Auth.restore()` after a successful update, so no extra
/// session sync is needed here.
///
/// `doUpdateProfile` requires `name` and `email`; both are carried over from
/// the current authenticated user so a locale-only save does not blank them.
class MagicStarterLanguageView
    extends MagicStatefulView<MagicStarterProfileController> {
  const MagicStarterLanguageView({super.key});

  @override
  State<MagicStarterLanguageView> createState() =>
      _MagicStarterLanguageViewState();
}

class _MagicStarterLanguageViewState
    extends
        MagicStatefulViewState<
          MagicStarterProfileController,
          MagicStarterLanguageView
        > {
  /// Single-field form for the locale value.
  late final form = MagicFormData({'language': ''}, controller: controller);

  /// Isolated save-button spinner, decoupled from the controller's global
  /// loading flag (mirrors the source view's per-section notifier pattern).
  final ValueNotifier<bool> _saveLoading = ValueNotifier<bool>(false);

  @override
  void onInit() {
    final user = Auth.user();
    form.set('language', user?.get<String>('locale') ?? '');
    controller.clearErrors();
    controller.setEmpty();
  }

  @override
  void onClose() {
    form.dispose();
    _saveLoading.dispose();
  }

  /// Resolves the configured locale options, falling back to en/tr.
  List<SelectOption<String>> _localeOptions() {
    final locales = MagicStarter.manager.localeOptions;
    if (locales.isNotEmpty) {
      return locales;
    }
    return [
      SelectOption<String>(value: 'en', label: 'English'),
      SelectOption<String>(value: 'tr', label: 'Türkçe'),
    ];
  }

  /// Persists the selected locale through the profile controller.
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
          language: form.get('language'),
        ),
      );
    } finally {
      _saveLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formTheme = MagicStarter.formTheme;

    return MSPageScaffold(
      title: trans('profile.language_label'),
      subtitle: trans('magic_starter.language.subtitle'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        MSSettingsSection(
          children: [
            WDiv(
              className: 'flex flex-col gap-4 px-5 py-4',
              children: [
                WFormSelect<String>(
                  value: form.get('language'),
                  onChange: (v) =>
                      setState(() => form.set('language', v ?? '')),
                  label: trans('profile.language_label'),
                  options: _localeOptions(),
                  labelClassName: formTheme.labelClassName,
                  className: formTheme.inputClassName,
                  menuClassName:
                      'bg-surface-container border border-color-border rounded-xl shadow-xl',
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
