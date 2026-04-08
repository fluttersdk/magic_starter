# Plan: Document State/Controller Registration Pattern

**TL;DR**: Create `doc/architecture/controllers.md`, update `doc/architecture/service-provider.md` with a cross-reference, update the scaffolded `app_service_provider.stub` with state registration guidance, and create `doc/guides/state-management.md` as a practical getting-started guide.

**Intent**: Build (documentation)
**Complexity**: Standard
**Test Strategy**: No code tests — verify docs render correctly, stub has new comments, cross-references resolve.

## Steps

### Step 1: Create `doc/architecture/controllers.md` [mid]

**Files**: `doc/architecture/controllers.md` (create)

**Description**: Create the primary architecture reference doc for controller/state registration. Follow the existing doc conventions (anchor-based TOC, `## Section` headings, code examples, tip/note callouts, `## Related` footer). Cover:

1. **Introduction** — Controller role in magic_starter architecture (state + business logic, paired with views)
2. **Lazy Singleton Pattern** — The `static T get instance => Magic.findOrPut(T.new)` pattern, explain IoC container caching, first-access initialization
3. **MagicController + MagicStateMixin** — Class hierarchy, typed state (`MagicStateMixin<bool>` vs untyped), what `isLoading`/`hasErrors`/`setError()`/`renderState()` provide
4. **Controller Lifecycle** — How controllers persist as singletons across view rebuilds, when state resets
5. **View Binding** — `MagicStatefulView<ControllerType>` auto-provides `controller` getter, `MagicStatefulViewState` lifecycle hooks (`onInit`, `onClose`)
6. **Consumer App Pattern** — Recommended approach for consumer apps creating their own controllers:
   - Lazy singleton with static accessor (default recommendation)
   - When to register in `AppServiceProvider.boot()` (eager — needs WebSocket, auth-dependent init)
   - When to use per-view instance (form state, wizard state — plain `ChangeNotifier`)
   - Decision tree as a table
7. **View Integration for Consumer Apps** — Option A: `MagicStatefulView<T>` (auto-listens), Option B: `StatefulWidget` + `Magic.find<T>()` (more control)
8. **Fine-Grained Reactivity** — `ValueNotifier<T>` fields for section-level loading (reference profile controller pattern)
9. **Testing Controllers** — Mock setup, `MagicApp.reset()`, `Magic.flush()`, singleton re-registration, `ValueNotifier` disposal
10. **Related** — Links to service-provider.md, manager.md, views-and-layouts.md

Use real magic_starter controller examples (auth, profile, team) — not hypothetical code.

**Done when**:
- `test -f doc/architecture/controllers.md && echo "exists"` returns "exists"
- `grep -c "Magic.findOrPut" doc/architecture/controllers.md` returns ≥3
- `grep -c "MagicStateMixin" doc/architecture/controllers.md` returns ≥2
- `grep -c "Consumer" doc/architecture/controllers.md` returns ≥1
- `grep -c "Decision" doc/architecture/controllers.md` returns ≥1

**QA**: Read the file, verify TOC anchors match section headings, verify code blocks have correct Dart syntax, verify decision tree covers eager/lazy/per-view scenarios.

**Independence**: independent
**Tier**: mid

---

### Step 2: Update `app_service_provider.stub` [quick]

**Files**: `assets/stubs/install/app_service_provider.stub` (modify)

**Description**: Add a commented state registration section at the end of the `boot()` method, after the existing `{{ notifications_block }}` template tag and before the closing `}`. The comment block should:

1. Use a 73-char ASCII dash section divider (matching project convention)
2. Explain that most state classes should use the lazy `Magic.findOrPut()` pattern via a static `instance` accessor
3. Show a concrete example of eager registration for state that needs early init
4. Reference the architecture docs for full guidance

Exact content to add before the closing `    }` of `boot()`:

```dart

    // -----------------------------------------------------------------------
    // State Registration (optional — for eager initialization)
    // -----------------------------------------------------------------------
    // Most state classes should use the lazy singleton pattern with a static
    // accessor instead of registering here:
    //
    //   class ProjectState extends MagicController with MagicStateMixin<List<Project>> {
    //     static ProjectState get instance => Magic.findOrPut(ProjectState.new);
    //   }
    //
    // Only register here if the state needs to be ready before any view
    // renders (e.g., WebSocket connection, auth-dependent initialization):
    //
    //   Magic.findOrPut(DashboardState.new);
    //
    // See: doc/architecture/controllers.md
```

**Done when**:
- `grep -c "State Registration" assets/stubs/install/app_service_provider.stub` returns 1
- `grep -c "Magic.findOrPut" assets/stubs/install/app_service_provider.stub` returns ≥2
- `grep -c "controllers.md" assets/stubs/install/app_service_provider.stub` returns 1

**QA**: Read the stub, verify comment block is inside `boot()` method, indentation uses 4 spaces (matching existing stub), template tags (`{{ }}`) are not disturbed.

**Independence**: independent
**Tier**: quick

---

### Step 3: Create `doc/guides/state-management.md` [mid]

**Files**: `doc/guides/state-management.md` (create)

**Description**: Create a practical getting-started guide for consumer app developers. This is the "how to" companion to the architecture reference in Step 1. Follow existing doc conventions. Cover:

1. **Introduction** — Brief context: magic_starter uses `MagicController` + `MagicStateMixin` + IoC container for state management
2. **Creating a State Class** — Step-by-step: extend `MagicController`, mixin `MagicStateMixin<T>`, add static `instance` accessor, implement async methods with `setLoading()`/`setData()`/`setError()` pattern
3. **Registration Decision Tree** — Visual/table decision tree:
   - "Does it need to be ready before views render?" → Yes: register in `AppServiceProvider.boot()` / No: lazy `findOrPut()`
   - "Is it shared across views?" → Yes: singleton (default) / No: per-view `ChangeNotifier`
4. **Connecting State to Views** — Two patterns with complete examples:
   - Pattern A: `MagicStatefulView<T>` — show full view class with `renderState()` builder
   - Pattern B: `StatefulWidget` + `Magic.find<T>()` — show full view class with manual access
5. **Testing** — Complete test example: setUp with `MagicApp.reset()` + `Magic.flush()`, mock network, verify state transitions
6. **Complete Example** — End-to-end: state class + view + test for a "ProjectList" feature
7. **Related** — Links to controllers.md, service-provider.md, views-and-layouts.md

Use a realistic consumer app example throughout (e.g., `ProjectState` managing a list of projects) — not magic_starter internals.

**Done when**:
- `test -f doc/guides/state-management.md && echo "exists"` returns "exists"
- `grep -c "MagicController" doc/guides/state-management.md` returns ≥3
- `grep -c "findOrPut" doc/guides/state-management.md` returns ≥3
- `grep -c "MagicStatefulView" doc/guides/state-management.md` returns ≥2
- `grep -c "test" doc/guides/state-management.md` returns ≥2

**QA**: Read the file, verify code examples are complete (not truncated with `...`), verify the decision tree is actionable, verify test example includes setUp/tearDown boilerplate.

**Independence**: independent
**Tier**: mid

---

### Step 4: Add cross-reference in `doc/architecture/service-provider.md` [quick]

**Files**: `doc/architecture/service-provider.md` (modify)

**Description**: Add a cross-reference to the new controllers.md doc. Two changes:

1. In the `## Related` section at the bottom, add a new bullet:
   `- [Controllers & State Registration](https://magic.fluttersdk.com/packages/starter/architecture/controllers) — lazy singleton pattern, consumer app state registration guide`

2. After the `## IoC Bindings` section (before `## Related`), add a brief note:

```markdown
> [!TIP]
> For guidance on registering your own controllers and state classes in a consumer app, see [Controllers & State Registration](controllers.md).
```

**Done when**:
- `grep -c "controllers" doc/architecture/service-provider.md` returns ≥2 (cross-ref + tip)
- `grep -c "State Registration" doc/architecture/service-provider.md` returns ≥1

**QA**: Read the file, verify the tip box is between IoC Bindings and Related sections, verify the Related link URL follows the same pattern as existing links.

**Independence**: independent
**Tier**: quick

---

### Step 5: Update CHANGELOG.md and README.md [quick]

**Files**: `CHANGELOG.md` (modify), `README.md` (modify)

**Description**: Per the post-change checklist:

1. **CHANGELOG.md** — Add entry under `[Unreleased]` section:
   ```
   ### Added
   - Documentation for recommended state/controller registration pattern for consumer apps (`doc/architecture/controllers.md`, `doc/guides/state-management.md`)
   - State registration guidance in scaffolded `app_service_provider.stub`
   ```

2. **README.md** — The README has a `## Documentation` table. Add rows for:
   - `doc/architecture/controllers.md` — Controllers & State Registration
   - `doc/guides/state-management.md` — State Management Guide

**Done when**:
- `grep -ic "state" CHANGELOG.md` returns ≥1
- `grep -c "controllers.md" CHANGELOG.md` returns ≥1
- `grep -c "controllers.md" README.md` returns ≥1
- `grep -c "state-management.md" README.md` returns ≥1

**QA**: Read CHANGELOG.md, verify entry is under `[Unreleased]`, verify no version bump. Read README.md, verify new rows are in the Documentation table.

**Independence**: depends on Steps 1-4
**Tier**: quick

---

## Waves

### Wave 1 (Start Immediately)
- Step 1 [mid]: Create `doc/architecture/controllers.md`
- Step 2 [quick]: Update `app_service_provider.stub`
- Step 3 [mid]: Create `doc/guides/state-management.md`
- Step 4 [quick]: Add cross-reference in `service-provider.md`

### Wave 2 (After Wave 1)
- Step 5 [quick]: Update CHANGELOG.md and README.md

## Must NOT Have

- No code changes to `lib/src/` — this is documentation only
- No version bump in `pubspec.yaml` — that's a release step
- No new test files — docs don't need tests
- No changes to existing controller implementations
- No hypothetical patterns that magic_starter itself doesn't use — document what exists
- No deep-diving into `magic` package internals (`MagicController`, `MagicStateMixin` source) — document usage patterns only, referencing what magic_starter controllers actually call
- Before writing code examples in Steps 1 and 3, grep `MagicStateMixin` method signatures from the `magic` package source (in `.pub-cache` or sibling package) to verify exact method names (`setLoading`, `setData`, `setError`, `renderState`, etc.) — do NOT fabricate API calls

## Risks

- **Magic Framework API docs**: The `MagicController`, `MagicStateMixin`, and `Magic.findOrPut()` APIs come from the `magic` package. Documentation should reference these but not explain their internals beyond what's needed for the pattern.
- **URL convention**: Existing Related links use `https://magic.fluttersdk.com/packages/starter/...` — new cross-references should follow the same pattern for consistency.

## Research Summary

**Key Files**:
- `lib/src/http/controllers/magic_starter_auth_controller.dart:19-22` — Representative controller with `Magic.findOrPut` singleton
- `lib/src/http/controllers/magic_starter_profile_controller.dart:9-12` — Profile controller with `MagicStateMixin<bool>`
- `lib/src/ui/views/auth/magic_starter_login_view.dart:17` — Representative `MagicStatefulView<T>` binding
- `assets/stubs/install/app_service_provider.stub` — Scaffolded provider (no state guidance currently)
- `doc/architecture/service-provider.md` — Existing provider docs (no consumer state section)
- `doc/basics/views-and-layouts.md` — Existing view docs with `MagicStatefulView` lifecycle

**Patterns Found**: All 7 controllers use identical `static T get instance => Magic.findOrPut(T.new)` lazy singleton pattern. All 11 page-level views use `MagicStatefulView<ControllerType>`. Controllers use `MagicStateMixin<bool>` for simple state tracking.

**Dependencies**: `magic` package provides `MagicController`, `MagicStateMixin`, `Magic.findOrPut()`, `MagicStatefulView`, `MagicStatefulViewState`.

**Codebase State**: Disciplined — consistent patterns across all controllers and views, strong test coverage, clear naming conventions.

## Conventions

- Doc format: Anchor-based TOC at top, `## Section` headings, code blocks with `dart` syntax, `> [!TIP]` / `> [!NOTE]` callouts, `## Related` footer with full URLs
- File naming: `snake_case.md` in `doc/` subdirectories
- Code examples: Use real magic_starter class names and patterns, not generic placeholders
- Section dividers in stubs: 73-char ASCII dash comments
- Stub indentation: 4 spaces
- English only — all content in English
