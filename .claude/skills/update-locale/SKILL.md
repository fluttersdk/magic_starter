---
name: update-locale
description: >
  Audit and fix i18n/localization completeness for Magic Framework projects.
  Use when: checking translation coverage, finding missing trans() keys,
  ensuring en.stub is complete, auditing hardcoded strings, or any task
  involving "locale", "translation", "i18n", "trans()", "en.stub", or
  "multi-language". Triggers on: "check translations", "update locale",
  "audit i18n", "missing translations", "en.stub", "trans keys".
---

# Update Locale

Audit and fix i18n completeness for Magic Framework Flutter projects.

## Context

Magic Framework uses `trans('key')` for all user-facing strings. Translations
live in a JSON stub file (`assets/stubs/install/en.stub`) that gets copied to
host apps during `magic_starter install`. Keys use dot-notation matching nested
JSON structure (e.g., `auth.login_title` → `{"auth":{"login_title":"Sign In"}}`).

## Workflow

### Step 1 — Extract trans() keys from source

Run the bundled audit script:

```bash
python3 .opencode/skills/update-locale/scripts/audit_locale.py lib/src assets/stubs/install/en.stub
```

The script handles both single-line and multi-line `trans()` calls:
```dart
// Single-line
trans('auth.login_title')

// Multi-line
trans(
    'magic_starter.email_verification.unverified_description',
)

// With parameters
trans('time.minutes_ago', {'minutes': difference.inMinutes})
```

### Step 2 — Fix missing keys

For each MISSING key reported by the script:

1. Find the key's usage in source to understand context
2. Write an appropriate English translation value
3. Add to `assets/stubs/install/en.stub` in the correct nested location
4. Maintain alphabetical ordering within each JSON object

### Step 3 — Review orphan keys

Orphan keys (in stub but not in source) are NOT errors. They may be:
- Used by the Magic Framework itself (e.g., `validation.*`)
- Used in tests only
- Reserved for future features
- Used by host apps directly

Do NOT remove orphan keys unless explicitly asked.

### Step 4 — Verify no hardcoded strings

Search for user-facing text that should use `trans()`:

```bash
# Find WText with string literals (not trans())
grep -rn "WText(" lib/src/ui/ | grep -v "trans(" | grep -v "className" | grep -v "//"

# Find labels/placeholders without trans()
grep -rn "label:" lib/src/ui/ | grep -v "trans(" | grep -v "//"
grep -rn "placeholder:" lib/src/ui/ | grep -v "trans(" | grep -v "//"
```

Skip: className strings, route paths, map keys, dynamic variables, test files.

### Step 5 — Run tests

```bash
flutter test
```

Ensure all tests pass after any en.stub changes.

## Key Structure Convention

```
top_level_domain.sub_key          → auth.login_title
magic_starter.feature.key         → magic_starter.otp.send_error
profile.two_factor.nested_key     → profile.two_factor.copy_codes
```

## Anti-Patterns

| Forbidden | Do Instead |
|-----------|-----------|
| Hardcoded UI strings in views | `trans('domain.key')` |
| Remove orphan validation keys | Keep — used by Magic Framework |
| Inline strings in controllers | `trans('errors.unexpected')` for errors |
| Duplicate keys across sections | Single source of truth per key |
