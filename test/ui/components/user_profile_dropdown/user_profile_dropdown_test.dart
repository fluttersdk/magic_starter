import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/user_profile_dropdown/index.dart';

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
  // Behavior equivalence gate — mirrors magic_starter_user_profile_dropdown_test
  // ---------------------------------------------------------------------------

  testWidgets('renders avatar with user initial when authenticated',
      (tester) async {
    mockGuard.setUser(MagicStarterAuthUser.fromMap({
      'id': 1,
      'name': 'John Doe',
      'email': 'john@example.com',
    }));
    await tester.pumpWidget(wrap(const UserProfileDropdown()));
    await tester.pumpAndSettle();
    expect(find.text('J'), findsOneWidget);
  });

  testWidgets('renders fallback initial when no user', (tester) async {
    await tester.pumpWidget(wrap(const UserProfileDropdown()));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('tapping avatar opens dropdown with user info', (tester) async {
    mockGuard.setUser(MagicStarterAuthUser.fromMap({
      'id': 1,
      'name': 'John Doe',
      'email': 'john@example.com',
    }));
    await tester.pumpWidget(wrap(const UserProfileDropdown()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('J'));
    await tester.pumpAndSettle();

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('john@example.com'), findsOneWidget);
  });

  testWidgets('uses default bottomRight alignment', (tester) async {
    await tester.pumpWidget(wrap(const UserProfileDropdown()));
    await tester.pumpAndSettle();
    final popover = tester.widget<WPopover>(find.byType(WPopover));
    expect(popover.alignment, PopoverAlignment.bottomRight);
  });

  testWidgets('accepts custom alignment parameter', (tester) async {
    await tester.pumpWidget(wrap(
      const UserProfileDropdown(alignment: PopoverAlignment.topRight),
    ));
    await tester.pumpAndSettle();
    final popover = tester.widget<WPopover>(find.byType(WPopover));
    expect(popover.alignment, PopoverAlignment.topRight);
  });

  testWidgets('uses custom triggerBuilder when provided', (tester) async {
    await tester.pumpWidget(wrap(
      UserProfileDropdown(
        triggerBuilder: (context, isOpen, isHovering) =>
            const Text('Custom Trigger'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Custom Trigger'), findsOneWidget);
  });

  testWidgets('UserProfileDropdown preview renders without error',
      (tester) async {
    await tester.pumpWidget(wrap(const UserProfileDropdownPreview()));
    await tester.pump();
    expect(find.byType(UserProfileDropdownPreview), findsOneWidget);
  });
}
