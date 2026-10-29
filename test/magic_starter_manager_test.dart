import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarterManager', () {
    late MagicStarterManager manager;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('magic_starter', () => MagicStarterManager());
      manager = Magic.make<MagicStarterManager>('magic_starter');
    });

    group('socialAuth', () {
      test('is null by default', () {
        expect(manager.socialAuth, isNull);
      });

      test('reset() clears the registered bridge', () {
        manager.socialAuth = _SilentSocialAuth();

        manager.reset();

        expect(manager.socialAuth, isNull);
      });
    });

    group('unified theme', () {
      test('setting theme updates individual sub-theme getters', () {
        const customForm = MagicStarterFormTheme(
          inputClassName: 'custom-input-class',
        );
        const customCard = MagicStarterCardTheme(borderRadius: 'rounded-xl');

        final unified = MagicStarterTheme(form: customForm, card: customCard);

        manager.theme = unified;

        expect(manager.formTheme.inputClassName, 'custom-input-class');
        expect(manager.cardTheme.borderRadius, 'rounded-xl');
      });

      test('setting individual formTheme is reflected in theme.form', () {
        const customForm = MagicStarterFormTheme(
          primaryButtonClassName: 'custom-btn',
        );

        manager.formTheme = customForm;

        expect(manager.theme.form.primaryButtonClassName, 'custom-btn');
      });

      test(
        'setting navigationTheme still works and is reflected in theme.navigation',
        () {
          const customNav = MagicStarterNavigationTheme(
            activeItemClassName: 'active:text-amber-500',
          );

          manager.navigationTheme = customNav;

          expect(
            manager.theme.navigation.activeItemClassName,
            'active:text-amber-500',
          );
          expect(
            manager.navigationTheme.activeItemClassName,
            'active:text-amber-500',
          );
        },
      );

      test('setting theme distributes the dropdown sub-theme', () {
        manager.theme = const MagicStarterTheme(
          dropdown: MagicStarterDropdownTheme(panelClassName: 'custom-panel'),
        );

        expect(manager.dropdownTheme.panelClassName, 'custom-panel');
        expect(manager.theme.dropdown.panelClassName, 'custom-panel');
      });

      test('setting dropdownTheme is reflected in theme.dropdown', () {
        manager.dropdownTheme = const MagicStarterDropdownTheme(
          textClassName: 'custom-text',
        );

        expect(manager.theme.dropdown.textClassName, 'custom-text');
      });

      test('setting theme distributes the button sub-theme', () {
        manager.theme = const MagicStarterTheme(
          button: MagicStarterButtonTheme(shapeClassName: 'rounded-full'),
        );

        expect(manager.buttonTheme.shapeClassName, 'rounded-full');
        expect(manager.theme.button.shapeClassName, 'rounded-full');
      });

      test('setting buttonTheme is reflected in theme.button', () {
        manager.buttonTheme = const MagicStarterButtonTheme(
          mdClassName: 'custom-md',
        );

        expect(manager.theme.button.mdClassName, 'custom-md');
      });

      test('setting theme distributes the field sub-theme', () {
        manager.theme = const MagicStarterTheme(
          field: MagicStarterFieldTheme(segmentedPaddingClassName: 'p-0'),
        );

        expect(manager.fieldTheme.segmentedPaddingClassName, 'p-0');
        expect(manager.theme.field.segmentedPaddingClassName, 'p-0');
      });

      test('setting fieldTheme is reflected in theme.field', () {
        manager.fieldTheme = const MagicStarterFieldTheme(
          inputSizeClassName: 'custom-input-size',
        );

        expect(manager.theme.field.inputSizeClassName, 'custom-input-size');
      });

      test('reset() clears all theme fields to const defaults', () {
        manager.theme = MagicStarterTheme(
          form: const MagicStarterFormTheme(inputClassName: 'custom-input'),
          card: const MagicStarterCardTheme(borderRadius: 'rounded-none'),
          navigation: const MagicStarterNavigationTheme(
            activeItemClassName: 'active:text-red-500',
          ),
          auth: const MagicStarterAuthTheme(titleClassName: 'custom-title'),
          pageHeader: const MagicStarterPageHeaderTheme(
            titleClassName: 'custom-header',
          ),
          layout: const MagicStarterLayoutTheme(sidebarWidth: 300),
          dropdown: const MagicStarterDropdownTheme(
            panelClassName: 'custom-panel',
          ),
          button: const MagicStarterButtonTheme(shapeClassName: 'rounded-full'),
          field: const MagicStarterFieldTheme(
            inputSizeClassName: 'custom-input-size',
          ),
        );

        manager.reset();

        expect(
          manager.formTheme.inputClassName,
          'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
        );
        expect(manager.cardTheme.borderRadius, 'rounded-2xl');
        expect(
          manager.navigationTheme.activeItemClassName,
          'active:text-primary active:bg-primary/10 dark:active:bg-primary/10',
        );
        expect(
          manager.authTheme.titleClassName,
          'text-2xl font-bold text-gray-900 dark:text-white text-center',
        );
        expect(
          manager.pageHeaderTheme.titleClassName,
          'text-2xl font-bold text-gray-900 dark:text-white line-clamp-2',
        );
        expect(manager.layoutTheme.sidebarWidth, 256);
        expect(
          manager.dropdownTheme.panelClassName,
          'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700',
        );
        expect(manager.buttonTheme.shapeClassName, 'rounded-lg');
        expect(
          manager.fieldTheme.inputSizeClassName,
          'py-3 lg:py-2.5 text-sm leading-5',
        );
      });

      test('convenience getters return correct sub-themes after theme set', () {
        const customAuth = MagicStarterAuthTheme(cardClassName: 'custom-card');
        const customPageHeader = MagicStarterPageHeaderTheme(
          titleClassName: 'custom-title',
        );
        const customLayout = MagicStarterLayoutTheme(sidebarWidth: 320);
        const customNav = MagicStarterNavigationTheme(
          brandClassName: 'custom-brand',
        );

        manager.theme = MagicStarterTheme(
          auth: customAuth,
          pageHeader: customPageHeader,
          layout: customLayout,
          navigation: customNav,
        );

        expect(manager.authTheme.cardClassName, 'custom-card');
        expect(manager.pageHeaderTheme.titleClassName, 'custom-title');
        expect(manager.layoutTheme.sidebarWidth, 320);
        expect(manager.navigationTheme.brandClassName, 'custom-brand');
      });
    });
  });
}

/// A bridge that is only ever registered, never driven.
class _SilentSocialAuth implements MagicStarterSocialAuth {
  @override
  List<String> providers() => const [];

  @override
  String label(String provider) => provider;

  @override
  Widget icon(String provider) => const SizedBox();

  @override
  Future<Map<String, dynamic>> signIn(String provider) =>
      throw UnimplementedError();

  @override
  Future<Future<Map<String, dynamic>> Function()> beginConnect(
    String provider,
    Map<String, String> proof,
  ) => throw UnimplementedError();

  @override
  Future<String> confirm(String provider) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}
