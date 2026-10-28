import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/user_profile_dropdown/user_profile_dropdown.preview.dart';

class MockGuard implements Guard {
  Authenticatable? _user;
  final ValueNotifier<int> _stateNotifier = ValueNotifier<int>(0);

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    _user = user;
    _stateNotifier.value++;
  }

  @override
  Future<void> logout() async {
    _user = null;
  }

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  T? user<T extends Model>() => _user as T?;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  void setUser(Authenticatable user) => _user = user;

  @override
  Future<bool> hasToken() async => false;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {}

  @override
  ValueNotifier<int> get stateNotifier => _stateNotifier;
}

class MockRouter implements MagicRouter {
  @override
  void push(String path) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockGuard mockGuard;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('log', () => LogManager());
    Config.set('logging', {
      'default': 'console',
      'channels': {
        'console': {'driver': 'console', 'level': 'debug'},
      },
    });

    mockGuard = MockGuard();
    Magic.singleton('auth', () => AuthManager());
    Auth.manager.forgetGuards();
    Auth.manager.extend('mock', (_) => mockGuard);
    Config.set('auth.defaults.guard', 'mock');
    Config.set('auth.guards', {
      'mock': {'driver': 'mock'},
    });

    Magic.singleton('magic_starter', () => MagicStarterManager());
    MagicStarter.useNavigation(mainItems: [], profileMenuItems: []);
    Magic.singleton('router', () => MockRouter());
  });

  tearDown(() {
    Auth.manager.forgetGuards();
    MagicStarter.manager.onLogout = null;
  });

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: widget),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Behavior gate: these assertions came from the pre-MS-prefix alias test.
  // ---------------------------------------------------------------------------

  testWidgets('renders avatar with user initial when authenticated', (
    tester,
  ) async {
    mockGuard.setUser(
      MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
      }),
    );
    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();
    expect(find.text('J'), findsOneWidget);
  });

  testWidgets('renders a person glyph rather than an initial when no user', (
    tester,
  ) async {
    // Before the session is known there is nobody to take an initial from. The
    // trigger used to take it from the word "User", so a host whose guest
    // session opens after the first frame drew a "U" that no account has, and
    // then swapped it for the real initial.
    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(MSAvatar),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(MSAvatar), matching: find.byType(WText)),
      findsNothing,
    );
  });

  testWidgets('renders a person glyph for an account with a blank name', (
    tester,
  ) async {
    mockGuard.setUser(MagicStarterAuthUser.fromMap({'id': 1, 'name': '  '}));

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(MSAvatar),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsOneWidget,
    );
  });

  testWidgets('names a blank-name account with the placeholder in the menu', (
    tester,
  ) async {
    mockGuard.setUser(MagicStarterAuthUser.fromMap({'id': 1, 'name': '  '}));

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MSAvatar));
    await tester.pumpAndSettle();

    expect(find.text('common.user'), findsOneWidget);
  });

  testWidgets('draws the initial once a session opens after the first frame', (
    tester,
  ) async {
    // The guest session a host opens without awaiting it: the first frame has
    // no user, the next one does. A const trigger in a shell that rebuilds on
    // auth change is not rebuilt with it, so the trigger listens itself.
    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    expect(find.text('G'), findsNothing);

    await mockGuard.login(
      {},
      MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Guest',
        'is_guest': true,
      }),
    );
    await tester.pump();

    expect(find.text('G'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  testWidgets('draws the initial on the theme\'s text class', (tester) async {
    MagicStarter.manager.navigationTheme = const MagicStarterNavigationTheme(
      dropdownAvatarTextClassName: 'text-sm font-bold text-amber-500',
    );
    mockGuard.setUser(MagicStarterAuthUser.fromMap({'id': 1, 'name': 'Guest'}));

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));

    expect(
      tester
          .widget<WText>(
            find.ancestor(of: find.text('G'), matching: find.byType(WText)),
          )
          .className,
      'text-sm font-bold text-amber-500',
    );
  });

  testWidgets('tapping avatar opens dropdown with user info', (tester) async {
    mockGuard.setUser(
      MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
      }),
    );
    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('J'));
    await tester.pumpAndSettle();

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('john@example.com'), findsOneWidget);
  });

  testWidgets('uses default bottomRight alignment', (tester) async {
    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();
    final popover = tester.widget<WPopover>(find.byType(WPopover));
    expect(popover.alignment, PopoverAlignment.bottomRight);
  });

  testWidgets('accepts custom alignment parameter', (tester) async {
    await tester.pumpWidget(
      wrap(const MSUserProfileDropdown(alignment: PopoverAlignment.topRight)),
    );
    await tester.pumpAndSettle();
    final popover = tester.widget<WPopover>(find.byType(WPopover));
    expect(popover.alignment, PopoverAlignment.topRight);
  });

  testWidgets('uses custom triggerBuilder when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        MSUserProfileDropdown(
          triggerBuilder: (context, isOpen, isHovering) =>
              const Text('Custom Trigger'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Custom Trigger'), findsOneWidget);
  });

  testWidgets('UserProfileDropdown preview renders without error', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const UserProfileDropdownPreview()));
    await tester.pump();
    expect(find.byType(UserProfileDropdownPreview), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Menu contents. The dropdown assembles its items from three sources (the
  // built-in profile link, the host's registered profileMenuItems, and logout),
  // so each source needs its own assertion: a regression in one is invisible
  // through the others.
  // ---------------------------------------------------------------------------

  testWidgets('shows profile settings menu item in dropdown', (tester) async {
    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MSAvatar));
    await tester.pumpAndSettle();

    expect(find.text('auth.profile'), findsOneWidget);
    // The menu's profile row, beside the trigger's own placeholder glyph.
    expect(find.byIcon(Icons.person_outline), findsNWidgets(2));
  });

  testWidgets('shows custom profileMenuItems in dropdown', (tester) async {
    MagicStarter.useNavigation(
      mainItems: [],
      profileMenuItems: [
        MagicStarterNavItem(
          icon: Icons.notifications_outlined,
          labelKey: 'Notifications',
          path: '/notifications',
        ),
      ],
    );

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MSAvatar));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('offers a guest a way to sign in or create an account', (
    tester,
  ) async {
    // A guest session is signed in, so the menu showed it profile, settings
    // and logout, and nothing that turns it into an account.
    mockGuard.setUser(
      MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Guest',
        'is_guest': true,
      }),
    );

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('G'));
    await tester.pumpAndSettle();

    expect(find.text('auth.sign_in'), findsOneWidget);
    expect(find.text('magic_starter.titles.register'), findsOneWidget);
  });

  testWidgets('offers an account no guest entries', (tester) async {
    mockGuard.setUser(
      MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Anilcan',
        'email': 'anilcan@example.com',
        'is_guest': false,
      }),
    );

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    expect(find.text('auth.sign_in'), findsNothing);
    expect(find.text('magic_starter.titles.register'), findsNothing);
  });

  testWidgets('shows logout item in dropdown and handles tap', (tester) async {
    bool logoutCalled = false;
    MagicStarter.manager.onLogout = () async {
      logoutCalled = true;
    };

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MSAvatar));
    await tester.pumpAndSettle();

    expect(find.text('auth.logout'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);

    await tester.tap(find.text('auth.logout'));
    await tester.pumpAndSettle();

    expect(logoutCalled, isTrue);
  });

  testWidgets('menu items are scrollable when many items registered', (
    tester,
  ) async {
    MagicStarter.useNavigation(
      mainItems: [],
      profileMenuItems: [
        for (int i = 0; i < 10; i++)
          MagicStarterNavItem(
            icon: Icons.settings,
            labelKey: 'Item $i',
            path: '/item-$i',
          ),
      ],
    );

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MSAvatar));
    await tester.pumpAndSettle();

    for (int i = 0; i < 10; i++) {
      expect(find.text('Item $i'), findsOneWidget);
    }
  });

  testWidgets('shows theme toggle in dropdown and toggles without closing', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MSAvatar));
    await tester.pumpAndSettle();

    // Light mode shows the dark-mode affordance, not both.
    expect(find.text('common.toggle_theme'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_outlined), findsNothing);

    await tester.tap(find.text('common.toggle_theme'));
    await tester.pumpAndSettle();

    // The icon flips and the dropdown stays open: toggling the theme must not
    // dismiss the menu the operator is still reading.
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
    expect(find.text('common.toggle_theme'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // The account's photo. This trigger is the one avatar on screen at all times,
  // and it drew the initial whatever the account carried, so a person who had
  // uploaded a photo saw it on the profile screen and nowhere else.
  // ---------------------------------------------------------------------------

  testWidgets('shows the signed-in account photo in its trigger', (
    tester,
  ) async {
    mockGuard.setUser(
      MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Anilcan Cakir',
        'email': 'a@example.test',
        'profile_photo_url': 'https://example.test/me.png',
      }),
    );

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));

    expect(
      tester.widget<MSAvatar>(find.byType(MSAvatar)).photoUrl,
      'https://example.test/me.png',
    );
  });

  testWidgets('falls back to the initial with no photo', (tester) async {
    mockGuard.setUser(
      MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Anilcan Cakir',
        'email': 'a@example.test',
      }),
    );

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));

    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('keeps the themed class on the node that carries states', (
    tester,
  ) async {
    // The avatar takes no states, so a theme className moved inside it would
    // silently drop the hover and active branches of a host that themed one.
    // The shipped default has no state variants, so nothing else would show it.
    MagicStarter.manager.navigationTheme = const MagicStarterNavigationTheme(
      dropdownAvatarClassName: 'bg-primary hover:bg-accent',
    );

    mockGuard.setUser(
      MagicStarterAuthUser.fromMap({'id': 1, 'name': 'Anilcan Cakir'}),
    );

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));

    final WDiv themed = tester.widget<WDiv>(
      find
          .ancestor(of: find.byType(MSAvatar), matching: find.byType(WDiv))
          .first,
    );

    expect(themed.className, contains('hover:bg-accent'));
    expect(themed.states, isNotNull);
  });

  // ---------------------------------------------------------------------------
  // Panel: corner clipping and theme-supplied colour.
  // ---------------------------------------------------------------------------

  group('panel', () {
    /// A host palette whose every role is a distinct hex, so a resolved colour
    /// names the role it came from.
    final hostTheme = WindThemeData(
      aliases: const {
        'bg-surface': 'bg-[#101012] dark:bg-[#101012]',
        'bg-surface-container': 'bg-[#202024] dark:bg-[#202024]',
        'bg-surface-container-high': 'bg-[#303036] dark:bg-[#303036]',
        'text-fg': 'text-[#f0f0f4] dark:text-[#f0f0f4]',
        'text-fg-muted': 'text-[#a0a0a8] dark:text-[#a0a0a8]',
        'border-color-border': 'border-[#404048] dark:border-[#404048]',
        'bg-destructive-container': 'bg-[#7f1d1d] dark:bg-[#7f1d1d]',
        'text-destructive': 'text-[#dc2626] dark:text-[#dc2626]',
      },
    );

    Future<void> open(WidgetTester tester, {WindThemeData? data}) async {
      mockGuard.setUser(
        MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'John Doe',
          'email': 'john@example.com',
        }),
      );

      await tester.pumpWidget(
        data == null
            ? wrap(const MSUserProfileDropdown())
            : MaterialApp(
                home: WindTheme(
                  data: data,
                  child: const Scaffold(body: MSUserProfileDropdown()),
                ),
              ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MSAvatar));
      await tester.pumpAndSettle();
    }

    Finder panel() => find.byWidgetPredicate(
      (widget) => widget is WDiv && (widget.className ?? '').contains('w-72'),
    );

    Finder rowOf(String label) => find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is WDiv && (widget.className ?? '').contains('py-2.5'),
          ),
        )
        .first;

    /// The [WText] that draws [label]; `find.text` lands on the inner `Text`.
    Finder wtext(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(WText)).first;

    /// Every fill painted under [owner], outermost first.
    List<Color> fillsOf(WidgetTester tester, Finder owner) => [
      for (final box in tester.widgetList<DecoratedBox>(
        find.descendant(of: owner, matching: find.byType(DecoratedBox)),
      ))
        if (box.decoration is BoxDecoration &&
            (box.decoration as BoxDecoration).color != null)
          (box.decoration as BoxDecoration).color!,
    ];

    testWidgets('clips its rows to the rounded corners', (tester) async {
      await open(tester);

      expect(
        tester.widget<WDiv>(panel()).className,
        contains('overflow-hidden'),
      );

      // The class alone proves nothing if Wind draws no clip for it.
      final clip = tester.widget<ClipRRect>(
        find.descendant(of: panel(), matching: find.byType(ClipRRect)).first,
      );
      expect(clip.borderRadius, isNot(BorderRadius.zero));
    });

    testWidgets('keeps the shipped grey panel when the host sets no theme', (
      tester,
    ) async {
      await open(tester);

      expect(
        tester.widget<WDiv>(panel()).className,
        contains(
          'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700',
        ),
      );
    });

    testWidgets('names no palette colour once the host theme supplies them', (
      tester,
    ) async {
      MagicStarter.useWindTheme(hostTheme);
      await open(tester, data: hostTheme);

      final raw = RegExp(r'(gray|blue|red)-\d|\bwhite\b');
      final classNames = [
        tester.widget<WDiv>(panel()).className ?? '',
        for (final div in tester.widgetList<WDiv>(
          find.descendant(of: panel(), matching: find.byType(WDiv)),
        ))
          div.className ?? '',
        for (final text in tester.widgetList<WText>(
          find.descendant(of: panel(), matching: find.byType(WText)),
        ))
          text.className ?? '',
        for (final icon in tester.widgetList<WIcon>(
          find.descendant(of: panel(), matching: find.byType(WIcon)),
        ))
          icon.className ?? '',
      ];

      // A panel that rendered nothing would pass the loop below vacuously.
      expect(classNames.length, greaterThan(10));
      for (final className in classNames) {
        expect(
          raw.hasMatch(className),
          isFalse,
          reason: '"$className" hard-codes a palette colour',
        );
      }
    });

    testWidgets('reads panel, divider, row, tile and text from the theme', (
      tester,
    ) async {
      MagicStarter.useDropdownTheme(
        const MagicStarterDropdownTheme(
          panelClassName: 'bg-amber-500 border border-amber-700',
          dividerClassName: 'border-amber-300',
          itemClassName: 'hover:bg-amber-100',
          tileClassName: 'bg-amber-200',
          textClassName: 'text-amber-900',
          mutedTextClassName: 'text-amber-700',
          dangerTextClassName: 'danger:text-rose-700',
          dangerTileClassName: 'danger:bg-rose-100',
        ),
      );
      await open(tester);

      bool anyDiv(String token) => tester
          .widgetList<WDiv>(
            find.descendant(of: panel(), matching: find.byType(WDiv)),
          )
          .any((div) => (div.className ?? '').contains(token));

      expect(
        tester.widget<WDiv>(panel()).className,
        contains('bg-amber-500 border border-amber-700'),
      );
      expect(
        tester.widget<WDiv>(rowOf('auth.profile')).className,
        contains('hover:bg-amber-100'),
      );
      expect(
        tester.widget<WText>(wtext('John Doe')).className,
        contains('text-amber-900'),
      );
      expect(
        tester.widget<WText>(wtext('john@example.com')).className,
        contains('text-amber-700'),
      );
      expect(
        tester.widget<WText>(wtext('auth.logout')).className,
        contains('danger:text-rose-700'),
      );
      expect(anyDiv('bg-amber-200'), isTrue, reason: 'tile fill not themed');
      expect(anyDiv('danger:bg-rose-100'), isTrue, reason: 'danger tile');
      expect(anyDiv('border-amber-300'), isTrue, reason: 'divider not themed');
    });

    testWidgets('colours the sign out row from the destructive role', (
      tester,
    ) async {
      MagicStarter.useWindTheme(hostTheme);
      await open(tester, data: hostTheme);

      Color? colourOf(String label) =>
          tester.widget<Text>(find.text(label)).style?.color;

      // The danger fields come last, so the state beats the resting colour on
      // the one row that carries it and leaves every other row alone.
      expect(colourOf('auth.logout'), const Color(0xFFDC2626));
      expect(colourOf('auth.profile'), const Color(0xFFF0F0F4));
    });

    testWidgets('draws the rules between its groups one pixel tall', (
      tester,
    ) async {
      await open(tester);

      final rules = find.byWidgetPredicate(
        (widget) =>
            widget is WDiv &&
            (widget.className ?? '').contains('my-1 mx-2 w-full border-t'),
      );

      expect(rules, findsOneWidget);
      // The rule is a border-only box: the old `h-[1px]` fill was one pixel
      // tall, and so is this, inside the same `my-1` margins.
      final line = find.descendant(
        of: rules,
        matching: find.byType(DecoratedBox),
      );
      expect(tester.getSize(line.first).height, 1);
      expect(tester.getSize(rules).height, 9);
    });

    testWidgets('paints the host palette on the panel and a hovered row', (
      tester,
    ) async {
      MagicStarter.useWindTheme(hostTheme);
      await open(tester, data: hostTheme);

      expect(fillsOf(tester, panel()).first, const Color(0xFF202024));

      final resting = fillsOf(tester, rowOf('auth.profile'));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('auth.profile')));
      // The row animates its fill (`transition-colors`), so one frame in it is
      // still the resting colour.
      await tester.pumpAndSettle();

      // The row gains its own fill, and the tile keeps a different one so it
      // stays visible on the hovered row.
      final hovered = fillsOf(tester, rowOf('auth.profile'));
      expect(hovered.length, resting.length + 1);
      expect(hovered.first, const Color(0xFF303036));
      expect(hovered.last, const Color(0xFF101012));
      expect(resting, [const Color(0xFF101012)]);
    });
  });
}
