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
}
