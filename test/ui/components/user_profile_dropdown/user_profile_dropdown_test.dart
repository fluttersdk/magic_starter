import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/user_profile_dropdown/user_profile_dropdown.preview.dart';

class MockGuard implements Guard {
  Authenticatable? _user;

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    _user = user;
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
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
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

  testWidgets('renders fallback initial when no user', (tester) async {
    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);
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

    // trans('common.user')[0] is the fallback avatar initial.
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();

    expect(find.text('auth.profile'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
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

    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('shows logout item in dropdown and handles tap', (tester) async {
    bool logoutCalled = false;
    MagicStarter.manager.onLogout = () async {
      logoutCalled = true;
    };

    await tester.pumpWidget(wrap(const MSUserProfileDropdown()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('C'));
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

    await tester.tap(find.text('C'));
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

    await tester.tap(find.text('C'));
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
}
