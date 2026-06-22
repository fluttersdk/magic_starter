/// CLI barrel for Magic Starter.
///
/// Exposes ONLY the artisan-CLI surface (MagicStarterArtisanProvider). Does
/// NOT export the Flutter runtime barrel (lib/magic_starter.dart), so this
/// barrel is safe for consumption from pure-Dart artisan dispatchers that must
/// not import Flutter or dart:ui.
///
/// Plugin auto-discovery in `fluttersdk_artisan` imports this barrel and
/// instantiates [MagicStarterArtisanProvider] by convention. Consumer apps
/// that register Magic Starter's CLI commands in a `bin/artisan.dart` should
/// import this barrel:
///
/// ```dart
/// import 'package:fluttersdk_artisan/artisan.dart';
/// import 'package:magic_starter/cli.dart' show MagicStarterArtisanProvider;
///
/// Future<void> main(List<String> args) async {
///   final registry = ArtisanRegistry()
///     ..registerProvider(MagicStarterArtisanProvider());
///   exit(await ArtisanApplication(registry: registry).dispatch(args));
/// }
/// ```
///
/// Runtime consumers (lib/main.dart of a Magic Starter app) continue to
/// import `package:magic_starter/magic_starter.dart` for facades and the
/// full Flutter surface.
library;

export 'src/cli/starter_artisan_provider.dart';
