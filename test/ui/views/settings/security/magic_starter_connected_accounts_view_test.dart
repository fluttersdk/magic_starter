import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/views/settings/security/magic_starter_connected_accounts_view.dart';

/// The package's shipped `social` copy, so an assertion on a sentence is an
/// assertion about what a host installs rather than a literal typed here.
class _ShippedCatalogueLoader implements TranslationLoader {
  const _ShippedCatalogueLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async => {
    for (final entry in _shippedSocial().entries)
      'social.${entry.key}': entry.value,
  };
}

Map<String, dynamic> _shippedSocial() {
  final stub =
      jsonDecode(File('assets/stubs/install/en.stub').readAsStringSync())
          as Map<String, dynamic>;

  return stub['social'] as Map<String, dynamic>;
}

String _shipped(String key, [Map<String, String> replace = const {}]) =>
    trans('social.$key', replace);

/// Answers requests from a FIFO queue and records the last one.
class _MockNetworkDriver implements NetworkDriver {
  final List<MagicResponse> _queue = [];
  final List<String> requests = [];

  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

  void mockResponse({required int statusCode, dynamic data}) =>
      _queue.add(MagicResponse(data: data ?? {}, statusCode: statusCode));

  MagicResponse _respond(String method, String url, {dynamic data}) {
    lastMethod = method;
    lastUrl = url;
    lastData = data;
    requests.add('$method $url');

    return _queue.isNotEmpty
        ? _queue.removeAt(0)
        : MagicResponse(data: {}, statusCode: 500);
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => _respond('GET', url);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => _respond('DELETE', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async => _respond('INDEX', resource);

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async => _respond('UPLOAD', url, data: data);
}

/// A guard whose user data a test can move, the way the backend would.
class _MockGuard implements Guard {
  Map<String, dynamic>? userData;

  /// Runs on every [restore], so a test can move the account on the way the
  /// backend would.
  void Function(_MockGuard guard)? onRestore;
  int restores = 0;

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {}

  @override
  Future<void> logout() async => userData = null;

  @override
  bool check() => userData != null;

  @override
  bool get guest => !check();

  @override
  T? user<T extends Model>() =>
      userData == null ? null : MagicStarterAuthUser.fromMap(userData!) as T?;

  @override
  dynamic id() => userData?['id'];

  @override
  void setUser(Authenticatable user) {}

  @override
  Future<bool> hasToken() async => true;

  @override
  Future<String?> getToken() async => 'token';

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {
    restores++;
    onRestore?.call(this);
  }

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier<int>(0);
}

/// A bridge whose connect answers, or fails, as scripted.
class _FakeSocialAuth implements MagicStarterSocialAuth {
  final List<String> beginCalls = [];
  final List<Map<String, String>> beginProofs = [];
  int openerCalls = 0;

  /// One failure per `beginConnect` call, consumed in order.
  final List<MagicStarterSocialException> beginFailures = [];
  MagicStarterSocialException? openFailure;

  @override
  List<String> providers() => const ['google', 'github'];

  @override
  String label(String provider) => provider == 'github' ? 'GitHub' : 'Google';

  @override
  Widget icon(String provider) => SizedBox(key: ValueKey('icon-$provider'));

  @override
  Future<Map<String, dynamic>> signIn(String provider) =>
      throw UnimplementedError();

  @override
  Future<Future<Map<String, dynamic>> Function()> beginConnect(
    String provider,
    Map<String, String> proof,
  ) async {
    beginCalls.add(provider);
    beginProofs.add(proof);
    if (beginFailures.isNotEmpty) throw beginFailures.removeAt(0);

    return () async {
      openerCalls++;
      final failure = openFailure;
      if (failure != null) throw failure;

      return {
        'data': {'provider': provider, 'email': 'ada@example.com'},
      };
    };
  }

  @override
  Future<String> confirm(String provider) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

Map<String, dynamic> _user({
  bool hasPassword = true,
  List<Map<String, dynamic>> accounts = const [],
}) => {
  'id': 1,
  'name': 'Ada',
  'email': 'ada@example.com',
  'has_password': hasPassword,
  'social_accounts': accounts,
};

Map<String, dynamic> _link(
  String provider, {
  String? email,
  String? revokedAt,
}) => {
  'provider': provider,
  'email_at_link': email ?? '$provider@example.com',
  'created_at': '2026-10-01T10:00:00.000000Z',
  'revoked_at': revokedAt,
};

void main() {
  late _MockNetworkDriver mockDriver;
  late _MockGuard mockGuard;
  late _FakeSocialAuth bridge;

  Widget wrap(Widget widget) => MaterialApp(
    builder: (context, child) =>
        WindTheme(data: WindThemeData(), child: child!),
    home: Scaffold(body: SingleChildScrollView(child: widget)),
  );

  /// The [WButton] whose label is [label], inside the row of [provider].
  Finder buttonLabelled(String label) => find.byWidgetPredicate(
    (widget) =>
        widget is WButton &&
        widget.child is WText &&
        (widget.child as WText).data == label,
  );

  Future<void> pumpView(
    WidgetTester tester, {
    bool openerNeedsTap = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(MagicStarterConnectedAccountsView(openerNeedsTap: openerNeedsTap)),
    );
    await tester.pump();
  }

  /// Types [password] into the confirmation dialog and confirms it.
  Future<void> confirmWithPassword(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(EditableText), password);
    await tester.tap(find.text('common.confirm'));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    MagicApp.reset();
    Magic.flush();

    mockDriver = _MockNetworkDriver();
    Magic.singleton('network', () => mockDriver);
    Magic.singleton('log', () => LogManager());

    mockGuard = _MockGuard()
      ..userData = _user(accounts: [_link('google', email: 'ada@gmail.com')]);
    Magic.singleton('auth', () => AuthManager());
    Auth.manager.forgetGuards();
    Auth.manager.extend('mock', (_) => mockGuard);
    Config.set('auth.defaults.guard', 'mock');
    Config.set('auth.guards', {
      'mock': {'driver': 'mock'},
    });

    Config.set('magic_starter.features.social_login', true);
    Magic.singleton('magic_starter', () => MagicStarterManager());
    bridge = _FakeSocialAuth();
    MagicStarter.useSocialAuth(bridge);
    Magic.put(MagicStarterProfileController());

    Gate.flush();

    Translator.instance.setLoader(const _ShippedCatalogueLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    Auth.manager.forgetGuards();
    Gate.flush();
  });

  group('MagicStarterConnectedAccountsView', () {
    testWidgets('renders an empty page when the app set no bridge', (
      tester,
    ) async {
      MagicStarter.manager.socialAuth = null;

      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(_shipped('connected_accounts')), findsOneWidget);
      expect(buttonLabelled(_shipped('connect')), findsNothing);
    });

    testWidgets('lists every provider the bridge offers', (tester) async {
      await pumpView(tester);

      expect(find.text('Google'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.byKey(const ValueKey('icon-google')), findsOneWidget);
      expect(find.byKey(const ValueKey('icon-github')), findsOneWidget);
    });

    testWidgets('a linked provider shows its email and Disconnect', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('ada@gmail.com'), findsOneWidget);
      expect(buttonLabelled(_shipped('disconnect')), findsOneWidget);
      expect(buttonLabelled(_shipped('connect')), findsOneWidget);
    });

    testWidgets('a revoked link counts as unlinked', (tester) async {
      mockGuard.userData = _user(
        accounts: [_link('google', revokedAt: '2026-10-02T10:00:00.000000Z')],
      );

      await pumpView(tester);

      expect(buttonLabelled(_shipped('disconnect')), findsNothing);
      expect(buttonLabelled(_shipped('connect')), findsNWidgets(2));
    });

    group('disconnect', () {
      testWidgets('a linked Google row disconnects with DELETE', (
        tester,
      ) async {
        mockDriver.mockResponse(statusCode: 204);
        mockGuard.onRestore = (guard) => guard.userData = _user();

        await pumpView(tester);
        await tester.tap(buttonLabelled(_shipped('disconnect')));
        await tester.pumpAndSettle();

        expect(mockDriver.lastMethod, equals('DELETE'));
        expect(mockDriver.lastUrl, equals('/user/social-accounts/google'));
        expect(mockGuard.restores, equals(1));
        // The restored user has no link left, so the row offers Connect.
        expect(buttonLabelled(_shipped('disconnect')), findsNothing);
        expect(buttonLabelled(_shipped('connect')), findsNWidgets(2));
      });

      testWidgets('a 422 last_login_method shows the shipped sentence', (
        tester,
      ) async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'The server wording.',
            'code': 'last_login_method',
            'errors': {
              'provider': ['The server wording.'],
            },
          },
        );

        await pumpView(tester);
        await tester.tap(buttonLabelled(_shipped('disconnect')));
        await tester.pumpAndSettle();

        expect(
          find.text(_shippedSocial()['last_login_method'] as String),
          findsOneWidget,
        );
        expect(find.text('The server wording.'), findsNothing);
        // The link is still there.
        expect(buttonLabelled(_shipped('disconnect')), findsOneWidget);
      });

      testWidgets(
        'a password-less user with exactly one active link cannot disconnect',
        (tester) async {
          mockGuard.userData = _user(
            hasPassword: false,
            accounts: [
              _link('google'),
              _link('github', revokedAt: '2026-10-02T10:00:00.000000Z'),
            ],
          );

          await pumpView(tester);

          final button = tester.widget<WButton>(
            buttonLabelled(_shipped('disconnect')),
          );
          expect(button.onTap, isNull);
          await tester.tap(
            buttonLabelled(_shipped('disconnect')),
            warnIfMissed: false,
          );
          await tester.pumpAndSettle();
          expect(mockDriver.requests, isEmpty);
        },
      );

      testWidgets('a password-less user with two active links can', (
        tester,
      ) async {
        mockGuard.userData = _user(
          hasPassword: false,
          accounts: [_link('google'), _link('github')],
        );

        await pumpView(tester);

        for (final button in tester.widgetList<WButton>(
          buttonLabelled(_shipped('disconnect')),
        )) {
          expect(button.onTap, isNotNull);
        }
      });

      testWidgets('a user with a password can drop their only link', (
        tester,
      ) async {
        await pumpView(tester);

        final button = tester.widget<WButton>(
          buttonLabelled(_shipped('disconnect')),
        );
        expect(button.onTap, isNotNull);
      });
    });

    group('connect', () {
      testWidgets(
        'confirms identity, then calls beginConnect with that proof and opens',
        (tester) async {
          mockGuard.onRestore = (guard) => guard.userData = _user(
            accounts: [
              _link('google'),
              _link('github', email: 'ada@gh.dev'),
            ],
          );

          await pumpView(tester);
          await tester.tap(buttonLabelled(_shipped('connect')));
          await tester.pumpAndSettle();
          // Nothing starts before the user has confirmed.
          expect(bridge.beginCalls, isEmpty);

          await confirmWithPassword(tester, 'secret-123');

          expect(bridge.beginCalls, equals(['github']));
          expect(
            bridge.beginProofs,
            equals([
              {'password': 'secret-123'},
            ]),
          );
          expect(bridge.openerCalls, equals(1));
          expect(mockGuard.restores, equals(1));
          expect(find.text('ada@gh.dev'), findsOneWidget);
        },
      );

      testWidgets('a guest connects with no proof and no dialog', (
        tester,
      ) async {
        mockGuard.userData = {..._user(hasPassword: false), 'is_guest': true};

        await pumpView(tester);
        await tester.tap(buttonLabelled(_shipped('connect')).first);
        await tester.pumpAndSettle();

        expect(find.byType(EditableText), findsNothing);
        expect(bridge.beginProofs, equals([<String, String>{}]));
        expect(bridge.openerCalls, equals(1));
      });

      testWidgets('cancelling the confirmation starts nothing', (tester) async {
        await pumpView(tester);
        await tester.tap(buttonLabelled(_shipped('connect')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('common.cancel'));
        await tester.pumpAndSettle();

        expect(bridge.beginCalls, isEmpty);
      });

      testWidgets('on the web the opener waits for a fresh tap on Continue', (
        tester,
      ) async {
        await pumpView(tester, openerNeedsTap: true);
        await tester.tap(buttonLabelled(_shipped('connect')));
        await tester.pumpAndSettle();
        await confirmWithPassword(tester, 'secret-123');

        // A popup opened after an await is blocked, so the opener has not
        // run: the user is asked to tap.
        expect(bridge.beginCalls, equals(['github']));
        expect(bridge.openerCalls, equals(0));
        final continueButton = buttonLabelled(
          _shipped('continue_with', {'provider': 'GitHub'}),
        );
        expect(continueButton, findsOneWidget);

        await tester.tap(continueButton);
        await tester.pumpAndSettle();

        expect(bridge.openerCalls, equals(1));
        expect(mockGuard.restores, equals(1));
        expect(continueButton, findsNothing);
      });

      for (final code in [
        'step_up_required',
        'social_account_taken',
        'flow_expired',
      ]) {
        testWidgets('$code from beginConnect shows its sentence', (
          tester,
        ) async {
          bridge.beginFailures.add(MagicStarterSocialException(code: code));

          await pumpView(tester);
          await tester.tap(buttonLabelled(_shipped('connect')));
          await tester.pumpAndSettle();
          await confirmWithPassword(tester, 'secret-123');

          expect(find.text(_shippedSocial()[code] as String), findsOneWidget);
          expect(bridge.openerCalls, equals(0));
        });
      }

      testWidgets('social_account_taken from the opener shows its sentence', (
        tester,
      ) async {
        bridge.openFailure = const MagicStarterSocialException(
          code: 'social_account_taken',
        );

        await pumpView(tester);
        await tester.tap(buttonLabelled(_shipped('connect')));
        await tester.pumpAndSettle();
        await confirmWithPassword(tester, 'secret-123');

        expect(
          find.text(_shippedSocial()['social_account_taken'] as String),
          findsOneWidget,
        );
        expect(mockGuard.restores, equals(0));
      });

      testWidgets(
        'a retry starts over: a fresh confirmation, a fresh beginConnect',
        (tester) async {
          bridge.beginFailures.add(
            const MagicStarterSocialException(code: 'flow_expired'),
          );

          await pumpView(tester);
          await tester.tap(buttonLabelled(_shipped('connect')));
          await tester.pumpAndSettle();
          await confirmWithPassword(tester, 'first-proof');
          expect(
            find.text(_shippedSocial()['flow_expired'] as String),
            findsOneWidget,
          );

          // The second attempt asks again; the first proof is not reused.
          await tester.tap(buttonLabelled(_shipped('connect')));
          await tester.pumpAndSettle();
          expect(find.byType(EditableText), findsOneWidget);
          await confirmWithPassword(tester, 'second-proof');

          expect(bridge.beginCalls, equals(['github', 'github']));
          expect(
            bridge.beginProofs,
            equals([
              {'password': 'first-proof'},
              {'password': 'second-proof'},
            ]),
          );
          expect(bridge.openerCalls, equals(1));
          // The sentence of the failed attempt is gone.
          expect(
            find.text(_shippedSocial()['flow_expired'] as String),
            findsNothing,
          );
        },
      );
    });
  });

  group('connected accounts route', () {
    setUp(() {
      MagicRouter.reset();
      Config.set('magic_starter.features.social_login', true);
    });

    tearDown(MagicRouter.reset);

    bool registered() {
      for (final layout in MagicRouter.instance.mergedLayouts) {
        for (final route in layout.children) {
          if (route.fullPath ==
              MagicStarterConfig.settingsConnectedAccountsRoute()) {
            return true;
          }
        }
      }

      return false;
    }

    test('lives under the profile prefix, beside the other security pages', () {
      expect(
        MagicStarterConfig.settingsConnectedAccountsRoute(),
        equals(
          '${MagicStarterConfig.profilePrefix()}/security/connected-accounts',
        ),
      );
    });

    test('is registered with the feature on and a bridge set', () {
      registerMagicStarterProfileRoutes();

      expect(registered(), isTrue);
    });

    test('is not registered with the feature off', () {
      Config.set('magic_starter.features.social_login', false);

      registerMagicStarterProfileRoutes();

      expect(registered(), isFalse);
    });

    test('is registered before any bridge is set', () {
      MagicStarter.manager.socialAuth = null;

      registerMagicStarterProfileRoutes();

      expect(registered(), isTrue);
    });

    test('resolves the registry view an app can override', () {
      registerMagicStarterProfileRoutes();

      expect(
        MagicStarter.view.make('settings.security.connected_accounts'),
        isA<MagicStarterConnectedAccountsView>(),
      );
    });
  });
}
