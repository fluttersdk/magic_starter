import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarter facade', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('magic_starter', () => MagicStarterManager());
    });

    group('social login', () {
      test('hasSocialLogin returns false when not configured', () {
        expect(MagicStarter.hasSocialLogin, isFalse);
      });

      test('socialLoginBuilder returns null when not configured', () {
        expect(MagicStarter.socialLoginBuilder, isNull);
      });

      test('useSocialLogin() sets the builder on the manager', () {
        Widget testBuilder(BuildContext context, bool isLoading) {
          return const SizedBox();
        }

        MagicStarter.useSocialLogin(testBuilder);

        expect(MagicStarter.manager.socialLoginBuilder, equals(testBuilder));
      });

      test('hasSocialLogin returns true after useSocialLogin()', () {
        MagicStarter.useSocialLogin((_, __) => const SizedBox());

        expect(MagicStarter.hasSocialLogin, isTrue);
      });

      test('socialLoginBuilder returns the registered builder', () {
        Widget testBuilder(BuildContext context, bool isLoading) {
          return const SizedBox();
        }

        MagicStarter.useSocialLogin(testBuilder);

        expect(MagicStarter.socialLoginBuilder, equals(testBuilder));
      });
    });

    group('navigation theme', () {
      test('navigationTheme returns default instance when not configured', () {
        final theme = MagicStarter.navigationTheme;

        expect(
          theme.activeItemClassName,
          'active:text-primary active:bg-primary/10 dark:active:bg-primary/10',
        );
        expect(
          theme.hoverItemClassName,
          'hover:bg-gray-100 dark:hover:bg-gray-800',
        );
        expect(theme.brandClassName, 'text-lg font-bold text-primary');
        expect(theme.brandBuilder, isNull);
        expect(theme.bottomNavActiveClassName, 'active:text-primary');
        expect(theme.avatarClassName, 'bg-primary/10 dark:bg-primary/10');
        expect(theme.avatarTextClassName, 'text-sm font-bold text-primary');
        expect(
          theme.dropdownAvatarClassName,
          'bg-gradient-to-tr from-primary to-gray-200',
        );
      });

      test('useNavigationTheme() stores theme on manager', () {
        const customTheme = MagicStarterNavigationTheme(
          activeItemClassName:
              'active:text-amber-500 active:bg-amber-500/10 dark:active:text-amber-400 dark:active:bg-amber-400/10',
        );

        MagicStarter.useNavigationTheme(customTheme);

        expect(MagicStarter.manager.navigationTheme, equals(customTheme));
      });

      test('navigationTheme getter returns the registered theme', () {
        const customTheme = MagicStarterNavigationTheme(
          activeItemClassName: 'active:text-red-500 active:bg-red-500/10',
          hoverItemClassName: 'hover:bg-red-50 dark:hover:bg-red-900',
        );

        MagicStarter.useNavigationTheme(customTheme);

        expect(MagicStarter.navigationTheme, equals(customTheme));
        expect(
          MagicStarter.navigationTheme.activeItemClassName,
          'active:text-red-500 active:bg-red-500/10',
        );
        expect(
          MagicStarter.navigationTheme.hoverItemClassName,
          'hover:bg-red-50 dark:hover:bg-red-900',
        );
      });

      test('useNavigationTheme() with brandBuilder stores builder', () {
        Widget testBrand(BuildContext context) => const SizedBox();

        final customTheme = MagicStarterNavigationTheme(
          brandBuilder: testBrand,
        );

        MagicStarter.useNavigationTheme(customTheme);

        expect(
          MagicStarter.navigationTheme.brandBuilder,
          equals(testBrand),
        );
      });

      test('MagicStarterNavigationTheme preserves all custom field values', () {
        Widget testBrand(BuildContext context) => const SizedBox();

        const customActive = 'active:text-purple-500 active:bg-purple-500/10';
        const customHover = 'hover:bg-purple-50 dark:hover:bg-purple-900/20';
        const customBrand = 'text-xl font-black text-purple-600';
        const customBottomNav =
            'active:text-purple-500 dark:active:text-purple-400';
        const customAvatar = 'bg-purple-500/10 dark:bg-purple-400/10';
        const customAvatarText =
            'text-sm font-bold text-purple-600 dark:text-purple-400';
        const customDropdown =
            'bg-gradient-to-tr from-purple-500 to-purple-300';

        final theme = MagicStarterNavigationTheme(
          activeItemClassName: customActive,
          hoverItemClassName: customHover,
          brandClassName: customBrand,
          brandBuilder: testBrand,
          bottomNavActiveClassName: customBottomNav,
          avatarClassName: customAvatar,
          avatarTextClassName: customAvatarText,
          dropdownAvatarClassName: customDropdown,
        );

        expect(theme.activeItemClassName, customActive);
        expect(theme.hoverItemClassName, customHover);
        expect(theme.brandClassName, customBrand);
        expect(theme.brandBuilder, equals(testBrand));
        expect(theme.bottomNavActiveClassName, customBottomNav);
        expect(theme.avatarClassName, customAvatar);
        expect(theme.avatarTextClassName, customAvatarText);
        expect(theme.dropdownAvatarClassName, customDropdown);
      });

      test('manager reset() restores default navigation theme', () {
        MagicStarter.useNavigationTheme(
          const MagicStarterNavigationTheme(
            activeItemClassName: 'active:text-custom',
          ),
        );

        expect(
          MagicStarter.navigationTheme.activeItemClassName,
          'active:text-custom',
        );

        MagicStarter.manager.reset();

        expect(
          MagicStarter.navigationTheme.activeItemClassName,
          'active:text-primary active:bg-primary/10 dark:active:bg-primary/10',
        );
      });
    });

    group('modal theme', () {
      test('modalTheme returns default instance when not configured', () {
        final theme = MagicStarter.modalTheme;

        expect(
          theme.containerClassName,
          'bg-white dark:bg-gray-800 rounded-2xl',
        );
        expect(
          theme.headerClassName,
          'px-6 pt-6 pb-4',
        );
        expect(
          theme.bodyClassName,
          'px-6 pb-4',
        );
        expect(
          theme.footerClassName,
          'px-6 py-4 bg-gray-50 dark:bg-gray-800/50',
        );
        expect(
          theme.titleClassName,
          'text-xl font-semibold text-gray-900 dark:text-white mb-2',
        );
        expect(
          theme.descriptionClassName,
          'text-sm text-gray-600 dark:text-gray-400',
        );
        expect(
          theme.primaryButtonClassName,
          'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
        );
        expect(
          theme.secondaryButtonClassName,
          'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium',
        );
        expect(
          theme.dangerButtonClassName,
          'px-4 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white text-sm font-medium',
        );
        expect(
          theme.warningButtonClassName,
          'px-4 py-2 rounded-lg bg-amber-500 hover:bg-amber-600 text-white text-sm font-medium',
        );
        expect(
          theme.errorClassName,
          'text-sm text-red-600 dark:text-red-400',
        );
        expect(
          theme.inputClassName,
          'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary',
        );
        expect(theme.maxWidth, 448.0);
      });

      test('useModalTheme() stores theme on manager', () {
        const customTheme = MagicStarterModalTheme(
          containerClassName: 'bg-gray-900 rounded-xl',
        );

        MagicStarter.useModalTheme(customTheme);

        expect(MagicStarter.manager.modalTheme, equals(customTheme));
      });

      test('modalTheme getter returns the registered theme', () {
        const customTheme = MagicStarterModalTheme(
          containerClassName: 'bg-slate-800 rounded-3xl',
          titleClassName: 'text-2xl font-bold text-white',
        );

        MagicStarter.useModalTheme(customTheme);

        expect(MagicStarter.modalTheme, equals(customTheme));
        expect(
          MagicStarter.modalTheme.containerClassName,
          'bg-slate-800 rounded-3xl',
        );
        expect(
          MagicStarter.modalTheme.titleClassName,
          'text-2xl font-bold text-white',
        );
      });

      test('MagicStarterModalTheme preserves all custom field values', () {
        const customContainer =
            'bg-zinc-900 rounded-2xl border border-zinc-700';
        const customHeader = 'px-8 pt-8 pb-6';
        const customBody = 'px-8 pb-6';
        const customFooter = 'px-8 py-6 bg-zinc-800';
        const customTitle = 'text-2xl font-black text-white';
        const customDescription = 'text-base text-zinc-400';
        const customPrimary =
            'px-6 py-3 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white font-semibold';
        const customSecondary =
            'px-6 py-3 rounded-xl bg-zinc-700 hover:bg-zinc-600 text-white font-semibold';
        const customDanger =
            'px-6 py-3 rounded-xl bg-rose-600 hover:bg-rose-700 text-white font-semibold';
        const customWarning =
            'px-6 py-3 rounded-xl bg-yellow-500 hover:bg-yellow-600 text-white font-semibold';
        const customError = 'text-base text-rose-400';
        const customInput =
            'w-full px-4 py-4 rounded-xl bg-zinc-800 border border-zinc-600 text-white';
        const customMaxWidth = 560.0;

        const theme = MagicStarterModalTheme(
          containerClassName: customContainer,
          headerClassName: customHeader,
          bodyClassName: customBody,
          footerClassName: customFooter,
          titleClassName: customTitle,
          descriptionClassName: customDescription,
          primaryButtonClassName: customPrimary,
          secondaryButtonClassName: customSecondary,
          dangerButtonClassName: customDanger,
          warningButtonClassName: customWarning,
          errorClassName: customError,
          inputClassName: customInput,
          maxWidth: customMaxWidth,
        );

        expect(theme.containerClassName, customContainer);
        expect(theme.headerClassName, customHeader);
        expect(theme.bodyClassName, customBody);
        expect(theme.footerClassName, customFooter);
        expect(theme.titleClassName, customTitle);
        expect(theme.descriptionClassName, customDescription);
        expect(theme.primaryButtonClassName, customPrimary);
        expect(theme.secondaryButtonClassName, customSecondary);
        expect(theme.dangerButtonClassName, customDanger);
        expect(theme.warningButtonClassName, customWarning);
        expect(theme.errorClassName, customError);
        expect(theme.inputClassName, customInput);
        expect(theme.maxWidth, customMaxWidth);
      });

      test('manager reset() restores default modal theme', () {
        MagicStarter.useModalTheme(
          const MagicStarterModalTheme(
            containerClassName: 'bg-custom rounded-none',
          ),
        );

        expect(
          MagicStarter.modalTheme.containerClassName,
          'bg-custom rounded-none',
        );

        MagicStarter.manager.reset();

        expect(
          MagicStarter.modalTheme.containerClassName,
          'bg-white dark:bg-gray-800 rounded-2xl',
        );
      });
    });

    group('sidebarFooter', () {
      test('useSidebarFooter() sets manager.sidebarFooterBuilder', () {
        MagicStarter.useSidebarFooter((context) => const SizedBox());

        expect(MagicStarter.manager.sidebarFooterBuilder, isNotNull);
      });

      test('manager.reset() clears sidebarFooterBuilder', () {
        MagicStarter.useSidebarFooter((context) => const SizedBox());

        expect(MagicStarter.manager.sidebarFooterBuilder, isNotNull);

        MagicStarter.manager.reset();

        expect(MagicStarter.manager.sidebarFooterBuilder, isNull);
      });
    });

    group('unified theme', () {
      test('useTheme() delegates to manager and theme getter returns it', () {
        const customForm = MagicStarterFormTheme(
          inputClassName: 'custom-unified-input',
        );
        const customCard = MagicStarterCardTheme(borderRadius: 'rounded-xl');

        const unified = MagicStarterTheme(
          form: customForm,
          card: customCard,
        );

        MagicStarter.useTheme(unified);

        expect(MagicStarter.theme.form.inputClassName, 'custom-unified-input');
        expect(MagicStarter.theme.card.borderRadius, 'rounded-xl');
      });

      test('useFormTheme() works and formTheme getter returns it', () {
        const customForm = MagicStarterFormTheme(
          primaryButtonClassName: 'custom-primary-btn',
          linkClassName: 'custom-link',
        );

        MagicStarter.useFormTheme(customForm);

        expect(
          MagicStarter.formTheme.primaryButtonClassName,
          'custom-primary-btn',
        );
        expect(MagicStarter.formTheme.linkClassName, 'custom-link');
        expect(MagicStarter.manager.formTheme, equals(customForm));
      });

      test('useNavigationTheme() still works alongside useTheme()', () {
        MagicStarter.useTheme(
          const MagicStarterTheme(
            form: MagicStarterFormTheme(inputClassName: 'themed-input'),
          ),
        );

        const customNav = MagicStarterNavigationTheme(
          activeItemClassName: 'active:text-indigo-500',
        );

        MagicStarter.useNavigationTheme(customNav);

        expect(
          MagicStarter.navigationTheme.activeItemClassName,
          'active:text-indigo-500',
        );
        expect(MagicStarter.formTheme.inputClassName, 'themed-input');
      });

      test('individual sub-theme getters work via facade', () {
        const customCard = MagicStarterCardTheme(
          surfaceClassName: 'custom-surface',
        );
        const customPageHeader = MagicStarterPageHeaderTheme(
          titleClassName: 'facade-title',
        );
        const customLayout = MagicStarterLayoutTheme(sidebarWidth: 280);
        const customAuth = MagicStarterAuthTheme(
          cardClassName: 'facade-auth-card',
        );

        MagicStarter.useCardTheme(customCard);
        MagicStarter.usePageHeaderTheme(customPageHeader);
        MagicStarter.useLayoutTheme(customLayout);
        MagicStarter.useAuthTheme(customAuth);

        expect(MagicStarter.cardTheme.surfaceClassName, 'custom-surface');
        expect(MagicStarter.pageHeaderTheme.titleClassName, 'facade-title');
        expect(MagicStarter.layoutTheme.sidebarWidth, 280);
        expect(MagicStarter.authTheme.cardClassName, 'facade-auth-card');
      });
    });

    group('modal registry defaults', () {
      test('default modal.confirm is registered after manager init', () {
        expect(MagicStarter.view.hasModal('modal.confirm'), isTrue);
      });

      test('default modal.password_confirm is registered', () {
        expect(MagicStarter.view.hasModal('modal.password_confirm'), isTrue);
      });

      test('default modal.two_factor is registered', () {
        expect(MagicStarter.view.hasModal('modal.two_factor'), isTrue);
      });

      test(
          'manager.reset() clears consumer overrides and re-registers defaults',
          () {
        // Consumer override is lost on reset — default is re-registered
        MagicStarter.view
            .registerModal('modal.confirm', () => const SizedBox());
        MagicStarter.manager.reset();
        expect(MagicStarter.view.hasModal('modal.confirm'), isTrue);
      });

      test('manager.reset() re-registers default modals', () {
        MagicStarter.manager.reset();
        expect(MagicStarter.view.hasModal('modal.confirm'), isTrue);
        expect(MagicStarter.view.hasModal('modal.password_confirm'), isTrue);
        expect(MagicStarter.view.hasModal('modal.two_factor'), isTrue);
      });
    });
  });
}
