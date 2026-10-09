import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_payments/magic_payments.dart';
import 'package:magic_starter/magic_starter.dart';

/// A store rail that records every id it was told to bill.
class _RecordingStoreRail implements StoreBillingService {
  final List<String> identifiedIds = [];

  @override
  Future<void> identify(String appUserId) async => identifiedIds.add(appUserId);

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
  Future<void> openStoreManagement() async {}

  @override
  ManageVia get store => ManageVia.appStore;
}

/// A store rail whose `identify` throws a plain (non-[BillingException])
/// error, the shape [StoreIdentitySync.syncNow] does not swallow and
/// rethrows to its caller.
class _ThrowingStoreRail implements StoreBillingService {
  @override
  Future<void> identify(String appUserId) async =>
      throw StateError('rail unreachable');

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
  Future<void> openStoreManagement() async {}

  @override
  ManageVia get store => ManageVia.appStore;
}

void main() {
  // The provider's boot reads `WidgetsBinding.instance` for its primary colour
  // fallback, and every test here boots it for real.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingStoreRail store;

  /// The team the backend holds as current; a successful switch moves it.
  dynamic activeTeamId;

  /// Whether the backend accepts the next switch.
  late bool acceptSwitch;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Magic.singleton('log', () => LogManager());
    Payments.manager.forgetDrivers();
    StoreIdentitySync.detach();
    Config.set('magic_starter.billing.billable', null);

    store = _RecordingStoreRail();
    Payments.extend(PaymentsManager.storeRole, () => store);

    activeTeamId = 10;
    acceptSwitch = true;
    Http.fake((MagicRequest request) {
      if (!acceptSwitch) {
        return Http.response({'message': 'Invalid team'}, 422);
      }

      activeTeamId = (request.data as Map<String, dynamic>)['team_id'];

      return Http.response();
    });

    Auth.fake(user: MagicStarterAuthUser.fromMap({'id': 42, 'name': 'Alice'}));
  });

  tearDown(() {
    StoreIdentitySync.detach();
    StoreIdentitySync.billableId = null;
    Payments.manager.forgetDrivers();
    Http.unfake();
    Auth.unfake();
  });

  Future<void> bootProvider() async {
    final provider = MagicStarterServiceProvider(MagicApp.instance);
    provider.register();
    await provider.boot();

    MagicStarter.useTeamResolver(
      currentTeam: () => MagicStarterTeam(id: activeTeamId),
      allTeams: () => [MagicStarterTeam(id: activeTeamId)],
      onSwitch: (dynamic id) => MagicStarter.switchTeam('$id'),
    );
  }

  group('MagicStarter.switchTeam', () {
    test('identifies the store as the team it landed on', () async {
      Config.set('magic_starter.billing.billable', 'team');
      await bootProvider();

      final bool switched = await MagicStarter.switchTeam('20');

      expect(switched, isTrue);
      expect(store.identifiedIds, ['20']);
    });

    test(
      'identifies the accepted team while the resolver still lags',
      () async {
        Config.set('magic_starter.billing.billable', 'team');
        await bootProvider();

        // `Auth.restore()` answers with the CACHED user, so right after the
        // switch the resolver still names the team being left.
        MagicStarter.useTeamResolver(
          currentTeam: () => const MagicStarterTeam(id: 10),
          allTeams: () => [const MagicStarterTeam(id: 10)],
          onSwitch: (dynamic id) => MagicStarter.switchTeam('$id'),
        );

        expect(await MagicStarter.switchTeam('20'), isTrue);
        expect(store.identifiedIds, ['20']);
        expect(MagicStarter.currentTeamId(), '10');
      },
    );

    test('does not identify when the switch is refused', () async {
      Config.set('magic_starter.billing.billable', 'team');
      await bootProvider();
      acceptSwitch = false;

      final bool switched = await MagicStarter.switchTeam('20');

      expect(switched, isFalse);
      expect(store.identifiedIds, isEmpty);
    });

    test('identifies the user when the user is the billable', () async {
      await bootProvider();

      final bool switched = await MagicStarter.switchTeam('20');

      expect(switched, isTrue);
      expect(store.identifiedIds, ['42']);
    });

    test('answers the switch without a store rail', () async {
      // A `flutter test` host is a desktop, where the factory answers no
      // store rail once the recording one is dropped.
      Payments.manager.forgetDrivers();
      await bootProvider();

      expect(await MagicStarter.switchTeam('20'), isTrue);
    });

    test(
      'still answers true when the store re-identify throws, and logs it',
      () async {
        // The backend already switched the team by the time syncNow() runs;
        // a non-BillingException from the rail must not read back as a
        // failed switch (magic_deeplink's gate would call `onSwitchFailed`
        // for a team change that in fact landed).
        Config.set('magic_starter.billing.billable', 'team');
        Payments.manager.forgetDrivers();
        Payments.extend(PaymentsManager.storeRole, () => _ThrowingStoreRail());
        final log = Log.fake();
        await bootProvider();

        final bool switched = await MagicStarter.switchTeam('20');

        expect(switched, isTrue);
        expect(
          log.entries.where(
            (entry) =>
                entry.level == 'error' &&
                entry.message.contains('rail unreachable'),
          ),
          hasLength(1),
        );
        Log.unfake();
      },
    );
  });

  group('MagicStarter.currentTeamId', () {
    test('answers the active team id as a string', () async {
      await bootProvider();

      expect(MagicStarter.currentTeamId(), '10');
    });

    test('answers null without a team resolver', () {
      Magic.singleton('magic_starter', () => MagicStarterManager());

      expect(MagicStarter.currentTeamId(), isNull);
    });
  });

  group('magic_starter.billing.billable', () {
    test('refuses a value other than user or team at boot', () async {
      Config.set('magic_starter.billing.billable', 'account');

      await expectLater(bootProvider(), throwsStateError);
    });

    test('the resolver is set at register(), before boot() runs', () async {
      Config.set('magic_starter.billing.billable', 'team');
      Auth.fake(
        user: MagicStarterAuthUser.fromMap({'id': 42, 'name': 'Alice'}),
      );

      final provider = MagicStarterServiceProvider(MagicApp.instance);
      provider.register();
      MagicStarter.useTeamResolver(
        currentTeam: () => MagicStarterTeam(id: activeTeamId),
        allTeams: () => [MagicStarterTeam(id: activeTeamId)],
        onSwitch: (dynamic id) => MagicStarter.switchTeam('$id'),
      );

      // No boot() at all: the resolver only reads state lazily when called.
      expect(StoreIdentitySync.billableId, isNotNull);
      expect(StoreIdentitySync.billableId!(), '10');
    });
  });
}
