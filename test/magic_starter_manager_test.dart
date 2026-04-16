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

    group('socialLoginBuilder', () {
      test('is null by default', () {
        expect(manager.socialLoginBuilder, isNull);
      });

      test('can be set and read back', () {
        Widget testBuilder(BuildContext context, bool isLoading) {
          return const SizedBox();
        }

        manager.socialLoginBuilder = testBuilder;

        expect(manager.socialLoginBuilder, equals(testBuilder));
      });

      test('reset() clears socialLoginBuilder', () {
        manager.socialLoginBuilder = (_, __) => const SizedBox();

        manager.reset();

        expect(manager.socialLoginBuilder, isNull);
      });
    });

    group('unified theme', () {
      test('setting theme updates individual sub-theme getters', () {
        const customForm = MagicStarterFormTheme(
          inputClassName: 'custom-input-class',
        );
        const customCard = MagicStarterCardTheme(
          borderRadius: 'rounded-xl',
        );

        final unified = MagicStarterTheme(
          form: customForm,
          card: customCard,
        );

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
        expect(manager.navigationTheme.activeItemClassName,
            'active:text-amber-500');
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
              titleClassName: 'custom-header'),
          layout: const MagicStarterLayoutTheme(sidebarWidth: 300),
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
          'text-2xl font-bold text-gray-900 dark:text-white truncate',
        );
        expect(manager.layoutTheme.sidebarWidth, 256);
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
