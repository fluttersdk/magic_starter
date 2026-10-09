import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_payments/magic_payments.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver — intercepts all Http facade calls
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;

  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(data: data ?? {}, statusCode: statusCode);
  }

  MagicResponse _respond(String method, String url, {dynamic data}) {
    lastMethod = method;
    lastUrl = url;
    lastData = data;
    return nextResponse ?? MagicResponse(data: {}, statusCode: 500);
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

  bool get hasInterceptors => false;
}

// ---------------------------------------------------------------------------
// Mock Guard — tracks auth state
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool logoutCalled = false;
  bool restoreCalled = false;
  String? mockToken = 'mock-token';

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    mockToken = data['token'] as String?;
    _user = user;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    _user = null;
    mockToken = null;
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
  Future<bool> hasToken() async => mockToken != null;

  @override
  Future<String?> getToken() async => mockToken;

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {
    restoreCalled = true;
    if (mockToken != null) {
      _user = MagicStarterAuthUser.fromMap({'id': 1, 'name': 'Restored User'});
    }
  }

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
}

// ---------------------------------------------------------------------------
// Test Suite
// ---------------------------------------------------------------------------

void main() {
  Widget wrap(Widget widget) {
    // The theme wraps the Navigator, so a dialog (an overlay entry) has it too.
    return MaterialApp(
      builder: (context, child) =>
          WindTheme(data: WindThemeData(), child: child!),
      home: Scaffold(body: SingleChildScrollView(child: widget)),
    );
  }

  group('MagicStarterProfileSettingsView — delete account section', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      MagicApp.reset();
      Magic.flush();

      // 1. Bind mock network driver.
      mockDriver = MockNetworkDriver();
      Magic.singleton('network', () => mockDriver);

      // 2. Bind log manager.
      Magic.singleton('log', () => LogManager());

      // 3. Bind auth with mock guard.
      mockGuard = MockGuard();
      Magic.singleton('auth', () => AuthManager());
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {'driver': 'mock'},
      });

      // 4. Set authenticated user.
      mockGuard.setUser(
        MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Test User',
          'email': 'test@example.com',
        }),
      );

      // 5. Bind MagicStarterManager.
      Magic.singleton('magic_starter', () => MagicStarterManager());

      // 6. Create and inject controller.
      Magic.put(MagicStarterProfileController());

      // 7. Register Gate abilities — non-guest user has all abilities.
      Gate.flush();
      Gate.define('starter.update-profile-photo', (user, [_]) => true);
      Gate.define('starter.update-email', (user, [_]) => true);
      Gate.define('starter.update-phone', (user, [_]) => true);
      Gate.define('starter.update-password', (user, [_]) => true);
      Gate.define('starter.verify-email', (user, [_]) => true);
      Gate.define('starter.manage-two-factor', (user, [_]) => true);
      Gate.define('starter.manage-newsletter', (user, [_]) => true);
      Gate.define('starter.logout-sessions', (user, [_]) => true);
      Gate.define('starter.delete-account', (user, [_]) => true);
    });

    tearDown(() {
      Auth.manager.forgetGuards();
      Gate.flush();
    });

    const scheduledKey =
        'magic_starter.profile.delete_account.option_scheduled';
    const immediateKey =
        'magic_starter.profile.delete_account.option_immediate';

    Finder choiceButton(String key) => find.byWidgetPredicate(
      (widget) =>
          widget is WButton &&
          widget.child is WText &&
          (widget.child as WText).data == trans(key),
    );

    /// Opens the delete choice: scrolls to the section's button, taps it.
    Future<void> openChoice(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final button = find.byWidgetPredicate(
        (widget) =>
            widget is WButton &&
            widget.child is WText &&
            (widget.child as WText).data ==
                trans('magic_starter.profile.delete_account.button'),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    /// Opens the delete choice and picks one: the scheduled deletion unless
    /// [immediately].
    Future<void> tapDelete(
      WidgetTester tester, {
      bool immediately = false,
    }) async {
      await openChoice(tester);
      await tester.tap(choiceButton(immediately ? immediateKey : scheduledKey));
      await tester.pumpAndSettle();
    }

    /// Types [password] into the confirmation dialog and confirms it.
    Future<void> confirmWithPassword(
      WidgetTester tester,
      String password,
    ) async {
      await tester.enterText(
        find.descendant(
          of: find.byType(MagicStarterPasswordConfirmDialog),
          matching: find.byType(EditableText),
        ),
        password,
      );
      await tester.tap(find.text('common.confirm'));
    }

    /// Mounts the view as the router's home, with a login page to land on, so
    /// the toast and the navigation are real.
    ///
    /// [WindTheme] sits above the app because a toast is inserted into the
    /// Navigator's overlay, a sibling of the routed pages.
    Future<void> mountWithRouter(WidgetTester tester) async {
      MagicRouter.reset();
      addTearDown(MagicRouter.reset);
      MagicRoute.page('/', () => const MagicStarterProfileSettingsView());
      MagicRoute.page(
        MagicStarterConfig.loginRoute(),
        () => const Text('login page'),
      );
      MagicRouter.instance.setInitialLocation('/');

      await tester.pumpWidget(
        WindTheme(
          data: WindThemeData(),
          child: MaterialApp.router(
            routerConfig: MagicRouter.instance.routerConfig,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'delete account is a button that asks for the password, with no inline field',
      (tester) async {
        await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));
        await tapDelete(tester);

        expect(find.byType(MagicStarterPasswordConfirmDialog), findsOneWidget);
        expect(find.byType(MagicStarterStepUpDialog), findsNothing);
        // Nothing is sent until the dialog confirms.
        expect(mockDriver.lastMethod, isNull);
      },
    );

    testWidgets('the confirmed password rides the delete request', (
      tester,
    ) async {
      mockDriver.mockResponse(statusCode: 202, data: {'message': 'Scheduled'});

      await mountWithRouter(tester);
      await tapDelete(tester);
      await confirmWithPassword(tester, 'mysecretpass');
      await tester.pumpAndSettle();

      expect(mockDriver.lastMethod, equals('POST'));
      expect(mockDriver.lastUrl, equals('/user'));
      expect(
        mockDriver.lastData,
        equals({'_method': 'DELETE', 'password': 'mysecretpass'}),
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'delete account first offers a scheduled and an immediate choice, the '
      'immediate one styled destructive',
      (tester) async {
        await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));
        await openChoice(tester);

        final scheduled = tester.widget<WButton>(choiceButton(scheduledKey));
        final immediate = tester.widget<WButton>(choiceButton(immediateKey));
        final danger = MagicStarter.manager.modalTheme.dangerButtonClassName;

        expect(immediate.className, equals(danger));
        expect(scheduled.className, isNot(equals(danger)));
        // Nothing is asked or sent until a choice is made.
        expect(find.byType(MagicStarterPasswordConfirmDialog), findsNothing);
        expect(mockDriver.lastMethod, isNull);
      },
    );

    testWidgets('cancelling the choice sends nothing and asks for nothing', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));
      await openChoice(tester);

      await tester.tap(find.text('common.cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterPasswordConfirmDialog), findsNothing);
      expect(mockDriver.lastMethod, isNull);
    });

    testWidgets(
      'choosing "Delete now" posts immediately: true with the proof',
      (tester) async {
        mockDriver.mockResponse(
          statusCode: 202,
          data: {
            'data': {
              'deletion_scheduled_at': '2026-10-05T12:00:00.000000Z',
              'immediate': true,
            },
            'message': 'Your account is being deleted.',
          },
        );

        await mountWithRouter(tester);
        await tapDelete(tester, immediately: true);
        await confirmWithPassword(tester, 'mysecretpass');
        await tester.pump();
        await tester.pump();

        expect(
          mockDriver.lastData,
          equals({
            '_method': 'DELETE',
            'password': 'mysecretpass',
            'immediately': true,
          }),
        );
        expect(mockGuard.logoutCalled, isTrue);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('login page'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a password-less account is offered the step-up dialog', (
      tester,
    ) async {
      mockGuard.setUser(
        MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Test User',
          'email': 'test@example.com',
          'has_password': false,
          'two_factor_enabled': true,
        }),
      );

      await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));
      await tapDelete(tester);

      expect(find.byType(MagicStarterStepUpDialog), findsOneWidget);
      expect(find.byType(MagicStarterPasswordConfirmDialog), findsNothing);
    });

    testWidgets('a guest deletes with no proof and no dialog', (tester) async {
      mockGuard.setUser(
        MagicStarterAuthUser.fromMap({
          'id': 1,
          'name': 'Guest',
          'has_password': false,
          'is_guest': true,
        }),
      );
      mockDriver.mockResponse(statusCode: 202, data: {'message': 'Scheduled'});

      await mountWithRouter(tester);
      await tapDelete(tester);

      expect(find.byType(MagicStarterPasswordConfirmDialog), findsNothing);
      expect(find.byType(MagicStarterStepUpDialog), findsNothing);
      expect(mockDriver.lastData, equals({'_method': 'DELETE'}));

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'a 202 shows the server message, signs out and lands on login',
      (tester) async {
        const message =
            'Your account will be deleted in 30 days. Sign in again before '
            'then to cancel the deletion.';
        mockDriver.mockResponse(
          statusCode: 202,
          data: {
            'data': {'deletion_scheduled_at': '2026-11-04T12:00:00.000000Z'},
            'message': message,
          },
        );

        await mountWithRouter(tester);
        await tapDelete(tester);
        await confirmWithPassword(tester, 'mysecretpass');
        await tester.pump();
        await tester.pump();

        expect(mockGuard.logoutCalled, isTrue);
        expect(find.text(message), findsOneWidget);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('login page'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a 422 owns_shared_teams shows its sentence and keeps the user signed in',
      (tester) async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'The server wording.',
            'code': 'owns_shared_teams',
            'team_ids': ['9a8b7c6d'],
            'errors': {
              'user': ['The server wording.'],
            },
          },
        );

        await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));
        await tapDelete(tester);
        await confirmWithPassword(tester, 'mysecretpass');
        await tester.pumpAndSettle();

        // No new proof fixes this refusal: the dialog closes and the
        // controller keeps the code's sentence (a key here: no catalogue is
        // loaded) rather than the server's, followed by the blocking teams.
        expect(find.byType(MagicStarterPasswordConfirmDialog), findsNothing);
        expect(
          Magic.find<MagicStarterProfileController>().rxStatus.message,
          'social.owns_shared_teams social.deletion_blocking_teams_count',
        );
        // Nothing to do about it from here, so there is no action to offer.
        expect(find.byType(MSDialog), findsNothing);
        expect(mockGuard.logoutCalled, isFalse);
        expect(Auth.check(), isTrue);
      },
    );

    group('an actionable refusal', () {
      late _RecordingLaunchAdapter launcher;
      late _RecordingStoreRail storeRail;

      setUp(() async {
        Translator.instance.setLoader(const _ShippedCatalogueLoader());
        await Translator.instance.setLocale(const Locale('en'));

        launcher = _RecordingLaunchAdapter();
        Magic.singleton('launch', () => LaunchService(adapter: launcher));

        storeRail = _RecordingStoreRail();
        Payments.manager.forgetDrivers();
        Payments.extend(PaymentsManager.storeRole, () => storeRail);

        Config.set('magic_starter.account.deletion_url', null);
        MagicStarter.manager.teamResolver = MagicStarterTeamResolverConfig(
          currentTeam: () => null,
          allTeams: () => const [MagicStarterTeam(id: 't1', name: 'Acme')],
          onSwitch: (_) async {},
        );
      });

      tearDown(() async {
        Payments.manager.forgetDrivers();
        Translator.instance.setLoader(const _EmptyCatalogueLoader());
        await Translator.instance.setLocale(const Locale('en'));
      });

      /// Runs the delete flow against a 422 `team_has_active_subscription`
      /// whose only blocking team, `t1`, is billed by [provider].
      Future<void> refuseWith(WidgetTester tester, String provider) async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'The server wording.',
            'code': 'team_has_active_subscription',
            'team_ids': ['t1'],
            'team_providers': {'t1': provider},
          },
        );

        await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));
        await tapDelete(tester);
        await confirmWithPassword(tester, 'mysecretpass');
        await tester.pumpAndSettle();
      }

      Finder actionButton(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is WButton &&
            widget.child is WText &&
            (widget.child as WText).data == label,
      );

      testWidgets(
        'stripe with a deletion_url names the team and opens that url',
        (tester) async {
          Config.set(
            'magic_starter.account.deletion_url',
            'https://example.com/account/delete',
          );

          await refuseWith(tester, 'stripe');

          expect(
            find.descendant(
              of: find.byType(MSDialog),
              matching: find.textContaining('Acme'),
            ),
            findsOneWidget,
          );
          expect(mockGuard.logoutCalled, isFalse);

          await tester.tap(actionButton('Open deletion page'));
          await tester.pumpAndSettle();

          expect(
            launcher.launched,
            equals([Uri.parse('https://example.com/account/delete')]),
          );
          expect(find.byType(MSDialog), findsNothing);
        },
      );

      testWidgets('stripe with no deletion_url offers no action', (
        tester,
      ) async {
        await refuseWith(tester, 'stripe');

        expect(actionButton('Open deletion page'), findsNothing);
        expect(find.byType(MSDialog), findsNothing);
        expect(launcher.launched, isEmpty);
        expect(
          Magic.find<MagicStarterProfileController>().rxStatus.message,
          startsWith(
            'One of your teams is billed by card. Cancel that subscription on '
            'the web, then delete your account.',
          ),
        );
      });

      testWidgets('a team no list resolves is counted, not named', (
        tester,
      ) async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'The server wording.',
            'code': 'team_has_active_subscription',
            'team_ids': ['t9'],
          },
        );

        await tester.pumpWidget(wrap(const MagicStarterProfileSettingsView()));
        await tapDelete(tester);
        await confirmWithPassword(tester, 'mysecretpass');
        await tester.pumpAndSettle();

        final message =
            Magic.find<MagicStarterProfileController>().rxStatus.message;
        expect(message, endsWith('1 of your teams.'));
        expect(message, isNot(contains('block the deletion')));
      });

      testWidgets('a play_store subscription offers store management', (
        tester,
      ) async {
        storeRail = _RecordingStoreRail(store: ManageVia.playStore);
        Payments.manager.forgetDrivers();
        Payments.extend(PaymentsManager.storeRole, () => storeRail);

        await refuseWith(tester, 'play_store');

        await tester.tap(actionButton('Manage subscription'));
        await tester.pumpAndSettle();

        expect(storeRail.managementOpened, equals(1));
        expect(launcher.launched, isEmpty);
        expect(find.byType(MSDialog), findsNothing);
      });

      testWidgets('a web build shows a play_store refusal as the sentence '
          'alone', (tester) async {
        // No store rail on the web: a "Manage subscription" button there would
        // open nothing at all.
        Payments.manager.forgetDrivers();

        await refuseWith(tester, 'play_store');

        expect(actionButton('Manage subscription'), findsNothing);
        expect(find.byType(MSDialog), findsNothing);
        expect(
          Magic.find<MagicStarterProfileController>().rxStatus.message,
          startsWith(
            'Your subscription was bought in the App Store or Google Play.',
          ),
        );
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Doubles for the actionable refusals
// ---------------------------------------------------------------------------

/// A launcher that records what it was asked to open instead of opening it.
class _RecordingLaunchAdapter implements LaunchAdapter {
  final List<Uri> launched = [];

  @override
  Future<bool> launch(
    Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    launched.add(url);

    return true;
  }

  @override
  Future<bool> canLaunch(Uri url) async => true;
}

/// A store rail that counts how often the store's management screen opened.
class _RecordingStoreRail implements StoreBillingService {
  _RecordingStoreRail({this.store = ManageVia.appStore});

  int managementOpened = 0;

  @override
  final ManageVia store;

  @override
  Future<void> identify(String appUserId) async {}

  @override
  Future<bool> purchase(String productKey, {PurchaseContext? context}) async =>
      false;

  @override
  StoreChangeTiming? get lastChangeTiming => null;

  @override
  Future<Map<String, StoreProductOffer>> products(
    List<String> productKeys,
  ) async => const <String, StoreProductOffer>{};

  @override
  Future<bool> restore() async => false;

  @override
  Future<void> openStoreManagement() async => managementOpened++;
}

/// The package's shipped `social` copy, so an assertion on a sentence is about
/// what a host installs rather than a literal typed here.
class _ShippedCatalogueLoader implements TranslationLoader {
  const _ShippedCatalogueLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final stub =
        jsonDecode(File('assets/stubs/install/en.stub').readAsStringSync())
            as Map<String, dynamic>;
    final social = stub['social'] as Map<String, dynamic>;

    return {
      for (final entry in social.entries) 'social.${entry.key}': entry.value,
    };
  }
}

/// No catalogue at all: every key answers as itself, the suite's default.
class _EmptyCatalogueLoader implements TranslationLoader {
  const _EmptyCatalogueLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async => <String, dynamic>{};
}
