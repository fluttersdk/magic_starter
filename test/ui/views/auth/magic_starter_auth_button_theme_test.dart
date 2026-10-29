import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Copy for the social buttons; every other label stays its translation key
/// unless [extra] words it.
class _CopyLoader implements TranslationLoader {
  const _CopyLoader([this.extra = const {}]);

  final Map<String, String> extra;

  @override
  Future<Map<String, dynamic>> load(Locale _) async => {
    'social.continue_with': 'Continue with :provider',
    ...extra,
  };
}

/// One provider whose sign-in never settles, so a render is not followed by a
/// completion the case does not look at.
class _FakeSocialAuth implements MagicStarterSocialAuth {
  _FakeSocialAuth([this._label = 'Google']);

  final String _label;

  @override
  List<String> providers() => const ['google'];

  @override
  String label(String provider) => _label;

  @override
  Widget icon(String provider) => const SizedBox.square(dimension: 16);

  @override
  Future<Map<String, dynamic>> signIn(String provider) =>
      Completer<Map<String, dynamic>>().future;

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

/// What one button paints, read off the render tree and not off its classes.
class _Look {
  const _Look({
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.weight,
    required this.bordered,
    this.lineHeight,
  });

  final double height;
  final double radius;
  final double fontSize;
  final FontWeight weight;
  final bool bordered;

  /// Only the host-theme expectations pin it; the stock ones leave it open.
  final double? lineHeight;
}

enum _Kind { primary, secondary }

/// A button to measure: the text that finds it and which standard it answers to.
class _Target {
  const _Target(this.label, this.kind);

  final String label;
  final _Kind kind;
}

/// A screen holding auth buttons and how to put it on the test surface.
class _Screen {
  const _Screen(this.name, this.targets, this.mount);

  final String name;
  final List<_Target> targets;
  final Future<void> Function(WidgetTester tester, WindThemeData wind) mount;
}

/// The title-lg label of a host design system, 17 on 22 at weight 600, in a
/// 44 px box: the standard the auth screens have to follow.
const _standardSize = 'px-5 py-[11px] text-[17px] leading-[22px] font-semibold';

const _capsule = MagicStarterButtonTheme(
  shapeClassName: 'rounded-full',
  smClassName: _standardSize,
  mdClassName: _standardSize,
  lgClassName: _standardSize,
  secondaryBorderClassName: '',
);

/// Measured with the stock theme on the code before the auth buttons followed
/// the button theme, at 1280 px (no hit area around the button), in light and in
/// dark: `py-3` around a 16 px label.
const _primaryBefore = _Look(
  height: 47,
  radius: 8,
  fontSize: 16,
  weight: FontWeight.w600,
  bordered: false,
);

/// The same measurement for the secondary, social and guest buttons: `py-3`
/// around a 14 px medium label and a one pixel border on each side.
const _secondaryBefore = _Look(
  height: 46,
  radius: 8,
  fontSize: 14,
  weight: FontWeight.w500,
  bordered: true,
);

/// The one measured change of the secondary, social and guest buttons: they are
/// the theme's `md` now (`py-2` around the same 14 px label) and no longer a
/// `py-3` of their own, so they sit 8 px lower than before.
const _secondaryNow = _Look(
  height: 38,
  radius: 8,
  fontSize: 14,
  weight: FontWeight.w500,
  bordered: true,
);

const _capsuleLook = _Look(
  height: 44,
  radius: 9999,
  fontSize: 17,
  weight: FontWeight.w600,
  bordered: false,
  lineHeight: 22,
);

/// The className the secondary, social and guest buttons carried before they
/// followed the button theme, handed to the default (primary, `md`) button as
/// they were: `py-3` and a one pixel border of their own.
const _secondaryBeforeClassName =
    'w-full bg-transparent border border-gray-300 dark:border-gray-600 '
    'text-gray-600 dark:text-gray-400 hover:bg-gray-50 '
    'dark:hover:bg-gray-800 py-3 rounded-lg text-sm font-medium';

/// A theme whose three sizes differ in height and label size, for the one group
/// that checks which size each button asks for: `_capsule` makes them equal, so
/// a button that forgot its `size:` would measure the same there.
const _tiered = MagicStarterButtonTheme(
  shapeClassName: 'rounded-full',
  smClassName: 'px-3 py-[5px] text-[13px] leading-[18px]',
  mdClassName: 'px-4 py-[10px] text-[15px] leading-[20px]',
  lgClassName: 'px-5 py-[14px] text-[19px] leading-[24px]',
  secondaryBorderClassName: '',
);

/// What `lg` paints under [_tiered]: the submit buttons.
const _tieredLg = _Look(
  height: 52,
  radius: 9999,
  fontSize: 19,
  weight: FontWeight.w600,
  bordered: false,
  lineHeight: 24,
);

/// What the secondary intent at `md` paints under [_tiered]: the social, guest
/// and step-up provider buttons.
const _tieredSecondaryMd = _Look(
  height: 40,
  radius: 9999,
  fontSize: 15,
  weight: FontWeight.w500,
  bordered: false,
  lineHeight: 20,
);

Widget _host(WindThemeData wind, Widget child) {
  return WindTheme(
    data: wind,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Future<void> _mountPlain(
  WidgetTester tester,
  WindThemeData wind,
  Widget view,
) async {
  await tester.pumpWidget(MaterialApp(home: _host(wind, view)));
  await tester.pumpAndSettle();
}

Future<void> _mountRouted(
  WidgetTester tester,
  WindThemeData wind, {
  required String route,
  required Widget view,
  String? location,
}) async {
  MagicRoute.page(route, () => view);
  MagicRouter.instance.setInitialLocation(location ?? route);

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: MagicRouter.instance.routerConfig,
      builder: (context, child) => _host(wind, child!),
    ),
  );
  await tester.pumpAndSettle();
}

final List<_Screen> _screens = [
  _Screen(
    'login',
    const [
      _Target('auth.login_title', _Kind.primary),
      _Target('magic_starter.auth.continue_as_guest', _Kind.secondary),
      _Target('Continue with Google', _Kind.secondary),
    ],
    (tester, wind) => _mountPlain(tester, wind, const MagicStarterLoginView()),
  ),
  _Screen(
    'register',
    const [_Target('auth.register_title', _Kind.primary)],
    (tester, wind) =>
        _mountPlain(tester, wind, const MagicStarterRegisterView()),
  ),
  _Screen(
    'forgot password',
    const [_Target('auth.send_reset_link', _Kind.primary)],
    (tester, wind) =>
        _mountPlain(tester, wind, const MagicStarterForgotPasswordView()),
  ),
  _Screen(
    'reset password',
    const [_Target('auth.reset_password_button', _Kind.primary)],
    (tester, wind) => _mountRouted(
      tester,
      wind,
      route: '/auth/reset-password',
      view: const MagicStarterResetPasswordView(),
    ),
  ),
  _Screen(
    'verify email',
    const [_Target('auth.back_to_login', _Kind.primary)],
    (tester, wind) {
      Http.fake((request) => Http.response(<String, dynamic>{'message': 'ok'}));

      return _mountRouted(
        tester,
        wind,
        route: '/auth/verify-email',
        view: const MagicStarterVerifyEmailView(),
        location:
            '/auth/verify-email?id=7&hash=${'a' * 40}&expires=99&signature=s',
      );
    },
  ),
  _Screen(
    'two-factor challenge',
    const [_Target('auth.verify', _Kind.primary)],
    (tester, wind) => _mountRouted(
      tester,
      wind,
      route: MagicStarterConfig.twoFactorChallengeRoute(),
      view: const MagicStarterTwoFactorChallengeView(),
    ),
  ),
  _Screen(
    'phone code request',
    const [_Target('magic_starter.otp.send_code_button', _Kind.primary)],
    (tester, wind) =>
        _mountPlain(tester, wind, const MagicStarterOtpVerifyView()),
  ),
  _Screen(
    'phone code verification',
    const [_Target('magic_starter.otp.verify_button', _Kind.primary)],
    (tester, wind) async {
      Http.fake((request) => Http.response(<String, dynamic>{'message': 'ok'}));
      await MagicStarterOtpController.instance.sendOtp(phone: '+905551112233');

      await _mountPlain(tester, wind, const MagicStarterOtpVerifyView());
    },
  ),
  _Screen(
    'team invitation',
    const [_Target('teams.accept_invitation', _Kind.primary)],
    (tester, wind) {
      Config.set('magic_starter.features.teams', true);
      final controller = MagicStarterTeamController.instance;
      addTearDown(() {
        controller.members.dispose();
        controller.invitations.dispose();
        controller.currentTeamId.dispose();
      });

      return _mountRouted(
        tester,
        wind,
        route: '/invitations/:token/accept',
        view: const MagicStarterTeamInvitationAcceptView(),
        location: '/invitations/tok1/accept',
      );
    },
  ),
];

WindThemeData _wind(Brightness brightness) {
  return WindThemeData(
    brightness: brightness,
    // A synced theme follows the platform and ignores the brightness above.
    syncWithSystem: false,
    aliases: MagicStarterTokens.defaultAliases,
  );
}

/// Reads what the button labelled [label] paints: the [WButton] around it, the
/// decoration Wind drew for it and the style its label resolved to.
_Look _measure(WidgetTester tester, String label) {
  final button = find
      .ancestor(of: find.text(label), matching: find.byType(WButton))
      .first;
  final decoration = tester
      .widgetList<Container>(
        find.descendant(of: button, matching: find.byType(Container)),
      )
      .map((container) => container.decoration)
      .whereType<BoxDecoration>()
      .first;
  final style = tester
      .renderObject<RenderParagraph>(
        find.descendant(of: button, matching: find.text(label)),
      )
      .text
      .style!;

  return _Look(
    height: tester.getSize(button).height,
    radius: (decoration.borderRadius! as BorderRadius).topLeft.x,
    fontSize: style.fontSize!,
    weight: style.fontWeight!,
    bordered: decoration.border != null,
    lineHeight: style.height == null ? null : style.height! * style.fontSize!,
  );
}

void _expectLook(_Look actual, _Look expected, String reason) {
  expect(actual.height, expected.height, reason: '$reason: height');
  expect(actual.radius, expected.radius, reason: '$reason: radius');
  expect(actual.fontSize, expected.fontSize, reason: '$reason: label size');
  expect(actual.weight, expected.weight, reason: '$reason: label weight');
  expect(actual.bordered, expected.bordered, reason: '$reason: border');

  if (expected.lineHeight != null) {
    expect(
      actual.lineHeight,
      closeTo(expected.lineHeight!, 0.01),
      reason: '$reason: line height',
    );
  }
}

void main() {
  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Magic.singleton('log', () => LogManager());
    setUpMagicStarterForTests();
    Magic.put(MagicStarterAuthController());
    Magic.put(MagicStarterOtpController());
    Auth.fake();
    Translator.instance.setLoader(const _CopyLoader());
    await Translator.instance.setLocale(const Locale('en'));
    Config.set('magic_starter.features.guest_auth', true);
    Config.set('magic_starter.features.social_login', true);
    Config.set('magic_starter.features.two_factor', true);
    MagicStarter.useSocialAuth(_FakeSocialAuth());
  });

  tearDown(() {
    Auth.unfake();
    Http.unfake();
    MagicRouter.reset();
  });

  /// Lays the surface out at 1280 px, where no hit area wraps a button, so the
  /// height read is the height painted.
  void useDesktopSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
  }

  group('a host that themes nothing', () {
    for (final screen in _screens) {
      for (final brightness in Brightness.values) {
        testWidgets('${screen.name} keeps its buttons in ${brightness.name}', (
          tester,
        ) async {
          useDesktopSurface(tester);

          await screen.mount(tester, _wind(brightness));

          for (final target in screen.targets) {
            _expectLook(_measure(tester, target.label), switch (target.kind) {
              _Kind.primary => _primaryBefore,
              _Kind.secondary => _secondaryNow,
            }, '${screen.name} / ${target.label}');
          }
        });
      }
    }

    testWidgets('the secondary buttons only moved by the vertical padding', (
      tester,
    ) async {
      useDesktopSurface(tester);

      // Both are measured: the old className on the button it used to sit on,
      // and the form theme's string on the secondary `md` that replaced it.
      await _mountPlain(
        tester,
        _wind(Brightness.light),
        Column(
          children: [
            const MSButton(
              className: _secondaryBeforeClassName,
              child: WText('Before'),
            ),
            MSButton(
              intent: ButtonIntent.secondary,
              size: ButtonSize.md,
              className: MagicStarter.formTheme.secondaryButtonClassName,
              child: const WText('Now'),
            ),
          ],
        ),
      );

      final before = _measure(tester, 'Before');
      final now = _measure(tester, 'Now');

      _expectLook(before, _secondaryBefore, 'the old secondary string');
      _expectLook(now, _secondaryNow, 'the secondary string now');
      expect(before.height - now.height, 8);
    });
  });

  group('a host with a 44 px capsule standard', () {
    for (final screen in _screens) {
      for (final brightness in Brightness.values) {
        testWidgets('${screen.name} follows it in ${brightness.name}', (
          tester,
        ) async {
          useDesktopSurface(tester);
          MagicStarter.useButtonTheme(_capsule);

          await screen.mount(tester, _wind(brightness));

          for (final target in screen.targets) {
            _expectLook(
              _measure(tester, target.label),
              _capsuleLook,
              '${screen.name} / ${target.label}',
            );
          }
        });
      }
    }

    testWidgets('an unfilled secondary stays unfilled in dark', (tester) async {
      useDesktopSurface(tester);
      MagicStarter.useButtonTheme(_capsule);

      await _mountPlain(
        tester,
        _wind(Brightness.dark),
        const MagicStarterLoginView(),
      );

      final guest = find
          .ancestor(
            of: find.text('magic_starter.auth.continue_as_guest'),
            matching: find.byType(WButton),
          )
          .first;
      final decoration = tester
          .widgetList<Container>(
            find.descendant(of: guest, matching: find.byType(Container)),
          )
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .first;

      expect(decoration.color?.a ?? 0, 0);
    });

    testWidgets('a secondary border is the theme\'s to keep', (tester) async {
      useDesktopSurface(tester);
      MagicStarter.useButtonTheme(
        const MagicStarterButtonTheme(
          shapeClassName: 'rounded-full',
          smClassName: _standardSize,
          mdClassName: _standardSize,
          lgClassName: _standardSize,
        ),
      );

      await _mountPlain(
        tester,
        _wind(Brightness.light),
        const MagicStarterLoginView(),
      );

      final primary = _measure(tester, 'auth.login_title');
      final guest = _measure(tester, 'magic_starter.auth.continue_as_guest');

      expect(primary.height, 44);
      expect(guest.bordered, isTrue);
      expect(guest.height, 46);
    });

    testWidgets('a colour-only border token still paints a hairline', (
      tester,
    ) async {
      // Why the button strings name no border colour: Wind falls back to a one
      // pixel width when only a colour is given, so a string that kept
      // `border-gray-300` would add 2 px to a borderless 44 px secondary. If
      // Wind stops doing that, the strings can take their border colour back.
      useDesktopSurface(tester);
      MagicStarter.useButtonTheme(_capsule);

      await _mountPlain(
        tester,
        _wind(Brightness.light),
        const MSButton(
          intent: ButtonIntent.secondary,
          size: ButtonSize.md,
          className: 'border-gray-300',
          child: WText('Save'),
        ),
      );

      final look = _measure(tester, 'Save');

      expect(look.bordered, isTrue);
      expect(look.height, 46);
    });

    testWidgets('lays out 44 px tall on a phone, with no extra hit area', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(390, 844) * 3.0;
      addTearDown(tester.view.reset);
      MagicStarter.useButtonTheme(_capsule);

      // The social buttons stand for the secondary kind (the guest button is
      // the same intent and size). The test font is as wide as it is tall, so
      // the labels are worded short enough to stay on one line at 17 px: an
      // untranslated key wraps on a phone and doubles the button.
      Translator.instance.setLoader(
        const _CopyLoader({'auth.send_reset_link': 'Send link'}),
      );
      await Translator.instance.setLocale(const Locale('en'));
      await _mountPlain(
        tester,
        _wind(Brightness.light),
        Column(
          children: [
            const MagicStarterForgotPasswordView(),
            MagicStarterSocialButtons(
              socialAuth: _FakeSocialAuth('Go'),
              onSelected: (_) {},
            ),
          ],
        ),
      );

      for (final label in ['Send link', 'Continue with Go']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byType(MSButton),
        );

        expect(tester.getSize(button).height, 44, reason: label);
      }
    });
  });

  group('a host whose button sizes differ', () {
    for (final screen in _screens) {
      testWidgets('${screen.name} asks for lg and the secondary md', (
        tester,
      ) async {
        useDesktopSurface(tester);
        MagicStarter.useButtonTheme(_tiered);

        await screen.mount(tester, _wind(Brightness.light));

        for (final target in screen.targets) {
          _expectLook(_measure(tester, target.label), switch (target.kind) {
            _Kind.primary => _tieredLg,
            _Kind.secondary => _tieredSecondaryMd,
          }, '${screen.name} / ${target.label}');
        }
      });
    }

    testWidgets('a weight in lgClassName does not reach the submit buttons', (
      tester,
    ) async {
      useDesktopSurface(tester);
      MagicStarter.useButtonTheme(
        const MagicStarterButtonTheme(
          lgClassName: 'px-5 py-3 text-base font-bold',
        ),
      );

      await _mountPlain(
        tester,
        _wind(Brightness.light),
        const Column(
          children: [
            MagicStarterForgotPasswordView(),
            MSButton(size: ButtonSize.lg, child: WText('Plain')),
          ],
        ),
      );

      // The primary string keeps `font-semibold` and is appended after the
      // size, so it wins the weight; a button without it takes the size's.
      expect(_measure(tester, 'auth.send_reset_link').weight, FontWeight.w600);
      expect(_measure(tester, 'Plain').weight, FontWeight.w700);
    });
  });

  group('the button strings of the form and auth themes', () {
    /// A token without its variant prefixes, so `hover:py-3` counts as `py-3`.
    Iterable<String> tokensOf(String className) => className
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) => token.split(':').last);

    final geometry = RegExp(
      r'^(rounded(-.*)?|p[xytrbl]?-.*|min-h-.*|h-.*|leading-.*|'
      r'text-(xs|sm|base|lg|[2-9]?xl|\[\d.*))$',
    );

    final complete = WindThemeData(aliases: MagicStarterTokens.defaultAliases);

    final themes = {
      'stock': const MagicStarterTheme(),
      'derived from a complete alias map': MagicStarterTheme.fromWind(complete),
      'derived from a theme without roles': MagicStarterTheme.fromWind(
        WindThemeData(),
      ),
    };

    for (final entry in themes.entries) {
      final theme = entry.value;
      final strings = {
        'form.primaryButtonClassName': theme.form.primaryButtonClassName,
        'form.secondaryButtonClassName': theme.form.secondaryButtonClassName,
        'auth.guestButtonClassName': theme.auth.guestButtonClassName,
      };

      for (final string in strings.entries) {
        test('${string.key}, ${entry.key}, names no shape, padding or label '
            'size', () {
          expect(
            tokensOf(string.value).where(geometry.hasMatch),
            isEmpty,
            reason: string.value,
          );
        });

        test('${string.key}, ${entry.key}, keeps the full width', () {
          expect(tokensOf(string.value), contains('w-full'));
        });
      }

      for (final name in [
        'form.secondaryButtonClassName',
        'auth.guestButtonClassName',
      ]) {
        test('$name, ${entry.key}, leaves the border to the button theme', () {
          // A colour-only `border-*` token still paints a one pixel border in
          // Wind, which a borderless 44 px standard cannot get rid of.
          expect(
            tokensOf(strings[name]!).where((t) => t.startsWith('border')),
            isEmpty,
            reason: strings[name],
          );
        });
      }

      test('form.primaryButtonClassName, ${entry.key}, keeps the label weight '
          'and the colours', () {
        final tokens = tokensOf(theme.form.primaryButtonClassName);

        expect(tokens, contains('font-semibold'));
        expect(tokens.where((t) => t.startsWith('bg-')), isNotEmpty);
        expect(tokens.where((t) => t.startsWith('text-')), isNotEmpty);
      });
    }
  });

  group('a caller className', () {
    testWidgets('with a shape of its own still wins over the button theme', (
      tester,
    ) async {
      useDesktopSurface(tester);
      MagicStarter.useButtonTheme(_capsule);
      MagicStarter.useFormTheme(
        const MagicStarterFormTheme(
          primaryButtonClassName: 'w-full bg-primary text-white rounded-lg',
        ),
      );
      MagicStarter.useAuthTheme(
        const MagicStarterAuthTheme(
          guestButtonClassName: 'w-full bg-transparent rounded-md',
        ),
      );

      await _mountPlain(
        tester,
        _wind(Brightness.light),
        const MagicStarterLoginView(),
      );

      final primary = _measure(tester, 'auth.login_title');
      final guest = _measure(tester, 'magic_starter.auth.continue_as_guest');

      // Their shape is theirs; the 44 px box and the label still come from the
      // button theme, as only the families they name are overridden.
      expect(primary.radius, 8);
      expect(primary.height, 44);
      expect(primary.fontSize, 17);
      expect(guest.radius, 6);
      expect(guest.height, 44);
    });

    testWidgets('with its own padding and size wins as well', (tester) async {
      useDesktopSurface(tester);
      MagicStarter.useButtonTheme(_capsule);
      MagicStarter.useFormTheme(
        const MagicStarterFormTheme(
          primaryButtonClassName:
              'w-full bg-primary text-white py-3 rounded-lg text-base',
        ),
      );

      await _mountPlain(
        tester,
        _wind(Brightness.light),
        const MagicStarterLoginView(),
      );

      final primary = _measure(tester, 'auth.login_title');

      expect(primary.radius, 8);
      expect(primary.fontSize, 16);
      expect(primary.height, greaterThan(44));
    });
  });
}
