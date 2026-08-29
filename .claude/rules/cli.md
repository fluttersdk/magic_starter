---
paths:
  - "lib/src/cli/**/*.dart"
---

# CLI Commands

- Class hierarchy: `extends ArtisanCommand` (or `extends ArtisanInstallCommand` for install) from `fluttersdk_artisan`
- Lifecycle: `signature` DSL property (`'name {arg} {--flag}'`), `description` property, async `handle(ArtisanContext ctx)` method
- Boot mode: `CommandBoot.none` — commands run out-of-isolate (no Flutter app instance required)
- Overridable methods for testability: `getProjectRoot()`, `getStubSearchPaths()`, `runDartFormat()`
- Install command pattern: extends `ArtisanInstallCommand`, drives `install.yaml` manifest, fluent override for dynamic logic (feature toggles, conditional prompts, validation)
- Manifest-driven install: static scaffolding (config publish, provider injection) via `install.yaml` schema (plugin_name, publish, prompts, magic.provider, post_install)
- Stub lookup: standardized on `resolveMagicStubsDir().parent.parent` pattern — consistent across all plugins
- File operations via `FileHelper`: `fileExists()`, `findProjectRoot()`, `readFile()`, `writeFile()`
- Process execution: `Process.run('dart', ['format', '.'], workingDirectory: path)` — captured output, not streamed
- User feedback: `ctx.output.info('message')` for progress, `ctx.output.error('message')` for errors
- Non-interactive mode: support `--non-interactive` flag with `--features` option for CI (via override, manifest cannot express conditional prompts)
- Validate host app is a Magic project before proceeding — check for `pubspec.yaml` with magic dependency
- Transactional install ops: order writes before helper-backed mutations (helpers write synchronously, no rollback)
- Stub paths are relative to the plugin package — resolve via package URI, not hardcoded paths
