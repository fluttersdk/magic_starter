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
  });
}
