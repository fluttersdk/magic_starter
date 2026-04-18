import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/src/configuration/magic_starter_theme.dart';

void main() {
  // -------------------------------------------------------------------------
  // MagicStarterFormTheme
  // -------------------------------------------------------------------------

  group('MagicStarterFormTheme', () {
    group('defaults', () {
      test('inputClassName contains w-full and rounded-lg', () {
        const theme = MagicStarterFormTheme();

        expect(theme.inputClassName, contains('w-full'));
        expect(theme.inputClassName, contains('rounded-lg'));
        expect(theme.inputClassName, contains('px-3 py-3'));
      });

      test('labelClassName contains text-sm and font-medium', () {
        const theme = MagicStarterFormTheme();

        expect(theme.labelClassName, contains('text-sm'));
        expect(theme.labelClassName, contains('font-medium'));
      });

      test('errorClassName contains text-red-600', () {
        const theme = MagicStarterFormTheme();

        expect(theme.errorClassName, contains('text-red-600'));
      });

      test('primaryButtonClassName contains w-full and rounded-lg', () {
        const theme = MagicStarterFormTheme();

        expect(theme.primaryButtonClassName, contains('w-full'));
        expect(theme.primaryButtonClassName, contains('rounded-lg'));
        expect(theme.primaryButtonClassName, contains('bg-primary'));
      });

      test('linkClassName contains text-primary', () {
        const theme = MagicStarterFormTheme();

        expect(theme.linkClassName, contains('text-primary'));
      });
    });

    group('custom overrides', () {
      test('accepts custom inputClassName', () {
        const theme = MagicStarterFormTheme(inputClassName: 'custom-input');

        expect(theme.inputClassName, equals('custom-input'));
      });

      test('accepts custom labelClassName', () {
        const theme = MagicStarterFormTheme(labelClassName: 'custom-label');

        expect(theme.labelClassName, equals('custom-label'));
      });

      test('accepts custom errorClassName', () {
        const theme = MagicStarterFormTheme(errorClassName: 'custom-error');

        expect(theme.errorClassName, equals('custom-error'));
      });

      test('accepts custom primaryButtonClassName', () {
        const theme = MagicStarterFormTheme(
          primaryButtonClassName: 'custom-btn',
        );

        expect(theme.primaryButtonClassName, equals('custom-btn'));
      });

      test('accepts custom secondaryButtonClassName', () {
        const theme = MagicStarterFormTheme(
          secondaryButtonClassName: 'custom-secondary-btn',
        );

        expect(theme.secondaryButtonClassName, equals('custom-secondary-btn'));
      });

      test('accepts custom linkClassName', () {
        const theme = MagicStarterFormTheme(linkClassName: 'custom-link');

        expect(theme.linkClassName, equals('custom-link'));
      });

      test('accepts custom checkboxLabelClassName', () {
        const theme = MagicStarterFormTheme(
          checkboxLabelClassName: 'custom-checkbox-label',
        );

        expect(
          theme.checkboxLabelClassName,
          equals('custom-checkbox-label'),
        );
      });

      test('non-overridden fields keep their defaults', () {
        const theme = MagicStarterFormTheme(inputClassName: 'custom-input');

        expect(theme.labelClassName, contains('text-sm'));
        expect(theme.errorClassName, contains('text-red-600'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // MagicStarterCardTheme
  // -------------------------------------------------------------------------

  group('MagicStarterCardTheme', () {
    group('defaults', () {
      test('surfaceClassName contains bg-white dark:bg-gray-800', () {
        const theme = MagicStarterCardTheme();

        expect(theme.surfaceClassName, contains('bg-white'));
        expect(theme.surfaceClassName, contains('dark:bg-gray-800'));
      });

      test('insetClassName contains bg-gray-50', () {
        const theme = MagicStarterCardTheme();

        expect(theme.insetClassName, contains('bg-gray-50'));
      });

      test('elevatedClassName contains shadow-md', () {
        const theme = MagicStarterCardTheme();

        expect(theme.elevatedClassName, contains('shadow-md'));
      });

      test('titleClassName contains text-lg and font-semibold', () {
        const theme = MagicStarterCardTheme();

        expect(theme.titleClassName, contains('text-lg'));
        expect(theme.titleClassName, contains('font-semibold'));
      });

      test('titleNoPaddingContainerClassName is px-6 pt-6 pb-3', () {
        const theme = MagicStarterCardTheme();

        expect(
            theme.titleNoPaddingContainerClassName, equals('px-6 pt-6 pb-3'));
      });

      test('borderRadius is rounded-2xl', () {
        const theme = MagicStarterCardTheme();

        expect(theme.borderRadius, equals('rounded-2xl'));
      });

      test('paddingClassName is p-6', () {
        const theme = MagicStarterCardTheme();

        expect(theme.paddingClassName, equals('p-6'));
      });
    });

    group('custom overrides', () {
      test('accepts custom surfaceClassName', () {
        const theme = MagicStarterCardTheme(surfaceClassName: 'bg-zinc-900');

        expect(theme.surfaceClassName, equals('bg-zinc-900'));
      });

      test('accepts custom borderRadius', () {
        const theme = MagicStarterCardTheme(borderRadius: 'rounded-xl');

        expect(theme.borderRadius, equals('rounded-xl'));
      });

      test('accepts custom paddingClassName', () {
        const theme = MagicStarterCardTheme(paddingClassName: 'p-8');

        expect(theme.paddingClassName, equals('p-8'));
      });

      test('non-overridden fields keep their defaults', () {
        const theme = MagicStarterCardTheme(borderRadius: 'rounded-xl');

        expect(theme.surfaceClassName, contains('bg-white'));
        expect(theme.titleClassName, contains('font-semibold'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // MagicStarterPageHeaderTheme
  // -------------------------------------------------------------------------

  group('MagicStarterPageHeaderTheme', () {
    group('defaults', () {
      test('titleClassName contains text-2xl and font-bold', () {
        const theme = MagicStarterPageHeaderTheme();

        expect(theme.titleClassName, contains('text-2xl'));
        expect(theme.titleClassName, contains('font-bold'));
      });

      test('subtitleClassName contains text-sm', () {
        const theme = MagicStarterPageHeaderTheme();

        expect(theme.subtitleClassName, contains('text-sm'));
      });

      test('titleClassName uses line-clamp-2 instead of truncate', () {
        const theme = MagicStarterPageHeaderTheme();

        expect(theme.titleClassName, contains('line-clamp-2'));
        expect(theme.titleClassName, isNot(contains('truncate')));
      });

      test('subtitleClassName uses line-clamp-2 instead of truncate', () {
        const theme = MagicStarterPageHeaderTheme();

        expect(theme.subtitleClassName, contains('line-clamp-2'));
        expect(theme.subtitleClassName, isNot(contains('truncate')));
      });

      test('containerClassName contains border-b', () {
        const theme = MagicStarterPageHeaderTheme();

        expect(theme.containerClassName, contains('border-b'));
      });

      test('containerInlineClassName contains flex-row items-center', () {
        const theme = MagicStarterPageHeaderTheme();

        expect(theme.containerInlineClassName, contains('flex-row'));
        expect(theme.containerInlineClassName, contains('items-center'));
      });

      test('actionContainerClassName contains flex flex-row', () {
        const theme = MagicStarterPageHeaderTheme();

        expect(theme.actionContainerClassName, contains('flex'));
        expect(theme.actionContainerClassName, contains('flex-row'));
      });
    });

    group('custom overrides', () {
      test('accepts custom titleClassName', () {
        const theme = MagicStarterPageHeaderTheme(
          titleClassName: 'text-3xl font-black text-white',
        );

        expect(theme.titleClassName, equals('text-3xl font-black text-white'));
      });

      test('accepts custom subtitleClassName', () {
        const theme = MagicStarterPageHeaderTheme(
          subtitleClassName: 'text-xs text-zinc-400',
        );

        expect(theme.subtitleClassName, equals('text-xs text-zinc-400'));
      });

      test('accepts custom containerClassName', () {
        const theme = MagicStarterPageHeaderTheme(
          containerClassName: 'custom-container',
        );

        expect(theme.containerClassName, equals('custom-container'));
      });

      test('non-overridden fields keep their defaults', () {
        const theme = MagicStarterPageHeaderTheme(
          titleClassName: 'text-3xl font-black',
        );

        expect(theme.subtitleClassName, contains('text-sm'));
        expect(theme.containerClassName, contains('border-b'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // MagicStarterLayoutTheme
  // -------------------------------------------------------------------------

  group('MagicStarterLayoutTheme', () {
    group('defaults', () {
      test('sidebarWidth is 256', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.sidebarWidth, equals(256));
      });

      test('headerHeight is 64', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.headerHeight, equals(64));
      });

      test('sidebarClassName contains bg-white dark:bg-gray-900', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.sidebarClassName, contains('bg-white'));
        expect(theme.sidebarClassName, contains('dark:bg-gray-900'));
      });

      test('headerClassName contains h-16', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.headerClassName, contains('h-16'));
      });

      test('contentBackgroundLightColor is gray', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.contentBackgroundLightColor, equals('gray'));
      });

      test('contentBackgroundLightShade is 50', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.contentBackgroundLightShade, equals(50));
      });

      test('contentBackgroundDarkShade is 950', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.contentBackgroundDarkShade, equals(950));
      });

      test('drawerBackgroundLightColor is white', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.drawerBackgroundLightColor, equals('white'));
      });

      test('drawerBackgroundLightShade is 50', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.drawerBackgroundLightShade, equals(50));
      });

      test('drawerBackgroundDarkColor is gray', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.drawerBackgroundDarkColor, equals('gray'));
      });

      test('drawerBackgroundDarkShade is 900', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.drawerBackgroundDarkShade, equals(900));
      });

      test('bottomNavClassName is empty string', () {
        const theme = MagicStarterLayoutTheme();

        expect(theme.bottomNavClassName, equals(''));
      });
    });

    group('custom overrides', () {
      test('accepts custom sidebarWidth', () {
        const theme = MagicStarterLayoutTheme(sidebarWidth: 280);

        expect(theme.sidebarWidth, equals(280));
      });

      test('accepts custom headerHeight', () {
        const theme = MagicStarterLayoutTheme(headerHeight: 80);

        expect(theme.headerHeight, equals(80));
      });

      test('accepts custom sidebarClassName', () {
        const theme = MagicStarterLayoutTheme(
          sidebarClassName: 'bg-zinc-900 border-r border-zinc-700',
        );

        expect(
          theme.sidebarClassName,
          equals('bg-zinc-900 border-r border-zinc-700'),
        );
      });

      test('accepts custom contentBackgroundLightColor', () {
        const theme = MagicStarterLayoutTheme(
          contentBackgroundLightColor: 'slate',
        );

        expect(theme.contentBackgroundLightColor, equals('slate'));
      });

      test('accepts custom bottomNavClassName', () {
        const theme = MagicStarterLayoutTheme(
          bottomNavClassName: 'bg-zinc-900 border-t border-zinc-700',
        );

        expect(
          theme.bottomNavClassName,
          equals('bg-zinc-900 border-t border-zinc-700'),
        );
      });

      test('non-overridden fields keep their defaults', () {
        const theme = MagicStarterLayoutTheme(sidebarWidth: 300);

        expect(theme.headerHeight, equals(64));
        expect(theme.contentBackgroundLightColor, equals('gray'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // MagicStarterAuthTheme
  // -------------------------------------------------------------------------

  group('MagicStarterAuthTheme', () {
    group('defaults', () {
      test('cardClassName contains rounded-2xl bg-white dark:bg-gray-800', () {
        const theme = MagicStarterAuthTheme();

        expect(theme.cardClassName, contains('rounded-2xl'));
        expect(theme.cardClassName, contains('bg-white'));
        expect(theme.cardClassName, contains('dark:bg-gray-800'));
      });

      test('titleClassName contains text-2xl and font-bold', () {
        const theme = MagicStarterAuthTheme();

        expect(theme.titleClassName, contains('text-2xl'));
        expect(theme.titleClassName, contains('font-bold'));
      });

      test('subtitleClassName contains text-sm', () {
        const theme = MagicStarterAuthTheme();

        expect(theme.subtitleClassName, contains('text-sm'));
      });

      test('errorBannerClassName contains bg-red-50 and text-red-700', () {
        const theme = MagicStarterAuthTheme();

        expect(theme.errorBannerClassName, contains('bg-red-50'));
        expect(theme.errorBannerClassName, contains('text-red-700'));
      });

      test('socialDividerClassName contains flex flex-row', () {
        const theme = MagicStarterAuthTheme();

        expect(theme.socialDividerClassName, contains('flex'));
        expect(theme.socialDividerClassName, contains('flex-row'));
      });

      test('registrationLinkTextClassName contains text-primary', () {
        const theme = MagicStarterAuthTheme();

        expect(theme.registrationLinkTextClassName, contains('text-primary'));
      });
    });

    group('custom overrides', () {
      test('accepts custom cardClassName', () {
        const theme = MagicStarterAuthTheme(
          cardClassName: 'rounded-3xl bg-zinc-900 border border-zinc-700',
        );

        expect(
          theme.cardClassName,
          equals('rounded-3xl bg-zinc-900 border border-zinc-700'),
        );
      });

      test('accepts custom titleClassName', () {
        const theme = MagicStarterAuthTheme(
          titleClassName: 'text-3xl font-black text-white text-center',
        );

        expect(
          theme.titleClassName,
          equals('text-3xl font-black text-white text-center'),
        );
      });

      test('accepts custom errorBannerClassName', () {
        const theme = MagicStarterAuthTheme(
          errorBannerClassName: 'custom-error-banner',
        );

        expect(theme.errorBannerClassName, equals('custom-error-banner'));
      });

      test('accepts custom guestButtonClassName', () {
        const theme = MagicStarterAuthTheme(
          guestButtonClassName: 'custom-guest-btn',
        );

        expect(theme.guestButtonClassName, equals('custom-guest-btn'));
      });

      test('non-overridden fields keep their defaults', () {
        const theme = MagicStarterAuthTheme(cardClassName: 'custom-card');

        expect(theme.titleClassName, contains('font-bold'));
        expect(theme.subtitleClassName, contains('text-sm'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // MagicStarterTheme (unified wrapper)
  // -------------------------------------------------------------------------

  group('MagicStarterTheme', () {
    group('default constructor', () {
      test('uses default sub-themes when no arguments provided', () {
        const theme = MagicStarterTheme();

        expect(theme.form, isA<MagicStarterFormTheme>());
        expect(theme.card, isA<MagicStarterCardTheme>());
        expect(theme.pageHeader, isA<MagicStarterPageHeaderTheme>());
        expect(theme.layout, isA<MagicStarterLayoutTheme>());
        expect(theme.auth, isA<MagicStarterAuthTheme>());
        expect(theme.navigation, isA<MagicStarterNavigationTheme>());
        expect(theme.modal, isA<MagicStarterModalTheme>());
      });

      test('default form sub-theme has correct defaults', () {
        const theme = MagicStarterTheme();

        expect(theme.form.inputClassName, contains('w-full'));
        expect(theme.form.primaryButtonClassName, contains('bg-primary'));
      });

      test('default card sub-theme has correct defaults', () {
        const theme = MagicStarterTheme();

        expect(theme.card.surfaceClassName, contains('bg-white'));
        expect(theme.card.borderRadius, equals('rounded-2xl'));
      });

      test('default layout sub-theme has correct numeric defaults', () {
        const theme = MagicStarterTheme();

        expect(theme.layout.sidebarWidth, equals(256));
        expect(theme.layout.headerHeight, equals(64));
      });

      test('default auth sub-theme has correct defaults', () {
        const theme = MagicStarterTheme();

        expect(theme.auth.cardClassName, contains('rounded-2xl'));
      });
    });

    group('custom sub-themes', () {
      test('stores custom form sub-theme', () {
        const customForm = MagicStarterFormTheme(
          inputClassName: 'custom-input',
        );
        const theme = MagicStarterTheme(form: customForm);

        expect(theme.form.inputClassName, equals('custom-input'));
      });

      test('stores custom card sub-theme', () {
        const customCard = MagicStarterCardTheme(borderRadius: 'rounded-xl');
        const theme = MagicStarterTheme(card: customCard);

        expect(theme.card.borderRadius, equals('rounded-xl'));
      });

      test('stores custom layout sub-theme', () {
        const customLayout = MagicStarterLayoutTheme(sidebarWidth: 300);
        const theme = MagicStarterTheme(layout: customLayout);

        expect(theme.layout.sidebarWidth, equals(300));
      });

      test('stores custom auth sub-theme', () {
        const customAuth = MagicStarterAuthTheme(
          cardClassName: 'custom-card',
        );
        const theme = MagicStarterTheme(auth: customAuth);

        expect(theme.auth.cardClassName, equals('custom-card'));
      });

      test('other sub-themes remain at defaults when one is customized', () {
        const theme = MagicStarterTheme(
          form: MagicStarterFormTheme(inputClassName: 'custom-input'),
        );

        expect(theme.card.borderRadius, equals('rounded-2xl'));
        expect(theme.layout.sidebarWidth, equals(256));
        expect(theme.auth.cardClassName, contains('rounded-2xl'));
      });
    });

    group('copyWith', () {
      test('overrides one sub-theme while keeping others at defaults', () {
        const original = MagicStarterTheme();
        final updated = original.copyWith(
          form: const MagicStarterFormTheme(inputClassName: 'custom-input'),
        );

        expect(updated.form.inputClassName, equals('custom-input'));
        expect(updated.card.borderRadius, equals('rounded-2xl'));
        expect(updated.layout.sidebarWidth, equals(256));
        expect(updated.auth.cardClassName, contains('rounded-2xl'));
      });

      test('overrides layout sub-theme while keeping others unchanged', () {
        const original = MagicStarterTheme();
        final updated = original.copyWith(
          layout: const MagicStarterLayoutTheme(sidebarWidth: 320),
        );

        expect(updated.layout.sidebarWidth, equals(320));
        expect(updated.form.inputClassName, contains('w-full'));
        expect(updated.card.borderRadius, equals('rounded-2xl'));
      });

      test('overrides auth sub-theme while keeping others unchanged', () {
        const original = MagicStarterTheme();
        final updated = original.copyWith(
          auth: const MagicStarterAuthTheme(cardClassName: 'custom-card'),
        );

        expect(updated.auth.cardClassName, equals('custom-card'));
        expect(updated.form.inputClassName, contains('w-full'));
        expect(updated.layout.headerHeight, equals(64));
      });

      test('overrides multiple sub-themes simultaneously', () {
        const original = MagicStarterTheme();
        final updated = original.copyWith(
          form: const MagicStarterFormTheme(inputClassName: 'custom-input'),
          card: const MagicStarterCardTheme(borderRadius: 'rounded-xl'),
          layout: const MagicStarterLayoutTheme(sidebarWidth: 300),
        );

        expect(updated.form.inputClassName, equals('custom-input'));
        expect(updated.card.borderRadius, equals('rounded-xl'));
        expect(updated.layout.sidebarWidth, equals(300));
        expect(updated.auth.cardClassName, contains('rounded-2xl'));
      });

      test('copyWith with no arguments returns equivalent theme', () {
        const original = MagicStarterTheme();
        final copy = original.copyWith();

        expect(copy.form.inputClassName, equals(original.form.inputClassName));
        expect(copy.card.borderRadius, equals(original.card.borderRadius));
        expect(copy.layout.sidebarWidth, equals(original.layout.sidebarWidth));
        expect(copy.layout.headerHeight, equals(original.layout.headerHeight));
        expect(copy.auth.cardClassName, equals(original.auth.cardClassName));
        expect(
          copy.pageHeader.titleClassName,
          equals(original.pageHeader.titleClassName),
        );
      });

      test('copyWith preserves custom sub-themes not being overridden', () {
        final base = const MagicStarterTheme().copyWith(
          form: const MagicStarterFormTheme(inputClassName: 'custom-input'),
        );
        final updated = base.copyWith(
          card: const MagicStarterCardTheme(borderRadius: 'rounded-xl'),
        );

        expect(updated.form.inputClassName, equals('custom-input'));
        expect(updated.card.borderRadius, equals('rounded-xl'));
      });
    });
  });
}
