# Accumulated Wisdom — Reusable Modal System

## Wave 4 (GREEN — ConfirmDialog + theme refactor)
- ConfirmDialog at `lib/src/ui/widgets/magic_starter_confirm_dialog.dart` — uses DialogShell internally, footer uses plain className (not theme.footerClassName) because shell already wraps footer
- ConfirmDialogVariant enum in same file: primary/danger/warning
- Barrel export added at `lib/magic_starter.dart:43`
- Theme refactor: both modals now read `final theme = MagicStarter.manager.modalTheme;` at top of build()
- TwoFactor modal: theme read needed in build(), _buildSetupStep(), AND _buildRecoveryStep() separately
- 69 widget tests all passing

## Wave 2 (GREEN implementations)
- MagicStarterModalTheme added at `lib/src/magic_starter_manager.dart:142` — 13 fields + const constructor
- Manager modalTheme field at line 318, reset() update at line 487
- Facade useModalTheme() at `lib/src/facades/magic_starter.dart:269`, modalTheme getter at line 292
- ViewRegistry modal methods at `lib/src/ui/magic_starter_view_registry.dart:60-79` — registerModal/hasModal/makeModal + clear() updated
- MagicStarterModalBuilder typedef at line 5 of view registry file

## Wave 1 (RED tests)
- Test wrap() helper: `WindTheme(data, child: MaterialApp(theme: data.toThemeData(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(1200, 800, child: widget)))))`
- setUp pattern: `MagicApp.reset()`, `Magic.flush()`, `Magic.singleton('magic_starter', () => MagicStarterManager())`, `Magic.singleton('log', () => LogManager())`
- Config in setUp: `Config.set('logging', {'default': 'console', 'channels': {'console': {'driver': 'console', 'level': 'debug'}}})`, `Config.set('wind.colors.primary', 'indigo')`
- Dialog shell footer sentinel: `Key('magic_starter_dialog_shell_footer')` used for presence/absence testing
- ViewRegistry test file already existed at `test/ui/magic_starter_view_registry_test.dart` — new group appended at line 164
