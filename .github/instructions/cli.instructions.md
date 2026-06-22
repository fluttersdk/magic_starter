---
name: 'CLI Command Patterns'
description: 'Command class hierarchy, stub lookup, file operations, non-interactive mode'
applyTo: 'lib/src/cli/**/*.dart'
---

# CLI Commands

- Class hierarchy: `extends ArtisanCommand` (or `extends ArtisanInstallCommand` for install) from `fluttersdk_artisan`
- Lifecycle: `signature` DSL property (`'name {arg} {--flag}'`) or `configure(ArgParser)` for flags, async `handle(ArtisanContext ctx)` for main logic
- Boot mode: `CommandBoot.none` (commands run out-of-isolate, no Flutter app instance required)
- Install command pattern: `extends ArtisanInstallCommand`, drives the `install.yaml` manifest, fluent override for dynamic logic (feature toggles, conditional prompts)
- Overridable methods for testability: `getProjectRoot()`, `getStubSearchPaths()`, `runDartFormat()`
- Stub lookup: standardized on `resolveMagicStubsDir().parent.parent`, consistent across plugins
- File operations via `FileHelper`: `fileExists()`, `findProjectRoot()`, `readFile()`, `writeFile()`
- Process execution: `Process.run('dart', ['format', '.'], workingDirectory: path)`, captured output (not streamed)
- User feedback: `ctx.output.info('message')` for progress, `ctx.output.error('message')` for errors
- Non-interactive mode: support `--non-interactive` flag with `--features` option for CI
- Validate host app is a Magic project before proceeding — check for `pubspec.yaml` with magic dependency
- Step-by-step file creation with `--force` flag to override existing files
- Stub paths are relative to the plugin package — resolve via package URI, not hardcoded paths
