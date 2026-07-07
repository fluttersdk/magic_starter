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

    test('derives a semantic alias into every one of the 7 sub-themes', () {
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
            MagicStarter.cardTheme.surfaceClassName, 'border-color-border'),
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
