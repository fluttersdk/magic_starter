import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class MockGuard implements Guard {
  Authenticatable? _user;
  bool logoutCalled = false;

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    _user = user;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
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
  String? pushedRoute;

  @override
  void push(String path) {
    pushedRoute = path;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockGuard mockGuard;
  late MockRouter mockRouter;

  setUp(() {
    MagicApp.reset();
    Magic.flush();

    // Mock LogManager
    Magic.singleton('log', () => LogManager());
    Config.set('logging', {
      'default': 'console',
      'channels': {
        'console': {'driver': 'console', 'level': 'debug'},
      },
    });

    // Mock Auth guard
    mockGuard = MockGuard();
    Auth.manager.forgetGuards();
    Auth.manager.extend('mock', (_) => mockGuard);
    Config.set('auth.defaults.guard', 'mock');
    Config.set('auth.guards', {
      'mock': {'driver': 'mock'},
    });

    // Bind MagicStarterManager
    Magic.singleton('magic_starter', () => MagicStarterManager());

    MagicStarter.useNavigation(
      mainItems: [],
      profileMenuItems: [],
    );

    // Mock Router
    mockRouter = MockRouter();
    Magic.singleton('router', () => mockRouter);
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

  testWidgets('renders avatar with user initial when authenticated',
      (tester) async {
    mockGuard.setUser(MagicStarterAuthUser.fromMap({
      'id': 1,
      'name': 'John Doe',
      'email': 'john@example.com',
    }));

    await tester.pumpWidget(wrap(const MagicStarterUserProfileDropdown()));
    await tester.pumpAndSettle();

    expect(find.text('J'), findsOneWidget);
  });

  testWidgets('renders fallback initial when no user', (tester) async {
    await tester.pumpWidget(wrap(const MagicStarterUserProfileDropdown()));
    await tester.pumpAndSettle();

    expect(find.text('C'), findsOneWidget); // trans('common.user')[0]
  });

  testWidgets('tapping avatar opens dropdown with user info', (tester) async {
    mockGuard.setUser(MagicStarterAuthUser.fromMap({
      'id': 1,
      'name': 'John Doe',
      'email': 'john@example.com',
    }));

    await tester.pumpWidget(wrap(const MagicStarterUserProfileDropdown()));
    await tester.pumpAndSettle();

    // Tap avatar trigger
    await tester.tap(find.text('J'));
    await tester.pumpAndSettle();

    // Find user name and email in dropdown
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('john@example.com'), findsOneWidget);
    expect(find.text('auth.signed_in_as'.toUpperCase()), findsOneWidget);
  });

  testWidgets('shows profile settings menu item in dropdown', (tester) async {
    await tester.pumpWidget(wrap(const MagicStarterUserProfileDropdown()));
    await tester.pumpAndSettle();

    // Tap avatar trigger
    await tester.tap(find.text('C')); // trans('common.user')[0]
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

    await tester.pumpWidget(wrap(const MagicStarterUserProfileDropdown()));
    await tester.pumpAndSettle();

    // Tap avatar trigger
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

    await tester.pumpWidget(wrap(const MagicStarterUserProfileDropdown()));
    await tester.pumpAndSettle();

    // Tap avatar trigger
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();

    expect(find.text('auth.logout'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);

    await tester.tap(find.text('auth.logout'));
    await tester.pumpAndSettle();

    expect(logoutCalled, isTrue);
  });

  testWidgets('uses default bottomRight alignment', (tester) async {
    await tester.pumpWidget(wrap(const MagicStarterUserProfileDropdown()));
    await tester.pumpAndSettle();

    final popover = tester.widget<WPopover>(find.byType(WPopover));
    expect(popover.alignment, PopoverAlignment.bottomRight);
  });

  testWidgets('accepts custom alignment parameter', (tester) async {
    await tester.pumpWidget(wrap(
      const MagicStarterUserProfileDropdown(
        alignment: PopoverAlignment.topRight,
      ),
    ));
    await tester.pumpAndSettle();

    final popover = tester.widget<WPopover>(find.byType(WPopover));
    expect(popover.alignment, PopoverAlignment.topRight);
  });

  testWidgets('uses custom triggerBuilder when provided', (tester) async {
    await tester.pumpWidget(wrap(
      MagicStarterUserProfileDropdown(
        triggerBuilder: (context, isOpen, isHovering) =>
            const Text('Custom Trigger'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Custom Trigger'), findsOneWidget);
  });
}
