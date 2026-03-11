---
path: "lib/**/*.dart"
---

# Flutter / Dart Stack

- Import order: (1) `dart:*`, (2) `package:flutter/*`, (3) `package:magic/*` and other packages, (4) relative imports
- File naming: snake_case, prefixed with `magic_starter_` for domain classes
- Class naming: PascalCase with `MagicStarter` prefix: `MagicStarterAuthController`
- Private members: leading underscore, camelCase: `_isSubmitting`, `_obscurePassword`
- Section dividers: 73-char ASCII dashes for grouping public/private sections:
  ```dart
  // -------------------------------------------------------------------------
  // Public actions
  // -------------------------------------------------------------------------
  ```
- Factory patterns used across the codebase:
  - Controller singleton: `static T get instance => Magic.findOrPut(T.new)`
  - Model factory: `static T fromMap(Map<String, dynamic> map)`
  - Dialog factory: `static Future<T> show(BuildContext context, ...)`
  - View factory: `MagicStarter.view.make('auth.login')`
- Static utility classes use private constructor: `ClassName._();`
- Config queries: `Config.get<T>('magic_starter.section.key', defaultValue)`
- Trailing commas on ALL multi-line argument lists, collections, and parameters
- Doc comments (`///`) on public APIs; inline comments (`//`) explain WHY, not WHAT
- Concerns directory: shared mixins live in `concerns/` subdirectory (e.g., `NavigatesRoutes` in `controllers/concerns/`)
- Feature toggles: 13 opt-in flags via `MagicStarterConfig.has<Feature>Features()` — all default false
- Gate abilities: 9 auto-registered `starter.*` abilities for section visibility (profile, teams, etc.)
