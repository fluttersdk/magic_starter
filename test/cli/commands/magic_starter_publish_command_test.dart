import 'dart:convert';
import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic_starter/src/cli/commands/magic_starter_publish_command.dart';
import 'package:test/test.dart';

class TestMagicStarterPublishCommand extends MagicStarterPublishCommand {
  final String _projectRoot;
  final String _pluginSourceDir;

  TestMagicStarterPublishCommand(this._projectRoot, this._pluginSourceDir);

  @override
  String getProjectRoot() => _projectRoot;

  @override
  String? getPluginSourceDir() => _pluginSourceDir;
}

/// Drives [command.handle] with a programmatic [ArtisanContext] composed of a
/// [MapInput] (flags) and a [BufferedOutput] (capturable).
///
/// [tag] defaults to `'all'` to match the command default. Pass [force] to
/// simulate `--force`.
Future<int> _runPublish(
  MagicStarterPublishCommand command, {
  String tag = 'all',
  bool force = false,
  BufferedOutput? output,
}) {
  final ctx = ArtisanContext.bare(
    MapInput(<String, dynamic>{'tag': tag, 'force': force}),
    output ?? BufferedOutput(),
  );
  return command.handle(ctx);
}

void main() {
  late Directory tempDir;
  late Directory pluginDir;
  late TestMagicStarterPublishCommand command;

  void createPluginFile(String relativePath, String content) {
    final file = File('${pluginDir.path}/$relativePath');
    file.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  void createHostFile(String relativePath, String content) {
    final file = File('${tempDir.path}/$relativePath');
    file.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  String readHostFile(String relativePath) {
    return File('${tempDir.path}/$relativePath').readAsStringSync();
  }

  bool hostFileExists(String relativePath) {
    return File('${tempDir.path}/$relativePath').existsSync();
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('publish_test_');
    pluginDir = Directory.systemTemp.createTempSync('plugin_source_');

    command = TestMagicStarterPublishCommand(tempDir.path, pluginDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }

    if (pluginDir.existsSync()) {
      pluginDir.deleteSync(recursive: true);
    }
  });

  group('MagicStarterPublishCommand', () {
    test('name is starter:publish', () {
      expect(command.name, 'starter:publish');
    });

    test('--tag=config copies config file from plugin to host', () async {
      createPluginFile(
        'lib/config/magic_starter.dart',
        'final map = <String, dynamic>{\'ok\': true};',
      );

      await _runPublish(command, tag: 'config');

      expect(hostFileExists('lib/config/magic_starter.dart'), isTrue);
      expect(
        readHostFile('lib/config/magic_starter.dart'),
        'final map = <String, dynamic>{\'ok\': true};',
      );
    });

    test('--tag=config skips when file exists and no --force', () async {
      createPluginFile('lib/config/magic_starter.dart', 'new-content');

      final existing = File('${tempDir.path}/lib/config/magic_starter.dart');
      existing.createSync(recursive: true);
      existing.writeAsStringSync('existing-content');

      await _runPublish(command, tag: 'config');

      expect(existing.readAsStringSync(), 'existing-content');
    });

    test('--tag=config overwrites when --force set', () async {
      createPluginFile('lib/config/magic_starter.dart', 'forced-content');

      final existing = File('${tempDir.path}/lib/config/magic_starter.dart');
      existing.createSync(recursive: true);
      existing.writeAsStringSync('existing-content');

      await _runPublish(command, tag: 'config', force: true);

      expect(existing.readAsStringSync(), 'forced-content');
    });

    test(
      '--tag=views copies view files to lib/resources/views/starter/',
      () async {
        createPluginFile(
          'lib/src/ui/views/auth/magic_starter_login_view.dart',
          'class LoginView {}',
        );
        createPluginFile(
          'lib/src/ui/views/profile/settings_view.dart',
          'class SettingsView {}',
        );

        await _runPublish(command, tag: 'views');

        expect(
          hostFileExists(
            'lib/resources/views/starter/auth/magic_starter_login_view.dart',
          ),
          isTrue,
        );
        expect(
          hostFileExists(
            'lib/resources/views/starter/profile/settings_view.dart',
          ),
          isTrue,
        );
        expect(
          readHostFile(
            'lib/resources/views/starter/auth/magic_starter_login_view.dart',
          ),
          'class LoginView {}',
        );
      },
    );

    test('--tag=lang copies translation JSON', () async {
      createPluginFile(
        'assets/stubs/install/en.stub',
        '{"auth.login":"Login"}',
      );

      await _runPublish(command, tag: 'lang');

      expect(hostFileExists('assets/lang/en.json'), isTrue);
      expect(readHostFile('assets/lang/en.json'), '{"auth.login":"Login"}');
    });

    test(
      '--tag=lang skips when destination already exists and no --force',
      () async {
        // Step 16b depends on this: an installed app carries a hand-merged
        // translation catalogue (e.g. Turkish), and re-running `starter:publish`
        // must never clobber it with the package's English-only stub.
        createPluginFile(
          'assets/stubs/install/en.stub',
          '{"billing":{"title":"new stub content"}}',
        );

        final existing = File('${tempDir.path}/assets/lang/en.json');
        existing.createSync(recursive: true);
        existing.writeAsStringSync(
          '{"billing":{"title":"host-owned content"}}',
        );

        await _runPublish(command, tag: 'lang');

        expect(
          existing.readAsStringSync(),
          '{"billing":{"title":"host-owned content"}}',
        );
      },
    );

    test('--tag=middleware copies middleware files', () async {
      createPluginFile(
        'assets/stubs/install/ensure_authenticated.stub',
        'class EnsureAuthenticated {}',
      );
      createPluginFile(
        'assets/stubs/install/redirect_if_authenticated.stub',
        'class RedirectIfAuthenticated {}',
      );

      await _runPublish(command, tag: 'middleware');

      expect(
        hostFileExists('lib/app/middleware/ensure_authenticated.dart'),
        isTrue,
      );
      expect(
        hostFileExists('lib/app/middleware/redirect_if_authenticated.dart'),
        isTrue,
      );
      expect(
        readHostFile('lib/app/middleware/ensure_authenticated.dart'),
        'class EnsureAuthenticated {}',
      );
      expect(
        readHostFile('lib/app/middleware/redirect_if_authenticated.dart'),
        'class RedirectIfAuthenticated {}',
      );
    });

    test(
      '--tag=all (default) copies config + views + lang + middleware',
      () async {
        createPluginFile('lib/config/magic_starter.dart', 'config-content');
        createPluginFile(
          'lib/src/ui/views/teams/magic_starter_team_settings_view.dart',
          'class TeamSettingsView {}',
        );
        createPluginFile('assets/stubs/install/en.stub', '{"starter":true}');
        createPluginFile(
          'assets/stubs/install/ensure_authenticated.stub',
          'ensure-content',
        );
        createPluginFile(
          'assets/stubs/install/redirect_if_authenticated.stub',
          'redirect-content',
        );

        await _runPublish(command, tag: 'all');

        expect(hostFileExists('lib/config/magic_starter.dart'), isTrue);
        expect(
          hostFileExists(
            'lib/resources/views/starter/teams/magic_starter_team_settings_view.dart',
          ),
          isTrue,
        );
        expect(hostFileExists('assets/lang/en.json'), isTrue);
        expect(
          hostFileExists('lib/app/middleware/ensure_authenticated.dart'),
          isTrue,
        );
        expect(
          hostFileExists('lib/app/middleware/redirect_if_authenticated.dart'),
          isTrue,
        );
      },
    );

    test('creates parent directories if they do not exist', () async {
      createPluginFile('lib/config/magic_starter.dart', 'config-content');

      expect(Directory('${tempDir.path}/lib').existsSync(), isFalse);

      await _runPublish(command, tag: 'config');

      expect(Directory('${tempDir.path}/lib/config').existsSync(), isTrue);
      expect(hostFileExists('lib/config/magic_starter.dart'), isTrue);
    });

    // -------------------------------------------------------------------
    // Granular view publishing
    // -------------------------------------------------------------------

    test('--tag=views:auth publishes only auth module views', () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'class LoginView {}',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_register_view.dart',
        'class RegisterView {}',
      );
      createPluginFile(
        'lib/src/ui/views/profile/magic_starter_profile_settings_view.dart',
        'class ProfileSettingsView {}',
      );

      await _runPublish(command, tag: 'views:auth');

      expect(
        hostFileExists(
          'lib/resources/views/starter/auth/magic_starter_login_view.dart',
        ),
        isTrue,
      );
      expect(
        hostFileExists(
          'lib/resources/views/starter/auth/magic_starter_register_view.dart',
        ),
        isTrue,
      );
      // Profile view should NOT be published.
      expect(
        hostFileExists(
          'lib/resources/views/starter/profile/magic_starter_profile_settings_view.dart',
        ),
        isFalse,
      );
    });

    test(
      '--tag=views:auth.login publishes single view by registry key',
      () async {
        createPluginFile(
          'lib/src/ui/views/auth/magic_starter_login_view.dart',
          'class LoginView {}',
        );
        createPluginFile(
          'lib/src/ui/views/auth/magic_starter_register_view.dart',
          'class RegisterView {}',
        );

        await _runPublish(command, tag: 'views:auth.login');

        expect(
          hostFileExists(
            'lib/resources/views/starter/auth/magic_starter_login_view.dart',
          ),
          isTrue,
        );
        expect(
          readHostFile(
            'lib/resources/views/starter/auth/magic_starter_login_view.dart',
          ),
          'class LoginView {}',
        );
        // Other auth views should NOT be published.
        expect(
          hostFileExists(
            'lib/resources/views/starter/auth/magic_starter_register_view.dart',
          ),
          isFalse,
        );
      },
    );

    test('--tag=views:auth publishes all six auth views when present', () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'login',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_register_view.dart',
        'register',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_forgot_password_view.dart',
        'forgot',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_reset_password_view.dart',
        'reset',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_two_factor_challenge_view.dart',
        'two_factor',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_otp_verify_view.dart',
        'otp',
      );

      await _runPublish(command, tag: 'views:auth');

      expect(
        hostFileExists(
          'lib/resources/views/starter/auth/magic_starter_login_view.dart',
        ),
        isTrue,
      );
      expect(
        hostFileExists(
          'lib/resources/views/starter/auth/magic_starter_register_view.dart',
        ),
        isTrue,
      );
      expect(
        hostFileExists(
          'lib/resources/views/starter/auth/magic_starter_forgot_password_view.dart',
        ),
        isTrue,
      );
      expect(
        hostFileExists(
          'lib/resources/views/starter/auth/magic_starter_reset_password_view.dart',
        ),
        isTrue,
      );
      expect(
        hostFileExists(
          'lib/resources/views/starter/auth/magic_starter_two_factor_challenge_view.dart',
        ),
        isTrue,
      );
      expect(
        hostFileExists(
          'lib/resources/views/starter/auth/magic_starter_otp_verify_view.dart',
        ),
        isTrue,
      );
    });

    test('--tag=views:notifications is no longer a publishable scope', () async {
      // The two notification screens moved to magic_notifications, so this
      // package has no source file to copy. The scope has to report as unknown
      // rather than warn about a missing file it still promises.
      //
      // The reported text is asserted, not just the absence of the directory:
      // publishing nothing at all, or warning about a missing file, would both
      // leave `lib/resources` uncreated too, so the directory check alone
      // cannot tell the three apart. An adopter who typed a scope this package
      // used to have needs to be told it is gone, not that a file is missing.
      final output = BufferedOutput();
      await _runPublish(command, tag: 'views:notifications', output: output);

      expect(Directory('${tempDir.path}/lib/resources').existsSync(), isFalse);
      expect(output.content, contains('Unknown view scope: notifications'));
      expect(output.content, contains('No files were published.'));
    });

    test('--tag=views:unknown reports error for unknown view scope', () async {
      await _runPublish(command, tag: 'views:unknown');

      // No files should be created.
      expect(Directory('${tempDir.path}/lib/resources').existsSync(), isFalse);
    });

    // -------------------------------------------------------------------
    // Granular layout publishing
    // -------------------------------------------------------------------

    test('--tag=layouts publishes both layout files', () async {
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_app_layout.dart',
        'class AppLayout {}',
      );
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_guest_layout.dart',
        'class GuestLayout {}',
      );

      await _runPublish(command, tag: 'layouts');

      expect(
        hostFileExists(
          'lib/resources/layouts/starter/magic_starter_app_layout.dart',
        ),
        isTrue,
      );
      expect(
        hostFileExists(
          'lib/resources/layouts/starter/magic_starter_guest_layout.dart',
        ),
        isTrue,
      );
    });

    test('--tag=layouts:app publishes only the app layout', () async {
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_app_layout.dart',
        'class AppLayout {}',
      );
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_guest_layout.dart',
        'class GuestLayout {}',
      );

      await _runPublish(command, tag: 'layouts:app');

      expect(
        hostFileExists(
          'lib/resources/layouts/starter/magic_starter_app_layout.dart',
        ),
        isTrue,
      );
      expect(
        readHostFile(
          'lib/resources/layouts/starter/magic_starter_app_layout.dart',
        ),
        'class AppLayout {}',
      );
      // Guest layout should NOT be published.
      expect(
        hostFileExists(
          'lib/resources/layouts/starter/magic_starter_guest_layout.dart',
        ),
        isFalse,
      );
    });

    test('--tag=layouts:guest publishes only the guest layout', () async {
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_guest_layout.dart',
        'class GuestLayout {}',
      );

      await _runPublish(command, tag: 'layouts:guest');

      expect(
        hostFileExists(
          'lib/resources/layouts/starter/magic_starter_guest_layout.dart',
        ),
        isTrue,
      );
    });

    test(
      '--tag=layouts:unknown reports error for unknown layout scope',
      () async {
        await _runPublish(command, tag: 'layouts:unknown');

        expect(
          Directory('${tempDir.path}/lib/resources').existsSync(),
          isFalse,
        );
      },
    );

    // -------------------------------------------------------------------
    // Granular view publishing with --force
    // -------------------------------------------------------------------

    test(
      '--tag=views:auth.login with --force overwrites existing file',
      () async {
        createPluginFile(
          'lib/src/ui/views/auth/magic_starter_login_view.dart',
          'new-login-content',
        );

        final existing = File(
          '${tempDir.path}/lib/resources/views/starter/auth/magic_starter_login_view.dart',
        );
        existing.createSync(recursive: true);
        existing.writeAsStringSync('old-login-content');

        await _runPublish(command, tag: 'views:auth.login', force: true);

        expect(
          readHostFile(
            'lib/resources/views/starter/auth/magic_starter_login_view.dart',
          ),
          'new-login-content',
        );
      },
    );

    test('--tag=views:auth.login without --force skips existing file', () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'new-login-content',
      );

      final existing = File(
        '${tempDir.path}/lib/resources/views/starter/auth/magic_starter_login_view.dart',
      );
      existing.createSync(recursive: true);
      existing.writeAsStringSync('old-login-content');

      await _runPublish(command, tag: 'views:auth.login');

      expect(
        readHostFile(
          'lib/resources/views/starter/auth/magic_starter_login_view.dart',
        ),
        'old-login-content',
      );
    });

    test('--tag=views:profile publishes profile module views', () async {
      createPluginFile(
        'lib/src/ui/views/profile/magic_starter_profile_settings_view.dart',
        'class ProfileSettingsView {}',
      );

      await _runPublish(command, tag: 'views:profile');

      expect(
        hostFileExists(
          'lib/resources/views/starter/profile/magic_starter_profile_settings_view.dart',
        ),
        isTrue,
      );
    });

    test('--tag=views:teams publishes team module views', () async {
      createPluginFile(
        'lib/src/ui/views/teams/magic_starter_team_create_view.dart',
        'class TeamCreateView {}',
      );
      createPluginFile(
        'lib/src/ui/views/teams/magic_starter_team_settings_view.dart',
        'class TeamSettingsView {}',
      );
      createPluginFile(
        'lib/src/ui/views/teams/magic_starter_team_invitation_accept_view.dart',
        'class TeamInvitationAcceptView {}',
      );

      await _runPublish(command, tag: 'views:teams');

      expect(
        hostFileExists(
          'lib/resources/views/starter/teams/magic_starter_team_create_view.dart',
        ),
        isTrue,
      );
      expect(
        hostFileExists(
          'lib/resources/views/starter/teams/magic_starter_team_settings_view.dart',
        ),
        isTrue,
      );
      expect(
        hostFileExists(
          'lib/resources/views/starter/teams/magic_starter_team_invitation_accept_view.dart',
        ),
        isTrue,
      );
    });

    // -------------------------------------------------------------------
    // Auto-wire into AppServiceProvider
    // -------------------------------------------------------------------

    test(
      'auto-wires view registration into AppServiceProvider after publish',
      () async {
        createPluginFile(
          'lib/src/ui/views/auth/magic_starter_login_view.dart',
          'class MagicStarterLoginView {}',
        );

        // Create a mock AppServiceProvider.
        createHostFile('lib/app/providers/app_service_provider.dart', '''
import 'package:magic/magic.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    // existing boot code
  }
}
''');

        await _runPublish(command, tag: 'views:auth.login');

        final content = readHostFile(
          'lib/app/providers/app_service_provider.dart',
        );

        // Should contain the import.
        expect(
          content,
          contains(
            "import '../../resources/views/starter/auth/magic_starter_login_view.dart';",
          ),
        );

        // Should contain the registration call.
        expect(
          content,
          contains(
            "MagicStarter.view.register('auth.login', () => const MagicStarterLoginView());",
          ),
        );
      },
    );

    test(
      'auto-wires layout registration into AppServiceProvider after publish',
      () async {
        createPluginFile(
          'lib/src/ui/layouts/magic_starter_app_layout.dart',
          'class MagicStarterAppLayout {}',
        );

        createHostFile('lib/app/providers/app_service_provider.dart', '''
import 'package:magic/magic.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    // existing boot code
  }
}
''');

        await _runPublish(command, tag: 'layouts:app');

        final content = readHostFile(
          'lib/app/providers/app_service_provider.dart',
        );

        expect(
          content,
          contains(
            "import '../../resources/layouts/starter/magic_starter_app_layout.dart';",
          ),
        );

        expect(
          content,
          contains(
            "MagicStarter.view.registerLayout('layout.app', (child) => MagicStarterAppLayout(child: child));",
          ),
        );
      },
    );

    test(
      'auto-wire is idempotent: second run does not duplicate registration',
      () async {
        createPluginFile(
          'lib/src/ui/views/auth/magic_starter_login_view.dart',
          'class MagicStarterLoginView {}',
        );

        createHostFile('lib/app/providers/app_service_provider.dart', '''
import 'package:magic/magic.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    // existing boot code
  }
}
''');

        // First publish.
        await _runPublish(command, tag: 'views:auth.login', force: true);

        // Second publish (with force to re-copy file).
        await _runPublish(command, tag: 'views:auth.login', force: true);

        final content = readHostFile(
          'lib/app/providers/app_service_provider.dart',
        );

        // Count occurrences of the registration line.
        final regPattern = RegExp(
          RegExp.escape(
            "MagicStarter.view.register('auth.login', () => const MagicStarterLoginView());",
          ),
        );
        final matches = regPattern.allMatches(content).length;
        expect(matches, 1, reason: 'Registration should appear exactly once');

        // Count occurrences of the import line.
        final importPattern = RegExp(
          RegExp.escape(
            "import '../../resources/views/starter/auth/magic_starter_login_view.dart';",
          ),
        );
        final importMatches = importPattern.allMatches(content).length;
        expect(importMatches, 1, reason: 'Import should appear exactly once');
      },
    );

    // -------------------------------------------------------------------
    // Shipped en.stub billing block (Step 6, billing-screen-into-magic-starter)
    // -------------------------------------------------------------------

    group('shipped en.stub billing block', () {
      /// The full set of `magic_starter.billing.*` keys the ported billing
      /// view reads, flattened to dotted paths (`invoice_status.paid`, etc.).
      /// Mirrors `uptizm`'s `plan_billing_view.dart` `trans('uptizm.teams.
      /// billing_*')` / `trans('uptizm.enums.invoice_status.*')` calls with
      /// the `uptizm.teams.billing_` / `uptizm.enums.` prefixes stripped.
      const expectedKeys = <String>[
        'description',
        'invoice_receipt_button',
        'invoice_status.failed',
        'invoice_status.paid',
        'invoice_status.pending',
        'invoices_header',
        'manage_app_store_text',
        'manage_header',
        'manage_play_store_text',
        'manage_store_button',
        'manage_store_no_url',
        'owner_only_notice',
        'payment_expires',
        'payment_header',
        'payment_none',
        'payment_update_button',
        'plan_billing_annual',
        'plan_billing_custom',
        'plan_billing_free',
        'plan_billing_monthly',
        'plan_button_contact',
        'plan_button_current',
        'plan_button_downgrade',
        'plan_button_unranked',
        'plan_button_unresolved',
        'plan_button_upgrade',
        'plan_current_badge',
        'plan_price_custom',
        'plan_price_monthly',
        'plan_price_store',
        'plan_recommended_badge',
        'plan_unavailable_text',
        'plans_annual',
        'plans_heading',
        'plans_monthly',
        'renewal_cycle_annual',
        'renewal_cycle_monthly',
        'renewal_free',
        'renewal_store',
        'renewal_text',
        'renewal_unbilled',
        'store_bound_text',
        'store_bound_title',
        'store_purchase_text',
        'store_purchase_title',
        'store_restore_button',
        'store_restore_found_title',
        'store_restore_none_text',
        'store_restore_none_title',
        'title',
        'toast_change_description',
        'toast_checkout_failed_title',
        'toast_contact_description',
        'toast_contact_title',
        'toast_deferred_text',
        'toast_deferred_title',
        'toast_failed_text',
        'toast_switch_title',
        'toast_upgrade_title',
      ];

      late Map<String, dynamic> stub;

      setUpAll(() {
        final stubFile = File(
          '${Directory.current.path}/assets/stubs/install/en.stub',
        );
        stub = jsonDecode(stubFile.readAsStringSync()) as Map<String, dynamic>;
      });

      test('parses as valid JSON', () {
        expect(stub, isA<Map<String, dynamic>>());
      });

      test(
        'every key the ported billing view reads is present and non-empty',
        () {
          final billing =
              (stub['magic_starter'] as Map<String, dynamic>)['billing']
                  as Map<String, dynamic>;

          for (final dottedKey in expectedKeys) {
            final segments = dottedKey.split('.');
            dynamic value = billing;
            for (final segment in segments) {
              expect(
                value,
                isA<Map<String, dynamic>>(),
                reason:
                    'magic_starter.billing.$dottedKey should resolve '
                    'through nested objects',
              );
              expect(
                (value as Map<String, dynamic>).containsKey(segment),
                isTrue,
                reason: 'magic_starter.billing.$dottedKey is missing',
              );
              value = value[segment];
            }

            expect(
              value,
              isA<String>(),
              reason: 'magic_starter.billing.$dottedKey should be a string',
            );
            expect(
              (value as String).isNotEmpty,
              isTrue,
              reason: 'magic_starter.billing.$dottedKey should not be empty',
            );
          }
        },
      );
    });

    test('auto-wire skips when AppServiceProvider not found', () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'class MagicStarterLoginView {}',
      );

      // Do NOT create AppServiceProvider file.

      await _runPublish(command, tag: 'views:auth.login');

      // Verify the view was still published.
      expect(
        hostFileExists(
          'lib/resources/views/starter/auth/magic_starter_login_view.dart',
        ),
        isTrue,
      );

      // AppServiceProvider should not exist.
      expect(
        hostFileExists('lib/app/providers/app_service_provider.dart'),
        isFalse,
      );
    });

    test('auto-wires multiple view registrations for module scope', () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'class MagicStarterLoginView {}',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_register_view.dart',
        'class MagicStarterRegisterView {}',
      );

      createHostFile('lib/app/providers/app_service_provider.dart', '''
import 'package:magic/magic.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    // existing boot code
  }
}
''');

      await _runPublish(command, tag: 'views:auth');

      final content = readHostFile(
        'lib/app/providers/app_service_provider.dart',
      );

      expect(
        content,
        contains(
          "MagicStarter.view.register('auth.login', () => const MagicStarterLoginView());",
        ),
      );
      expect(
        content,
        contains(
          "MagicStarter.view.register('auth.register', () => const MagicStarterRegisterView());",
        ),
      );
    });
  });
}
