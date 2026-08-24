import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Stand-in for a host app's own `User` model.
///
/// Lets the tests tell "the app's factory ran" apart from "the starter's
/// built-in MagicStarterAuthUser default ran", which is the silent breach
/// `bootstrap()` exists to close.
class _HostUser extends Model with Authenticatable {
  @override
  String get table => 'host_users';

  @override
  String get resource => 'host_users';

  static _HostUser fromMap(Map<String, dynamic> map) {
    return _HostUser()..setRawAttributes(map, sync: true);
  }
}

void main() {
  group('MagicStarter.bootstrap()', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      setUpMagicStarterForTests();
      MagicStarter.manager.reset();
    });

    tearDown(() {
      MagicStarter.manager.reset();
      MagicApp.reset();
      Magic.flush();
    });

    // -------------------------------------------------------------------------
    // The three universal pieces land exactly where their setters put them.
    // -------------------------------------------------------------------------

    group('universal identity', () {
      test('userFactory lands where useUserModel() puts it', () {
        Authenticatable factory(Map<String, dynamic> data) {
          return _HostUser.fromMap(data);
        }

        MagicStarter.bootstrap(
          userFactory: factory,
          onLogout: () async {},
          locales: const {'en': 'English'},
        );

        expect(MagicStarter.manager.userFactory, equals(factory));

        final Authenticatable user = MagicStarter.createUser({
          'id': 7,
          'name': 'Ada',
        });

        expect(user, isA<_HostUser>());
        expect(user, isNot(isA<MagicStarterAuthUser>()));
        expect((user as Model).get<String>('name'), 'Ada');
      });

      test('onLogout lands where useLogout() puts it', () async {
        bool calledLogout = false;

        Future<void> onLogout() async {
          calledLogout = true;
        }

        MagicStarter.bootstrap(
          userFactory: (data) => _HostUser.fromMap(data),
          onLogout: onLogout,
          locales: const {'en': 'English'},
        );

        expect(MagicStarter.manager.onLogout, equals(onLogout));

        await MagicStarter.manager.onLogout!();

        expect(calledLogout, isTrue);
      });

      test('locales land where useLocaleOptions() puts them', () {
        MagicStarter.bootstrap(
          userFactory: (data) => _HostUser.fromMap(data),
          onLogout: () async {},
          locales: const {'en': 'English', 'tr': 'Türkçe'},
        );

        final List<SelectOption<String>> options =
            MagicStarter.manager.localeOptions;

        expect(options.length, 2);
        expect(options.first.value, 'en');
        expect(options.first.label, 'English');
        expect(options.last.value, 'tr');
        expect(options.last.label, 'Türkçe');
        expect(MagicStarter.localeOptions, equals(options));
      });

      test('leaves the optional theming setters untouched', () {
        MagicStarter.bootstrap(
          userFactory: (data) => _HostUser.fromMap(data),
          onLogout: () async {},
          locales: const {'en': 'English'},
        );

        expect(MagicStarter.manager.navigationConfig, isNull);
        expect(MagicStarter.manager.headerBuilder, isNull);
        expect(MagicStarter.manager.socialLoginBuilder, isNull);
        expect(
          MagicStarter.navigationTheme,
          equals(const MagicStarterNavigationTheme()),
        );
        expect(MagicStarter.modalTheme, equals(const MagicStarterModalTheme()));
        expect(MagicStarter.formTheme, equals(const MagicStarterFormTheme()));
      });
    });

    // -------------------------------------------------------------------------
    // The team trio: optional as a group, never as individuals.
    // -------------------------------------------------------------------------

    group('team callbacks', () {
      test('the trio reaches manager.teamResolver as passed', () async {
        final MagicStarterTeam acme = MagicStarterTeam.fromMap({
          'id': 1,
          'name': 'Acme Corp',
        });
        final MagicStarterTeam beta = MagicStarterTeam.fromMap({
          'id': 2,
          'name': 'Beta Inc',
        });
        dynamic switchedTo;

        MagicStarterTeam? currentTeam() => acme;
        List<MagicStarterTeam> allTeams() => [acme, beta];
        Future<void> onSwitch(dynamic teamId) async {
          switchedTo = teamId;
        }

        MagicStarter.bootstrap(
          userFactory: (data) => _HostUser.fromMap(data),
          onLogout: () async {},
          locales: const {'en': 'English'},
          currentTeam: currentTeam,
          allTeams: allTeams,
          onSwitch: onSwitch,
        );

        final MagicStarterTeamResolverConfig? resolver =
            MagicStarter.manager.teamResolver;

        expect(resolver, isNotNull);
        expect(resolver!.currentTeam, equals(currentTeam));
        expect(resolver.allTeams, equals(allTeams));
        expect(resolver.onSwitch, equals(onSwitch));

        expect(resolver.currentTeam()?.name, 'Acme Corp');
        expect(resolver.allTeams().map((t) => t.name).toList(), [
          'Acme Corp',
          'Beta Inc',
        ]);

        await resolver.onSwitch(2);

        expect(switchedTo, 2);
        expect(MagicStarter.hasTeamResolver, isTrue);
      });

      test('a teamless bootstrap succeeds and leaves teamResolver null', () {
        expect(MagicStarterConfig.hasTeamFeatures(), isFalse);

        MagicStarter.bootstrap(
          userFactory: (data) => _HostUser.fromMap(data),
          onLogout: () async {},
          locales: const {'en': 'English'},
        );

        expect(MagicStarter.manager.teamResolver, isNull);
        expect(MagicStarter.hasTeamResolver, isFalse);
        expect(MagicStarter.isReady, isTrue);
      });

      test('throws StateError when teams are enabled without the trio', () {
        Config.set('magic_starter.features.teams', true);

        expect(
          () => MagicStarter.bootstrap(
            userFactory: (data) => _HostUser.fromMap(data),
            onLogout: () async {},
            locales: const {'en': 'English'},
          ),
          throwsA(
            isA<StateError>().having(
              (StateError error) => error.message,
              'message',
              allOf(
                contains('magic_starter.features.teams'),
                contains('useTeamResolver'),
              ),
            ),
          ),
        );

        expect(MagicStarter.isReady, isFalse);
      });

      test('succeeds when teams are enabled and the trio is passed', () {
        Config.set('magic_starter.features.teams', true);

        MagicStarter.bootstrap(
          userFactory: (data) => _HostUser.fromMap(data),
          onLogout: () async {},
          locales: const {'en': 'English'},
          currentTeam: () => null,
          allTeams: () => const [],
          onSwitch: (dynamic teamId) async {},
        );

        expect(MagicStarter.manager.teamResolver, isNotNull);
        expect(MagicStarter.isReady, isTrue);
      });

      test('throws ArgumentError on a partial trio without mutating state', () {
        expect(
          () => MagicStarter.bootstrap(
            userFactory: (data) => _HostUser.fromMap(data),
            onLogout: () async {},
            locales: const {'en': 'English'},
            currentTeam: () => null,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (ArgumentError error) => error.message.toString(),
              'message',
              contains('all three team callbacks'),
            ),
          ),
        );

        // The trio is validated before any setter runs, so a rejected
        // bootstrap must leave the manager on its defaults.
        expect(MagicStarter.manager.teamResolver, isNull);
        expect(MagicStarter.manager.onLogout, isNull);
        expect(
          MagicStarter.createUser(const {'id': 1}),
          isA<MagicStarterAuthUser>(),
        );
      });

      test('throws ArgumentError when only onSwitch is passed', () {
        expect(
          () => MagicStarter.bootstrap(
            userFactory: (data) => _HostUser.fromMap(data),
            onLogout: () async {},
            locales: const {'en': 'English'},
            onSwitch: (dynamic teamId) async {},
          ),
          throwsArgumentError,
        );
      });
    });

    // -------------------------------------------------------------------------
    // bootstrap() is a composition, not a replacement: the four individual
    // setters must keep working standalone.
    // -------------------------------------------------------------------------

    group('individual setters remain available', () {
      test('useUserModel() still works standalone', () {
        Authenticatable factory(Map<String, dynamic> data) {
          return _HostUser.fromMap(data);
        }

        MagicStarter.useUserModel(factory);

        expect(MagicStarter.manager.userFactory, equals(factory));
        expect(MagicStarter.createUser(const {'id': 1}), isA<_HostUser>());
      });

      test('useLogout() still works standalone', () async {
        bool calledLogout = false;

        MagicStarter.useLogout(() async {
          calledLogout = true;
        });

        expect(MagicStarter.manager.onLogout, isNotNull);

        await MagicStarter.manager.onLogout!();

        expect(calledLogout, isTrue);
      });

      test('useLocaleOptions() still works standalone', () {
        MagicStarter.useLocaleOptions(const {'de': 'Deutsch'});

        expect(MagicStarter.manager.localeOptions.length, 1);
        expect(MagicStarter.manager.localeOptions.first.value, 'de');
        expect(MagicStarter.manager.localeOptions.first.label, 'Deutsch');
      });

      test('useTeamResolver() still works standalone', () {
        final MagicStarterTeam team = MagicStarterTeam.fromMap({
          'id': 3,
          'name': 'Gamma Ltd',
        });

        MagicStarter.useTeamResolver(
          currentTeam: () => team,
          allTeams: () => [team],
          onSwitch: (dynamic teamId) async {},
        );

        expect(MagicStarter.teamResolver, isNotNull);
        expect(MagicStarter.teamResolver!.currentTeam()?.name, 'Gamma Ltd');
      });

      test('a setter called after bootstrap() overrides it', () {
        MagicStarter.bootstrap(
          userFactory: (data) => _HostUser.fromMap(data),
          onLogout: () async {},
          locales: const {'en': 'English'},
        );

        MagicStarter.useLocaleOptions(const {'fr': 'Français'});

        expect(MagicStarter.manager.localeOptions.length, 1);
        expect(MagicStarter.manager.localeOptions.first.value, 'fr');
      });
    });
  });
}
