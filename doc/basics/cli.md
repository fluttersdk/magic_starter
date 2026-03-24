# CLI Commands

- [Introduction](#introduction)
- [Install Command](#install-command)
    - [What It Creates](#what-it-creates)
    - [What It Injects](#what-it-injects)
    - [Flags](#install-flags)
- [Configure Command](#configure-command)
    - [Show Current Config](#show-current-config)
    - [Toggle Features](#toggle-features)
    - [Non-Interactive Mode](#non-interactive-mode)
- [Doctor Command](#doctor-command)
    - [Health Checks](#health-checks)
    - [Verbose Mode](#verbose-mode)
- [Publish Command](#publish-command)
    - [Publish Tags](#publish-tags)
- [Uninstall Command](#uninstall-command)
- [Stub Templates](#stub-templates)
- [Testing CLI Commands](#testing-cli-commands)

<a name="introduction"></a>
## Introduction

Magic Starter provides five CLI commands that manage the full lifecycle of the plugin inside a host Magic application — from initial scaffolding through configuration, diagnostics, customization, and removal. All commands extend `Command` from `magic_cli` and follow a consistent pattern: `configure(ArgParser)` for flag definitions and `handle()` for async execution logic.

Every command resolves the host project root via `FileHelper.findProjectRoot()` and validates that the target is a Magic project before proceeding.

<a name="install-command"></a>
## Install Command

```bash
dart run magic_starter install
```

The installer is a multi-step scaffolding command that sets up Magic Starter in a host application. It validates the host project, prompts for feature selection, generates files from stubs, and injects registrations into existing config files.

<a name="what-it-creates"></a>
### What It Creates

The installer generates the following files from stub templates:

| File | Purpose |
|------|---------|
| `lib/config/magic_starter.dart` | Feature toggle configuration with selected features enabled |
| `lib/app/middleware/ensure_authenticated.dart` | Auth guard middleware |
| `lib/app/middleware/redirect_if_authenticated.dart` | Guest redirect middleware |
| `lib/app/models/user.dart` | User model with `Authenticatable` implementation |
| `lib/app/models/team.dart` | Team model (only when teams feature is enabled) |
| `lib/app/providers/app_service_provider.dart` | Service provider with facade setup |
| `lib/resources/views/dashboard_view.dart` | Dashboard view scaffold |
| `lib/routes/app_routes.dart` | App routes file with starter route registrations |
| `assets/lang/en.json` | Translation strings |

<a name="what-it-injects"></a>
### What It Injects

Beyond creating new files, the installer modifies existing host files:

- **`lib/config/app.dart`** — Adds `MagicStarterServiceProvider` to the providers list and its import
- **`lib/main.dart`** — Adds `magicStarterConfig` factory to the config factories list and its import
- **`lib/app/kernel.dart`** — Registers `EnsureAuthenticated` and `RedirectIfAuthenticated` middleware aliases
- **`lib/app/providers/route_service_provider.dart`** — Adds starter route registration calls (`registerMagicStarterAuthRoutes`, etc.)
- **`pubspec.yaml`** — Ensures `assets/lang/` is listed in the assets section

```dart
// Injected into lib/config/app.dart
MagicStarterServiceProvider(),

// Injected into lib/main.dart
() => magicStarterConfig,
```

> [!NOTE]
> The installer validates that `lib/config/app.dart` exists before proceeding. If Magic Framework is not installed, it throws an exception: _"Magic Framework not detected. Run `magic install` first."_

<a name="install-flags"></a>
### Flags

| Flag | Description |
|------|-------------|
| `--force`, `-f` | Overwrite existing generated files |
| `--non-interactive` | Skip interactive prompts, use defaults or `--features` |
| `--features` | Comma-separated feature keys for non-interactive mode |

```bash
# Interactive installation (prompts for each feature)
dart run magic_starter install

# Non-interactive with specific features
dart run magic_starter install --non-interactive --features teams,notifications,registration

# Force overwrite existing files
dart run magic_starter install --force
```

> [!TIP]
> When `--features notifications` is included, the installer automatically runs `dart run magic_notifications install --non-interactive` to set up the notifications package dependency.

<a name="configure-command"></a>
## Configure Command

```bash
dart run magic_starter configure
```

Updates individual feature flags in `lib/config/magic_starter.dart` without modifying any other file. All I/O is delegated through `MagicStarterConfigHelper`.

<a name="show-current-config"></a>
### Show Current Config

```bash
dart run magic_starter configure --show
```

Displays a formatted table of all feature toggles and their current status:

```
Current Magic Starter Feature Configuration:

Feature              Status
teams                enabled
social_login         disabled
two_factor           disabled
notifications        enabled
...
```

<a name="toggle-features"></a>
### Toggle Features

Each feature has a boolean flag that can be enabled or disabled:

```bash
# Enable teams and notifications
dart run magic_starter configure --teams --notifications

# Disable social login
dart run magic_starter configure --no-social-login

# Mix enable and disable
dart run magic_starter configure --teams --no-social-login --notifications
```

Available feature flags:

| CLI Flag | Config Key |
|----------|------------|
| `--teams` | `teams` |
| `--social-login` | `social_login` |
| `--two-factor` | `two_factor` |
| `--sessions` | `sessions` |
| `--phone-otp` | `phone_otp` |
| `--newsletter` | `newsletter` |
| `--notifications` | `notifications` |
| `--email-verification` | `email_verification` |

> [!NOTE]
> Only flags explicitly provided on the command line are modified. Omitted flags remain untouched in the config file. The command modifies the Dart source file directly using string replacement via `MagicStarterConfigHelper.updateFeature()`.

<a name="non-interactive-mode"></a>
### Non-Interactive Mode

The configure command is non-interactive by design — it operates entirely through CLI flags. This makes it suitable for CI pipelines and automation scripts.

<a name="doctor-command"></a>
## Doctor Command

```bash
dart run magic_starter doctor
```

Runs a series of independent health checks to verify that Magic Starter was installed correctly. Each check reports pass or fail, and the command exits with code 0 (all pass) or code 1 (any failure).

<a name="health-checks"></a>
### Health Checks

| Check | What It Verifies |
|-------|-----------------|
| Magic Framework | `lib/config/app.dart` exists |
| Starter Config | `lib/config/magic_starter.dart` exists |
| Provider | `MagicStarterServiceProvider` registered in `app.dart` |
| Config Factory | `magicStarterConfig` wired in `main.dart` |
| Middleware | `EnsureAuthenticated` registered in `kernel.dart` |
| Routes | `registerMagicStarterAuthRoutes` called in `route_service_provider.dart` |
| Facade | `MagicStarter.useNavigation` configured in `app_service_provider.dart` |
| Translations | `assets/lang/en.json` exists |

```
Magic Starter — Doctor Report
==================================================

Magic Framework: ✓
Starter Config: ✓
Provider: ✓
Config Factory: ✓
Middleware: ✓
Routes: ✓
Facade: ✗
Translations: ✓

Missing Requirements:
  ✗ MagicStarter facade not configured in app_service_provider.dart

1 check(s) failed. Run `dart run magic_starter install` to fix.
```

<a name="verbose-mode"></a>
### Verbose Mode

```bash
dart run magic_starter doctor --verbose
```

Shows the file path inspected for each check and the specific string searched for:

```
Provider: ✓
    File: lib/config/app.dart
    Contains: MagicStarterServiceProvider
```

<a name="publish-command"></a>
## Publish Command

```bash
dart run magic_starter publish
```

Copies plugin source files into the host application for customization — the Magic Starter equivalent of Laravel's `vendor:publish`. Published files can be edited freely; the view registry will pick up your custom versions when you re-register them.

<a name="publish-tags"></a>
### Publish Tags

```bash
# Publish everything
dart run magic_starter publish

# Publish only views
dart run magic_starter publish --tag views

# Publish with force overwrite
dart run magic_starter publish --force
```

| Tag | What It Publishes |
|-----|-------------------|
| `config` | `lib/config/magic_starter.dart` |
| `views` | All view files to `lib/resources/views/starter/` |
| `middleware` | Auth middleware files to `lib/app/middleware/` |
| `lang` | Translation file to `assets/lang/en.json` |
| `all` (default) | All of the above |

> [!NOTE]
> Without `--force`, existing files are skipped with a warning. The command reports the total number of published files at the end.

<a name="uninstall-command"></a>
## Uninstall Command

```bash
dart run magic_starter uninstall
```

Performs a safe reverse of the install command. It removes generated files and cleans up injected lines from host config files while keeping user code intact.

What it removes:

- `lib/config/magic_starter.dart`
- `magic_starter` dependency from `pubspec.yaml`
- `MagicStarterServiceProvider` import/registration from `lib/config/app.dart`
- `magicStarterConfig` import/factory from `lib/main.dart`
- Middleware aliases/imports from `lib/app/kernel.dart`
- Route imports/registrations from `route_service_provider.dart`

```bash
# Skip confirmation prompt
dart run magic_starter uninstall --force
```

Each removal step is wrapped in error handling — already-clean projects and partial installations will not crash the command. After removal, `dart format .` is run automatically.

> [!TIP]
> The uninstall command does not remove your custom AppServiceProvider integrations, middleware files, or translation entries. These are listed as manual cleanup recommendations after uninstall completes.

<a name="stub-templates"></a>
## Stub Templates

All generated files are built from stub templates in the `assets/stubs/install/` directory:

| Stub | Output |
|------|--------|
| `magic_starter_config.stub` | `lib/config/magic_starter.dart` |
| `ensure_authenticated.stub` | `lib/app/middleware/ensure_authenticated.dart` |
| `redirect_if_authenticated.stub` | `lib/app/middleware/redirect_if_authenticated.dart` |
| `user.stub` | `lib/app/models/user.dart` |
| `team.stub` | `lib/app/models/team.dart` |
| `app_service_provider.stub` | `lib/app/providers/app_service_provider.dart` |
| `dashboard_view.stub` | `lib/resources/views/dashboard_view.dart` |
| `app_routes.stub` | `lib/routes/app_routes.dart` |
| `en.stub` | `assets/lang/en.json` |

Stub paths are resolved relative to the plugin package at runtime. The installer searches multiple paths with fallback via `getStubSearchPaths()`:

```dart
List<String> getStubSearchPaths() {
  return [
    _resolvePluginStubsDir(),        // Package URI resolution
    '${Directory.current.path}/assets/stubs', // Local fallback
  ];
}
```

> [!NOTE]
> Stubs are plain Dart/JSON files with placeholder tokens that the installer replaces based on the selected features. Never hardcode absolute stub paths — always resolve via the package URI mechanism.

<a name="testing-cli-commands"></a>
## Testing CLI Commands

All CLI commands expose overridable methods for testability. Override these to isolate commands from the real filesystem:

```dart
class TestableInstallCommand extends MagicStarterInstallCommand {
  final String _testRoot;

  TestableInstallCommand(this._testRoot);

  @override
  String getProjectRoot() => _testRoot;

  @override
  List<String> getStubSearchPaths() => [
    '$_testRoot/stubs',
  ];

  @override
  Future<ProcessResult> runDartFormat(String rootPath) async {
    return ProcessResult(0, 0, '', ''); // No-op in tests
  }
}
```

Key overridable methods across commands:

| Method | Commands | Purpose |
|--------|----------|---------|
| `getProjectRoot()` | All | Redirect to temp directory |
| `getStubSearchPaths()` | Install | Point to test stub fixtures |
| `runDartFormat()` | Install, Uninstall | Skip formatting in tests |
| `runNotificationInstaller()` | Install | Skip notification package setup |
| `getPluginSourceDir()` | Publish | Point to test plugin source |

> [!TIP]
> The doctor command's individual check methods (`checkConfigExists()`, `checkProviderRegistered()`, etc.) accept a root path parameter, making them directly testable without subclassing.

---

**Related Links:**

- [Installation](https://magic.fluttersdk.com/packages/starter/getting-started/installation)
- [Configuration](https://magic.fluttersdk.com/packages/starter/getting-started/configuration)
- [Service Providers](https://magic.fluttersdk.com/packages/starter/architecture/providers)
