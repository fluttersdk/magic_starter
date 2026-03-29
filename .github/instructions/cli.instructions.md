---
name: 'CLI Command Patterns'
description: 'Command class hierarchy, stub lookup, file operations, non-interactive mode'
applyTo: 'lib/src/cli/**/*.dart'
---

# CLI Commands

- Class hierarchy: `extends Command` from `magic_cli`
- Lifecycle: `configure(ArgParser parser)` for flags/options, `handle()` async for main logic
- Overridable methods for testability: `getProjectRoot()`, `getStubSearchPaths()`, `runDartFormat()`
- Stub lookup: multiple search paths with fallback — use `_resolvePluginStubsDir()` helper
- File operations via `FileHelper`: `fileExists()`, `findProjectRoot()`, `readFile()`, `writeFile()`
- Process execution: `Process.run('dart', ['format', '.'], workingDirectory: path)` — captured output, not streamed
- User feedback: `info('message')` for progress, `Log.warning('[MagicStarter] message')` for issues
- Non-interactive mode: support `--non-interactive` flag with `--features` option for CI
- Validate host app is a Magic project before proceeding — check for `pubspec.yaml` with magic dependency
- Step-by-step file creation with `--force` flag to override existing files
- Stub paths are relative to the plugin package — resolve via package URI, not hardcoded paths
