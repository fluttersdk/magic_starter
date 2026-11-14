/// CLI barrel for Magic Starter.
///
/// Exposes ONLY the dowel CLI surface (MagicStarterDowelProvider). Does
/// NOT export the Flutter runtime barrel (lib/magic_starter.dart), so this
/// barrel is safe for consumption from pure-Dart dowel dispatchers that must
/// not import Flutter or dart:ui.
///
/// Plugin auto-discovery in `dowel` imports this barrel and instantiates
/// [MagicStarterDowelProvider] by convention. Consumer apps that register
/// Magic Starter's CLI commands in a `bin/dispatcher.dart` should import this
/// barrel:
///
/// ```dart
/// import 'package:dowel/dowel.dart';
/// import 'package:magic_starter/cli.dart' show MagicStarterDowelProvider;
///
/// Future<void> main(List<String> args) async {
///   final registry = DowelRegistry()
///     ..registerProvider(MagicStarterDowelProvider());
///   exit(await DowelApplication(registry: registry).dispatch(args));
/// }
/// ```
///
/// Runtime consumers (lib/main.dart of a Magic Starter app) continue to
/// import `package:magic_starter/magic_starter.dart` for facades and the
/// full Flutter surface.
library;

export 'src/cli/starter_dowel_provider.dart';
