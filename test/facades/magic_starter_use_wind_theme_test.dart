import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Whether [className] carries [token] as a whole utility, allowing a variant
/// prefix (`hover:bg-surface` still counts as carrying `bg-surface`).
bool hasToken(String className, String token) {
  return className
      .split(RegExp(r'\s+'))
      .any((t) => t == token || t.endsWith(':$token'));
}

void main() {
  group('MagicStarter.useWindTheme', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      setUpMagicStarterForTests();
    });

    tearDown(() {
      MagicApp.reset();
      Magic.flush();
    });

    /// A theme whose semantic alias map and primary color are all custom, so a
    /// derived className that carries a semantic token provably re-skins to the
    /// passed palette rather than the shipped default.
    final windTheme = WindThemeData(
      colors: {'primary': Colors.deepPurple},
      aliases: const {
        'bg-surface': 'bg-[#101012] dark:bg-[#101012]',
        'bg-surface-container': 'bg-[#202024] dark:bg-[#202024]',
        'bg-surface-container-high': 'bg-[#303036] dark:bg-[#303036]',
        'text-fg': 'text-[#f0f0f4] dark:text-[#f0f0f4]',
        'text-fg-muted': 'text-[#a0a0a8] dark:text-[#a0a0a8]',
        'text-fg-disabled': 'text-[#606068] dark:text-[#606068]',
        'bg-primary': 'bg-[#6d28d9] dark:bg-[#6d28d9]',
        'text-on-primary': 'text-[#ffffff] dark:text-[#ffffff]',
        'border-color-border': 'border-[#404048] dark:border-[#404048]',
        'border-color-border-subtle': 'border-[#303036] dark:border-[#303036]',
        'bg-destructive': 'bg-[#dc2626] dark:bg-[#dc2626]',
        'text-on-destructive': 'text-[#ffffff] dark:text-[#ffffff]',
        'bg-destructive-container': 'bg-[#7f1d1d] dark:bg-[#7f1d1d]',
        'text-destructive': 'text-[#dc2626] dark:text-[#dc2626]',
        'bg-warning': 'bg-[#d97706] dark:bg-[#d97706]',
      },
    );

    test('derives a semantic alias into every one of the 8 sub-themes', () {
      MagicStarter.useWindTheme(windTheme);

      // 1. Navigation: brand text follows the primary role.
      expect(
        hasToken(MagicStarter.navigationTheme.brandClassName, 'text-primary'),
        isTrue,
        reason: 'navigation brand should carry the primary token',
      );

      // 2. Modal: container follows the card/panel surface role.
      expect(
        hasToken(
          MagicStarter.modalTheme.containerClassName,
          'bg-surface-container',
        ),
        isTrue,
        reason: 'modal container should carry the surface-container token',
      );

      // 3. Form: primary button follows the primary role.
      expect(
        hasToken(MagicStarter.formTheme.primaryButtonClassName, 'bg-primary'),
        isTrue,
        reason: 'form primary button should carry the primary token',
      );

      // 4. Card: surface variant follows the base surface role.
      expect(
        hasToken(MagicStarter.cardTheme.surfaceClassName, 'bg-surface'),
        isTrue,
        reason: 'card surface should carry the surface token',
      );

      // 5. Page header: title follows the foreground role.
      expect(
        hasToken(MagicStarter.pageHeaderTheme.titleClassName, 'text-fg'),
        isTrue,
        reason: 'page header title should carry the fg token',
      );

      // 6. Layout: sidebar follows the base surface role.
      expect(
        hasToken(MagicStarter.layoutTheme.sidebarClassName, 'bg-surface'),
        isTrue,
        reason: 'layout sidebar should carry the surface token',
      );

      // 7. Auth: form card follows the card/panel surface role.
      expect(
        hasToken(MagicStarter.authTheme.cardClassName, 'bg-surface-container'),
        isTrue,
        reason: 'auth card should carry the surface-container token',
      );

      // 8. Dropdown: the popover panel follows the card/panel surface role.
      expect(
        hasToken(
          MagicStarter.dropdownTheme.panelClassName,
          'bg-surface-container',
        ),
        isTrue,
        reason: 'dropdown panel should carry the surface-container token',
      );
    });

    test('leaves the button theme at its defaults', () {
      // The recipe already writes the semantic aliases (`bg-primary`,
      // `text-on-primary`, `border-color-border`) itself, so there is no colour
      // to derive here, and shape and size are the host's call. Deriving the
      // border from the role would also hand a fallback palette pair to a host
      // whose theme does not define it, which the recipe never did.
      MagicStarter.useWindTheme(windTheme);

      const defaults = MagicStarterButtonTheme();
      final button = MagicStarter.buttonTheme;

      expect(button.shapeClassName, defaults.shapeClassName);
      expect(button.smClassName, defaults.smClassName);
      expect(button.mdClassName, defaults.mdClassName);
      expect(button.lgClassName, defaults.lgClassName);
      expect(
        button.secondaryBorderClassName,
        defaults.secondaryBorderClassName,
      );
    });

    test('derives every dropdown role from the semantic palette', () {
      MagicStarter.useWindTheme(windTheme);

      final dropdown = MagicStarter.dropdownTheme;

      expect(hasToken(dropdown.panelClassName, 'border-color-border'), isTrue);
      expect(
        hasToken(dropdown.dividerClassName, 'border-color-border'),
        isTrue,
      );
      expect(
        hasToken(dropdown.itemClassName, 'bg-surface-container-high'),
        isTrue,
      );
      expect(dropdown.itemClassName, startsWith('hover:'));
      // The hovered row is container-high, so the tile must not be.
      expect(hasToken(dropdown.tileClassName, 'bg-surface'), isTrue);
      expect(
        hasToken(dropdown.tileClassName, 'bg-surface-container-high'),
        isFalse,
      );
      expect(hasToken(dropdown.textClassName, 'text-fg'), isTrue);
      expect(hasToken(dropdown.mutedTextClassName, 'text-fg-muted'), isTrue);
      expect(dropdown.dangerTextClassName, 'danger:text-destructive');
      expect(dropdown.dangerTileClassName, 'danger:bg-destructive-container');
    });

    test('leaves no raw palette utility in the derived dropdown theme', () {
      MagicStarter.useWindTheme(windTheme);

      final dropdown = MagicStarter.dropdownTheme;

      for (final className in [
        dropdown.panelClassName,
        dropdown.dividerClassName,
        dropdown.itemClassName,
        dropdown.tileClassName,
        dropdown.textClassName,
        dropdown.mutedTextClassName,
        dropdown.dangerTextClassName,
        dropdown.dangerTileClassName,
      ]) {
        expect(
          RegExp(r'(gray|red|white)').hasMatch(className),
          isFalse,
          reason: '"$className" still names a palette colour',
        );
      }
    });

    test('keeps the dropdown derivation when the navigation theme is set', () {
      // A host refines the navigation theme after `useWindTheme` and replaces
      // it whole (the setter has no merge), so the dropdown colours must not
      // live there or that refinement would hand them back to the stock grey.
      MagicStarter.useWindTheme(windTheme);
      MagicStarter.useNavigationTheme(
        const MagicStarterNavigationTheme(brandClassName: 'text-lg text-fg'),
      );

      expect(
        hasToken(
          MagicStarter.dropdownTheme.panelClassName,
          'bg-surface-container',
        ),
        isTrue,
      );
    });

    test('prefixes every token of a fallback pair with the variant', () {
      // With no aliases the roles resolve to palette pairs. A variant written
      // in front of the pair would reach only its first token, so the dark
      // half of a hover or danger field would apply at rest.
      MagicStarter.useWindTheme(WindThemeData());

      final dropdown = MagicStarter.dropdownTheme;

      for (final (variant, className) in [
        ('hover', dropdown.itemClassName),
        ('danger', dropdown.dangerTextClassName),
        ('hover', MagicStarter.navigationTheme.hoverItemClassName),
      ]) {
        for (final token in className.split(RegExp(r'\s+'))) {
          expect(
            token,
            startsWith('$variant:'),
            reason: '"$token" is not scoped to $variant',
          );
        }
      }
      expect(dropdown.panelClassName, contains('bg-'));
    });

    test('derives on-primary and border roles onto action buttons', () {
      MagicStarter.useWindTheme(windTheme);

      expect(
        hasToken(
          MagicStarter.formTheme.primaryButtonClassName,
          'text-on-primary',
        ),
        isTrue,
      );
      expect(
        hasToken(
          MagicStarter.cardTheme.surfaceClassName,
          'border-color-border',
        ),
        isTrue,
      );
      expect(
        hasToken(
          MagicStarter.modalTheme.dangerButtonClassName,
          'bg-destructive',
        ),
        isTrue,
      );
    });

    test('derives the dropdown avatar initial from on-primary', () {
      // The trigger's background starts at the primary colour, so its initial
      // is the colour a theme chose to put on primary, not a fixed white.
      MagicStarter.useWindTheme(windTheme);

      expect(
        hasToken(
          MagicStarter.navigationTheme.dropdownAvatarTextClassName,
          'text-on-primary',
        ),
        isTrue,
      );
    });

    test('keeps a white dropdown initial when the theme omits on-primary', () {
      MagicStarter.useWindTheme(WindThemeData());

      final className =
          MagicStarter.navigationTheme.dropdownAvatarTextClassName;
      expect(hasToken(className, 'text-on-primary'), isFalse);
      expect(hasToken(className, 'text-white'), isTrue);
    });

    test('falls back to a visible default when the theme omits a role', () {
      // A bare theme defines no semantic aliases; `bg-surface` is unavailable,
      // so the derivation must NOT emit a token that silently no-ops. It falls
      // back to the shipped default palette pair instead.
      MagicStarter.useWindTheme(WindThemeData());

      final surface = MagicStarter.cardTheme.surfaceClassName;
      expect(
        hasToken(surface, 'bg-surface'),
        isFalse,
        reason: 'undefined surface role must not emit a dead alias token',
      );
      expect(
        surface.contains('bg-'),
        isTrue,
        reason: 'card surface must still carry a concrete background',
      );
    });

    test('is additive: individual setters still override afterward', () {
      MagicStarter.useWindTheme(windTheme);

      const override = MagicStarterCardTheme(surfaceClassName: 'bg-zinc-950');
      MagicStarter.useCardTheme(override);

      // The individual setter wins for card.
      expect(MagicStarter.cardTheme.surfaceClassName, 'bg-zinc-950');
      // Other sub-themes still reflect the useWindTheme derivation.
      expect(
        hasToken(MagicStarter.formTheme.primaryButtonClassName, 'bg-primary'),
        isTrue,
      );
    });

    test('does not break the existing useTheme unified hook', () {
      const theme = MagicStarterTheme(
        form: MagicStarterFormTheme(primaryButtonClassName: 'bg-teal-600'),
      );
      MagicStarter.useTheme(theme);

      expect(MagicStarter.formTheme.primaryButtonClassName, 'bg-teal-600');
    });
  });
}
