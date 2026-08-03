# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.0.1-alpha.19] - 2026-08-03

### Added

- **`MSPageContainer`: one page container for every page, in this package and in the host app.** The width cap the previous release handed to the host fixed the settings pages and nothing else, because the cap was only ever half the geometry and only one of three surfaces read it. The team pages (`/teams/create`, `/teams/settings`) and the notification pages (`/notifications`, `/notifications/preferences`) opened with a bare `WDiv(className: 'p-4 lg:p-6 flex flex-col gap-6')`: no cap at all, so on a desktop window they spread the full width of the content region while the settings and host pages centred in a column, and `p-4 lg:p-6` against the settings scaffold's `px-4 lg:px-8` put their headers on a different vertical and horizontal grid. Three surfaces, three answers, one shell. `MSPageContainer` now owns the geometry (width, edge margins, vertical rhythm, plus a horizontal safe-area guard so content never slides under a rounded display corner), `MSPageScaffold` composes it, and a host app uses the same component for its own pages. Nothing per page is left to disagree about.
- **`MSPageScaffold.actions` forwards page-level actions to the shared header.** A page that needed an action next to its title (Notifications and its "mark all read") had to build its own `MSPageHeader`, and a page that builds its own header builds its own container right after. Now it passes `actions` and keeps the shared chrome.
- **The Notifications, Notification Preferences, Team Create, Team Settings, and Profile Settings views moved onto `MSPageScaffold`.** They now share the page surface, the scroll ownership (`primary: false`), the geometry, and the header with every settings page. Their view slots (`header`, `footer`, `afterSection:*`) are unchanged and still render in the same order, as the first and last children of the sections column.

### Breaking

- **`MagicStarterManager.settingsMaxWidthClassName` is now `pageContainerClassName`, and carries the WHOLE geometry instead of just the cap.** Migration is one line: `MagicStarter.manager.pageContainerClassName = 'max-w-6xl px-4 sm:px-5 lg:px-8 pt-6 sm:pt-8 pb-24';`, using the same values the host's own page container uses. Passing only a cap (`'max-w-6xl'`) still works and keeps the starter's default padding, so the old one-value call is a valid subset. One string rather than a cap knob plus a padding knob is deliberate: a cap that agrees while the padding does not still reads as two different pages. The default is `MagicStarterManager.defaultPageContainerClassName` (`max-w-7xl px-4 lg:px-8 pt-6 sm:pt-8 pb-16`), which reproduces the previous scaffold geometry exactly, so **an app that configures nothing sees no visual change.**
- **`MSSettingsScaffold` is now `MSPageScaffold`, and lives at `lib/src/ui/components/page_scaffold/`.** It stopped being a settings component the moment the team and notification pages needed it. Migration is the rename; the constructor is unchanged apart from the added optional `actions`.
- **`settingsScaffoldContainerRecipe()` is removed.** Its job is `MSPageContainer`'s now. A consumer that called it directly should render `MSPageContainer` instead, or read `pageContainerRecipe(hostClassName: ...)` if it only wants the className. `settingsScaffoldScrollableRecipe()` is now `pageScaffoldSurfaceRecipe()` and `settingsScaffoldChildrenAreaRecipe()` is now `pageScaffoldChildrenAreaRecipe()`; both are unchanged in output.
- **Every pre-`MS`-prefix alias widget is removed: `MagicStarterCard`, `MagicStarterPageHeader`, `MagicStarterSocialDivider`, `MagicStarterNotificationDropdown`, `MagicStarterTeamSelector`, `MagicStarterUserProfileDropdown`.** All six were empty subclasses that added nothing to `MSCard`, `MSPageHeader`, `MSSocialDivider`, `MSNotificationDropdown`, `MSTeamSelector` and `MSUserProfileDropdown`, and keeping them split this package's own code across two names for one component: the team views used the canonical names while the notification and profile views used the aliases, and the app layout reached for the aliases while the components it composed documented themselves against them. Migration is the rename, nothing else: every constructor parameter, `CardVariant`, and the barrel export path are unchanged. Their test files are gone too, but no coverage went with them: the assertions that were unique to an alias test (five menu-content cases on the user-profile dropdown, four optional-slot cases on the page header) moved into the canonical component test, and the rest were duplicates of assertions the canonical test already made.
- **`MagicStarterTimezoneSelect` is NOT affected** and keeps its name. It reads as one of the aliases but is a real 242-line widget with no `MS` counterpart, like `MagicStarterConfirmDialog` and `MagicStarterDialogShell`.

## [0.0.1-alpha.18] - 2026-08-02

### Added

- **`MagicStarterManager.settingsMaxWidthClassName`: the host now owns how wide the Settings pages are.** `MSSettingsScaffold` centres its own content column, and it always capped that column at its own `max-w-7xl` regardless of the app it was rendering in. A host app caps its own pages wherever it likes, so in any app that does not happen to use the same value both columns centred inside the SAME content region at DIFFERENT widths: same sidebar, same chrome, and every settings header starting tens of pixels further out than the header on every other page (64px per side against a `max-w-6xl` host, measured on a 1800px viewport). Registering the host's own shell as `layout.app` does not fix this and in fact hides it, because the two columns then differ inside identical chrome. Set the field once, from the same constant the host's own page container uses, and the two cannot drift: `MagicStarter.manager.settingsMaxWidthClassName = PageContainer.maxWidthClassName;`. It defaults to `MagicStarterManager.defaultSettingsMaxWidth` (`max-w-7xl`), the value the scaffold has always used, so **an app that configures nothing sees no change in width.**

### Fixed

- **Every Settings page sat 32px higher than every other page in the app, because the scaffold emitted no vertical page padding at all.** The app layout's content region is a bare scroll view with no padding of its own, so a page's own `pt-*` is the only thing standing between its header and the top edge of the viewport, and `settingsScaffoldContainerRecipe` emitted none. The header was therefore glued to the top edge on every settings screen, in every consumer, since the recipe was written. It now emits `pt-6 sm:pt-8` plus a `pb-16` so the last section does not end flush against the fold. Verified against a host app on a 1800px viewport: content top and the full content column (left AND right edge) now identical across the host's dashboard, its list pages and the starter's settings pages, checked in production rather than only locally.
- **The class docblock described a column the widget had stopped rendering.** It claimed the inner column was always `w-full max-w-2xl mx-auto px-4 lg:px-0`; the recipe had been emitting `px-4 lg:px-8` with a `max-w-7xl` cap for some time, so the documentation was already wrong before this release and would have sent a reader looking for padding that was not there. It now states the real className, says why the vertical padding is this column's own responsibility, and names the host as the owner of the cap.

### Breaking

- **`settingsScaffoldContainerRecipe()` now takes a required `maxWidthClassName`.** The recipe is exported from the package barrel, so a consumer calling it directly must pass a cap. Migration is one argument: `settingsScaffoldContainerRecipe(maxWidthClassName: MagicStarterManager.defaultSettingsMaxWidth)` reproduces the previous output exactly. The parameter is required rather than defaulted on purpose: a cap nobody had to think about is precisely how the widths drifted apart in the first place. `MSSettingsScaffold` itself is unchanged for callers, and passes the host's configured value for you.

## [0.0.1-alpha.17] - 2026-07-29

### Added

- **`MagicStarter.bootstrap()` is now the single entry point for the starter's identity contract.** The starter needs four things from the host app before it behaves correctly: how to build the app's user model, what logging out does, which locales to offer, and (only when the teams feature is on) how to read and switch teams. Those were four separate `use*` calls that nothing enforced, and forgetting one failed SILENTLY: `MagicStarterManager.userFactory` defaults to `MagicStarterAuthUser.fromMap`, so an app that skipped `useUserModel` kept running while every starter screen quietly read the starter's own user type instead of the app's. `bootstrap()` makes `userFactory`, `onLogout` and `locales` required named arguments. The three team callbacks stay optional because teams are opt-in (`magic_starter.features.teams` defaults to `false`) and a teamless app must not be forced to pass stubs, but they are cohesive: a partial set throws an `ArgumentError` before any setter runs (so a rejected call leaves the manager untouched rather than half-configured), and enabling the teams feature without them throws a `StateError`. That second check finally gives `MagicStarterManager.isReady` a reader; it encoded exactly this rule and nothing had ever called it. All four individual setters remain public and unchanged for partial or advanced setup, and the 16 optional theming setters are deliberately NOT part of `bootstrap()`. The installer now scaffolds `bootstrap()` instead of the loose calls, on both the inject-into-existing-provider path and the `--force` / first-install stub path. Covered by `test/facades/magic_starter_bootstrap_test.dart` and the install-command tests; documented in `doc/getting-started/installation.md`.

- **`SessionScopedController` plus `SessionScopeSync`: a fix for a cross-tenant data leak every magic app has.** magic caches controllers as Type-keyed singletons and runs `onInit` once per instance lifetime, so a logout followed by a login as a DIFFERENT user, or a team switch, never re-runs the initial fetch and the previous session's rows stay on screen until a hard reload. On a team-scoped product that is not staleness, it shows one tenant's data to another. A controller that caches team-scoped data now implements `SessionScopedController.resetForSession()`, and the host calls `SessionScopeSync.attach()` once from its service provider to drive them off `Auth.stateNotifier`, keyed on `<userId>:<teamId>` so a team switch counts as an identity change. Three rules are load-bearing: `resetForSession()` must CLEAR before it refetches (ordinary `reload()` paths are deliberately non-destructive so a transport blip does not blank a dashboard, which is exactly wrong across an identity change, where a failed refetch must leave the screen empty rather than populated with the previous tenant's data); only a change to a NON-NULL identity resets, because resetting on logout could only fire requests that 401 from the login screen; and each controller's reset is isolated, so one failure logs and does not abort the others. Covered by `test/http/session_scoped_controller_test.dart`; documented in `doc/basics/session-scope.md`.

- **`EnsureAuthenticated` and `RedirectIfAuthenticated` middleware, ready to register as the `auth` and `guest` aliases.** Both resolve their destinations through `MagicStarterConfig.loginRoute()` / `homeRoute()` rather than literals, and both override `redirectTarget` (a pre-build synchronous redirect) instead of `handle` (a post-build remount), so a guarded page never mounts for a visitor who is about to be redirected away. Each guards its own destination so the redirect cannot loop, which matters because go_router raises after more than five successive redirects. Documented in `doc/basics/middleware.md`.

- **`PlanUpgradeRequirement`, `UpgradePrompt`, `MSUpgradeDialog` and `MSUpgradeNudge`: a plan-gate wall with the purchase action attached.** A plan-gated refusal used to end in a plain error toast that named the tier in prose and left the user to find billing, the plan and the checkout button themselves. `PlanUpgradeRequirement.fromResponse` reads a `403` carrying an `upgrade.required_plan` marker and returns `null` for anything else, so a caller can branch on "upgrade wall or real failure" without matching English prose. The marker is REQUIRED on purpose: a `403` without it is an authorization denial no purchase fixes (a team-scope denial, a revoked token), and offering to upgrade there would be a lie. The destination is `MagicStarterConfig.billingRoute()` (`magic_starter.routes.billing`, default `/teams/billing`), and each navigation mints a fresh single-use `intent` token because the billing screen mounts more than once per arrival (the router rebuilds it on the auth-state refresh) and both mounts read the same query, which previously opened two checkout sessions. The two widgets read their copy from `common.upgrade`, `common.upgrade_available_on` and `common.upgrade_dialog_not_now`, which are added to the published `en` lang stub so an installed app resolves them; a consumer that installed an earlier stub should add those three keys. Covered by `test/support/plan_upgrade_test.dart` and the two component test folders.

- **The `layout.app` override seam is documented.** `MagicStarterAppLayout` was already the registered default, so a fresh install always rendered account routes in a working shell, but an app with its own navigation chrome had no documented way to host starter routes inside it and would render them in a second, different shell. `MagicStarter.view.registerLayout('layout.app', (child) => MyShell(child: child))` is that seam; it is now documented in `doc/basics/views-and-layouts.md` with the ordering rule, and pinned by `test/ui/layout_override_test.dart`.

### Changed

- **Every symbol added in this release is exported from `package:magic_starter/magic_starter.dart`**, and `test/barrel_export_test.dart` imports only that entry point to prove it: a symbol present under `lib/src/` but missing from the barrel is invisible to consumers and would otherwise surface as a compile error in a downstream app.
- **Every component now styles through tokens the starter's own theme guarantees.** The two upgrade widgets arrived from the downstream app still referencing `bg-ai-soft` and `text-ai`, which belong to that app's hand-authored status supplement rather than to the semantic role set. Wind resolves an unknown alias to nothing and drops it silently, so in any other app the lock tile rendered with NO background and the glyph fell back to the inherited colour: a visual no-op with no error, and invisible to `design:lint` (which validates `DESIGN.md`, not className tokens) and to the component tests (which assert text and taps, not decoration). They now use `bg-primary-container` and `text-primary`, both of which the shipped alias map resolves. `MSErrorState`'s icon and title keep their raw `text-red-*` pair deliberately, and now say why in a docblock: the alias contract ships `bg-destructive`, `text-on-destructive` and `bg-destructive-container` but NO destructive TEXT role, so the semantic-looking `text-destructive` is claimed by the parser and then resolves to nothing. Both components are now pinned by tests that assert the RESOLVED colour rather than the className, because a dropped token renders identically to no token at all and every string-level assertion passes straight through it.
- **`starter:doctor` checks the contract it claims to check.** Its verbose output named `MagicStarter.bootstrap` while the probe still grepped `MagicStarter.useNavigation`, an optional theming setter, so a provider missing the identity contract entirely could report OK. It now accepts `bootstrap(` or the legacy `useUserModel(` and says so.
- **`starter:install` no longer overwrites a pre-`bootstrap()` app's setup.** Injection appends at the end of `boot()`, so re-running the installer on an app wired with the individual setters would have placed a generic `bootstrap()` AFTER that app's own `useLocaleOptions()` and `useLogout()`, silently winning by write order and replacing a customized locale list or logout behaviour. The idempotency guard now recognises the legacy shape and leaves such a provider alone.

- **The two new components follow the `MS` namespace** (`MSUpgradeDialog`, `MSUpgradeNudge`) that the rest of the component layer adopted, so nothing new lands in the flat namespace that previously collided with Material. Their preview classes stay unprefixed (`UpgradeDialogPreview`, `UpgradeNudgePreview`), matching every other component.

## [0.0.1-alpha.16] - 2026-07-26

### Added
- **Push-not-provisioned hint on the notification preferences view, driven by the backend.** When the app has no OneSignal `app_id`, a push preference is still offered but the channel is dropped from `via()` at send time, so the toggle silently could not deliver. `MagicStarterNotificationController` now reads `meta.push_provisioned` off both preference responses (`GET` and `PUT /notification-preferences`, added in `magic-starter-laravel`) into `pushProvisionedNotifier`, and the view renders a subtle hint under the push channel label while it is `false`. The flag starts `true` and only moves on a response that actually carries it, so a backend that predates the flag (or a degraded payload) never renders a false "not configured" claim. `MagicStarterNotificationPreferencesView` also takes an optional `bool? pushProvisioned` as a host OVERRIDE (`null`, the default, means "read the backend flag"); pass a bool only to force the hint on or off. The hint reads the new `notifications.channel_push_unconfigured` lang key (added to the published `en` lang stub), so a consumer that installed an earlier stub should add that key to keep it translated. The hint deliberately stays OUTSIDE the label's `ExcludeSemantics` (the exclusion exists so an E2E label lookup resolves the switch, not the text), because it carries information the switch label does not and a screen reader has to announce it. Requires `magic-starter-laravel` with the `meta.push_provisioned` responses; against an older backend the hint simply never shows.

### Changed
- **Dependencies tracked to the current release line: `magic ^0.0.5` and `magic_notifications ^0.0.2`.** Under pub's `0.0.z` caret semantics the previous `^0.0.4` / `^0.0.1` bounds excluded those releases, so the graph could not solve against current magic. magic 0.0.5 also carries the `Model.save()` 422 validation-error surface this starter's forms can read.
- **Account views now style through the semantic alias tokens instead of raw Tailwind gray classes.** The auth screens (login, register, forgot / reset password, OTP verify), the profile and notification views, the team settings / invitation views, the app layout, and the password-confirm / two-factor dialogs used literal `gray-*` classes for their surfaces, borders, and text. They now map to the semantic aliases (`bg-surface*`, `text-fg*`, `border-color-border*`), so a consumer's theme and dark-mode pairs drive them and the account surface matches the rest of the design system. Pure class-name refactor, no behavior change. Touches the auth / profile / teams views under `lib/src/ui/views/`, `lib/src/ui/layouts/magic_starter_app_layout.dart`, and the `magic_starter_password_confirm_dialog` / `magic_starter_two_factor_modal` widgets.

- **Dependency constraints realigned to the 0.0.x release line.** `magic` is now `^0.0.4` (was a stale `^1.0.0-alpha.13` that no published magic satisfied) and `magic_notifications` is `^0.0.1` (was `^0.0.1-alpha.1`). The old `^1.0.0-alpha.13` constraint also conflicted with `magic_notifications`'s `magic ^0.0.3`, so the graph only solved via the local path overrides; it now resolves cleanly against published packages. magic 0.0.4 pulls `fluttersdk_wind ^1.2.0`, which carries the `WindRecipe`/`WindSlotRecipe` API the component layer uses.

- **BREAKING: every design-system component class is now `MS`-prefixed (MS-7b)**: the flat, unprefixed component classes were renamed to an `MS`-prefixed namespace (`Button` -> `MSButton`, `Dialog` -> `MSDialog`, ...) and the old names were removed outright (no re-export, no `@Deprecated` alias, no compat barrel). This ends the `package:flutter/material.dart` collision that previously forced consumers to sprinkle `hide` clauses (`Switch`, `Dialog`, `Checkbox`, `Radio`, `Badge`, `Typography`, `BottomSheet`, `Tooltip`, `DropdownMenu`, `DropdownMenuItem`, `EmptyState`, `ErrorState` all shadowed Material or common consumer names). The already-`MagicStarter*`-prefixed public widgets (`MagicStarterCard`, `MagicStarterPageHeader`, ...), the per-axis enums (`ButtonIntent`, `InputState`, `BadgeTone`, ...), and the recipe functions/consts are unchanged. Migration: replace each old class name with its `MS` counterpart and drop any now-unnecessary `hide` clause.

  | Old name | New name | Old name | New name |
  |----------|----------|----------|----------|
  | `Button` | `MSButton` | `Tooltip` | `MSTooltip` |
  | `Input` | `MSInput` | `DropdownMenu` | `MSDropdownMenu` |
  | `Textarea` | `MSTextarea` | `DropdownMenuItem` | `MSDropdownMenuItem` |
  | `Checkbox` | `MSCheckbox` | `MagicFormField` | `MSFormField` |
  | `Switch` | `MSSwitch` | `Navbar` | `MSNavbar` |
  | `Radio` | `MSRadio` | `EmptyState` | `MSEmptyState` |
  | `Badge` | `MSBadge` | `ErrorState` | `MSErrorState` |
  | `Typography` | `MSTypography` | `SettingsSection` | `MSSettingsSection` |
  | `Skeleton` | `MSSkeleton` | `SettingsRow` | `MSSettingsRow` |
  | `Select` | `MSSelect` | `SettingsNavRow` | `MSSettingsNavRow` |
  | `Combobox` | `MSCombobox` | `SettingsScaffold` | `MSSettingsScaffold` |
  | `SegmentedControl` | `MSSegmentedControl` | `Card` | `MSCard` |
  | `Tabs` | `MSTabs` | `PageHeader` | `MSPageHeader` |
  | `Accordion` | `MSAccordion` | `SocialDivider` | `MSSocialDivider` |
  | `AccordionItem` | `MSAccordionItem` | `NotificationDropdown` | `MSNotificationDropdown` |
  | `Dialog` | `MSDialog` | `UserProfileDropdown` | `MSUserProfileDropdown` |
  | `BottomSheet` | `MSBottomSheet` | `TeamSelector` | `MSTeamSelector` |
  | `Toast` | `MSToast` | `ConfirmDialog` | `MSConfirmDialog` |

  Note: `MagicFormField` becomes `MSFormField` (the `Magic` segment is dropped, not double-prefixed). The `MagicStarter*` alias widgets keep their names and now subclass the `MS`-prefixed components (`MagicStarterCard extends MSCard`).

### Fixed
- **`doUpdateProfile` now sends the `language` param under the `locale` wire key**: `MagicStarterProfileController.doUpdateProfile` was posting the language change as body field `language`, but `magic-starter-laravel`'s `UpdateProfileRequest` validates `locale`, so the field was silently dropped and language changes never persisted. The Dart-side `language` parameter name is unchanged (existing call sites keep passing `language:`); only the outgoing wire key is corrected to `locale`.
- **`MagicStarter.manager` no longer throws when `magic_starter` is unbound (MS-6)**: components that read theme through the facade (e.g. `Card` via `MagicStarter.cardTheme`) threw `"Service [magic_starter] is not registered"` when rendered without a running `MagicStarterServiceProvider` — e.g. a standalone widget test or a `/preview` catalog entry. `MagicStarter.manager` now checks `Magic.bound('magic_starter')` first and, when unbound, falls back to a shared default-constructed `MagicStarterManager()` (its 7 sub-themes already hold const defaults) instead of throwing. The fallback emits a one-time `kDebugMode` warning ("MagicStarterManager not bound; using defaults...") so a genuine forgot-to-bind bug in a real app still surfaces in development; a bound manager still wins. Note: in `kReleaseMode` the fallback is silent (no warning) and renders unbranded defaults, so wire `MagicStarterServiceProvider` in production even though a missing binding no longer crashes.
- **Caller `className` now APPENDS onto the component recipe instead of replacing it (WIND-1)**: 14 components (`Button`, `Badge`, `Input`, `Textarea`, `Card`, `Switch`, `Checkbox`, `Radio`, `Skeleton`, `Toast`, `Typography`, `DropdownMenu`, `Tooltip`, `SettingsSection`) previously bypassed their recipe entirely when a caller passed `className` (`if (className != null) return className!` / `className ?? recipe()`), so `Button(intent: primary, className: 'w-full')` dropped the primary fill and every base token. Each component now routes the caller `className` through the recipe's caller-slot (`recipe(variants: {...}, className: className)`), so it appends last and Wind's parse-time per-family last-wins resolves conflicts while every non-overridden base class survives. `DropdownMenu` also threads its per-item `className` (active + disabled) through per-item recipes, `Radio` appends `indicatorClassName`, `Switch` appends `thumbClassName`, and `SettingsSection` appends both `containerClassName` and `captionClassName`. `Tooltip` and `DropdownMenu`, which had hardcoded default strings and no recipe, now lift those defaults into small `WindRecipe`s (`tooltipPanelRecipe`, `dropdownMenuPanelRecipe`, `dropdownMenuItemRecipe`, `dropdownMenuItemDisabledRecipe`); the previous `kTooltipDefaultPanelClassName` / `kDropdownMenu*ClassName` string constants are removed in favor of these recipes. Default styling (no caller `className`) is byte-identical to before.
- **`SegmentedControl` rendered its segments vertically**: the recipe `root` slot used `inline-flex`, which Wind does not support (no inline layout) and which falls back to a vertical flex column, so the segments stacked top-to-bottom instead of sitting side by side. Changed `root` to `flex flex-row items-center` so the control lays its segments out horizontally as intended.

### Added
- **`MagicStarter.useWindTheme(WindThemeData)` one-call theme adoption (MS-7a)**: a single call now derives all 7 magic_starter sub-themes (navigation, modal, form, card, page header, layout, auth) from a `WindThemeData`'s semantic alias palette and delegates to the existing `useTheme(MagicStarterTheme)` hook, so a consumer aligns every built-in surface to their brand without hand-building up to 7 sub-theme structs. Backed by a new `MagicStarterTheme.fromWind(WindThemeData)` factory that rebuilds each color-bearing className from the 17 semantic roles (`bg-surface`/`bg-surface-container`/`bg-surface-container-high`, `text-fg`/`text-fg-muted`/`text-fg-disabled`, `bg-primary`/`text-on-primary`/`text-primary`, `border-color-border`/`border-color-border-subtle`, `bg-destructive`/`text-on-destructive`/`bg-destructive-container`). Each alias carries its own `dark:` pair, so a single token replaces every `bg-white dark:bg-gray-800`-style pair. A role is emitted as a token only when the passed theme defines it (as an alias key or a backing color key); otherwise the property keeps the shipped default palette pair, so a partially-configured theme never renders a silent no-op surface. Purely additive: `useTheme` and every individual `use*Theme()` setter still work and override afterward. Pair it with `MagicStarterTokens.defaultAliases` (or a `design:sync`-generated alias map) to re-skin every surface. See `doc/guides/wind-theme-adoption.md` for the full alias-to-property mapping.
- **`setUpMagicStarterForTests()` test utility (MS-6)**: `lib/src/testing/magic_starter_test_utils.dart` (exported from the release barrel) wraps the `Magic.singleton('magic_starter', () => MagicStarterManager())` idiom repeated across 16+ test files. Call `setUpMagicStarterForTests()` for a default manager, or `setUpMagicStarterForTests(manager: myManager)` to bind a pre-configured one. Combined with the `MagicStarter.manager` defensive fallback above, tests may now omit this call entirely for components that only need default theme values.
- **First-class `fullWidth` prop on `Button`, `Input`, `Textarea` (MS-2)**: each component gains a `bool fullWidth = false` constructor prop. Because Material widgets ignore cross-axis stretch inside a `Column` (flutter/flutter#19399), setting `fullWidth: true` wraps the rendered `WButton`/`WInput` in a `SizedBox(width: double.infinity)` at the widget layer instead of relying on a `className` token; the recipe stays width-agnostic (`inputRecipe`/`textareaRecipe` no longer bake an unconditional `w-full` into their `base`). `fullWidth` is orthogonal to `size` (a layout concern, not the padding/font scale) and defaults to `false` (content-width).
- **`package:magic_starter/previews.dart`** (dev-only barrel): exposes all 30 component previews as `(label, slug, builder)` records via `starterComponentPreviews()`, so a consumer's dev-only preview catalog can surface the full component set (Button, Badge, ..., UserProfileDropdown, TeamSelector, NotificationDropdown) without duplication. Kept SEPARATE from the `magic_starter.dart` release barrel (the atomic-component contract keeps `*.preview.dart` out of release); the records are returned from a function (not a top-level const holding widget refs), so a consumer that only calls it behind a `kReleaseMode`/`PREVIEW_ENABLED` guard tree-shakes the whole set from release.
- **`design.md.stub`**: a `DESIGN.md` template shipped at `assets/stubs/design.md.stub` covering all 17 semantic roles (`surface`, `fg`, `primary`, `border`, `destructive`, `success`, `warning`, and their variants), typography on the 4px logical scale, rounded/spacing scales, and key component entries with `{{ placeholder }}` tokens. Consumers copy it into their project root, fill in brand hex values and fonts, then run `design:lint` to validate and `design:sync` to generate the Wind theme. Pairs with `MagicStarterTokens.defaultAliases` as the stable key contract.
- **Wave 4 design-system component library**: 23 new generic UI components are now part of the public barrel (`package:magic_starter/magic_starter.dart`). Each component lives in the canonical atomic-component folder shape (`<name>.dart`, `<name>.recipe.dart`, `<name>.preview.dart`, `index.dart`) under `lib/src/ui/components/`.
  - **Form controls**: `Button` (with `ButtonIntent`, `ButtonSize`, `buttonRecipe`), `Input` (with `InputState`, `inputRecipe`), `Textarea` (with `TextareaState`, `textareaRecipe`), `Checkbox`, `Switch`, `Radio`, `Select` (with `selectRecipe`), `Combobox` (with `comboboxRecipe`).
  - **Feedback and display**: `Badge` (with `BadgeTone`), `Typography` (with `TypographyVariant`), `Skeleton` (with `SkeletonShape`), `Toast` (with `ToastVariant`), `Tooltip`, `EmptyState`, `ErrorState`.
  - **Layout and navigation**: `Accordion` (with `AccordionItem`, `accordionRecipe`), `SegmentedControl` (with `SegmentedControlSize`, `segmentedControlRecipe`), `Tabs` (with `tabsRecipe`), `Navbar`, `Dropdown` menu (`DropdownMenu`, `DropdownMenuItem`).
  - **Overlay**: `Dialog`, `BottomSheet`.
  - **Composition**: `MagicFormField` (label, hint, error wrapper).
  - Previously migrated components (`Card`, `PageHeader`, `SocialDivider`, `NotificationDropdown`, `UserProfileDropdown`, `TeamSelector`, `ConfirmDialog`) were already barrel-reachable through their existing alias exports and are unchanged.
  - **Collision resolved by the `MS` prefix (see the BREAKING entry below)**: these components were initially added under bare names (`Switch`, `Dialog`, `Checkbox`, `Radio`, `Badge`, `Typography`, `BottomSheet`, `Tooltip`, `DropdownMenu`, `DropdownMenuItem`) that collided with `package:flutter/material.dart`. They now carry an `MS` prefix (`MSSwitch`, `MSDialog`, ...), so importing both packages no longer needs a `hide` clause.

### Changed
- **Wave 5 view rewrite**: the auth (login, register, forgot, reset, two-factor-challenge, otp-verify), profile, notifications (list + preferences matrix), and teams (create, settings, invitation-accept) views plus both layouts (`MagicStarterAppLayout`, `MagicStarterGuestLayout`) now compose the new design-system components (`Button`, `Card`, `Switch`, `PageHeader`, `SocialDivider`, etc.) instead of inline W-widgets. Views are now Wind-exclusive: bare `package:flutter/material.dart` imports were replaced with `widgets.dart` + `material show Icons` (and the few genuinely-needed Material shells via `show`), so the new component names no longer collide. Behavior, registry keys (`auth.*`, `profile.*`, `notifications.*`, `teams.*`, `layout.app`, `layout.guest`), controller contracts, gate abilities, `refreshNotifier`, and notification polling are all preserved; only the presentation layer changed.
- **Card migrated to the atomic-component folder + `WindRecipe`**: the card now lives at `lib/src/ui/components/card/` in the canonical 4-file shape (`card.dart` → `class Card`, `card.recipe.dart`, `card.preview.dart`, `index.dart`) and resolves its root className through a theme-driven `WindRecipe` instead of inline string interpolation. The recipe output is byte-identical to the previous `_defaultClassName` for every `CardVariant` x `noPadding` combination (gated by an explicit equivalence test). `MagicStarterCard` is retained as a thin re-export alias of `Card`, and `CardVariant` plus the barrel export path (`package:magic_starter/magic_starter.dart`) are unchanged, so existing callers and the widget-test suite are untouched. This establishes the verbatim template for the Wave 4 component migration.

### Added
- **`MagicStarterTokens.defaultAliases`**: semantic token alias map with 17 roles (`surface`, `surface-container`, `surface-container-high`, `fg`, `fg-muted`, `fg-disabled`, `primary`, `on-primary`, `primary-container`, `accent`, `border`, `border-subtle`, `destructive`, `on-destructive`, `destructive-container`, `success`, `warning`). Each role maps to a light+dark wind className pair (`'bg-... dark:bg-...'` / `'text-... dark:text-...'`). Pass as `WindThemeData(aliases: MagicStarterTokens.defaultAliases)` so components resolve against semantic roles rather than palette utilities directly. This map is the stable key contract that `design:sync` (Steps 20-21) will later regenerate from `DESIGN.md`.

### Fixed
- **User dropdown adds a Settings (hub) entry + items work on web**: the user-profile dropdown now lists `Settings` (-> the iOS settings hub) above `Profile`. The dropdown items previously appeared dead on web (clicking did nothing and the popover closed; reopening closed immediately) because of a `WPopover` focus-loss auto-dismiss — fixed upstream in `fluttersdk_wind` (see its changelog).
- **Account deletion moved off the Profile form to Security**: the destructive Delete Account row no longer sits on the Profile sub-page (it read as tacked-on); it now lives in a Danger section at the bottom of the Security > Browser Sessions sub-page, reusing the same password-confirm dialog and `doDeleteAccount` unchanged.
- **Guest auth screens no longer crash during in-app transitions**: `MagicStarterGuestLayout` wrapped its content in `SingleChildScrollView(primary: true)`, which attaches to the ambient `PrimaryScrollController`. Auth routes use `RouteTransition.none`, so navigating between guest screens (login -> register -> forgot, etc.) briefly mounts the outgoing and incoming routes together; two `primary: true` scroll views then contended for the single `PrimaryScrollController` and detached each other mid-layout, producing a `dropChild` / "RenderBox.size accessed beyond scope" / "wrong build scope" assertion cascade (and, on the worst cold-start case, a red error screen). The scroll view is now `primary: false` so each guest page owns its own implicit controller and never contends for the shared one.
- **PR #78 review (release boundary + semantic tokens + Wind-only previews):**
  - Component `index.dart` barrels no longer re-export their `*.preview.dart` (9 components: error_state, empty_state, navbar, form_field, notification_dropdown, social_divider, page_header, user_profile_dropdown, team_selector). Previews are dev-only and must stay out of the release barrel (`magic_starter.dart` re-exports every `index.dart`); `previews:refresh` and the `previews.dart` dev barrel discover `*.preview.dart` directly, so the exports leaked previews into release for no benefit. Preview tests now import the preview file directly.
  - `Tooltip` default panel + `kTooltipDefaultPanelClassName` use semantic alias tokens (`bg-surface-container-high text-fg border border-color-border`) instead of hardcoded gray palette utilities, so tooltips re-skin via `MagicStarterTokens` / `design:sync`. The `Tooltip` doc comment was corrected to describe the actual `enableTriggerOnTap: true` behavior (it does not use a `PopoverController`).
  - `BottomSheet` drag handle uses `bg-surface-container-high` instead of `bg-gray-300 dark:bg-gray-600`.
  - `PageHeader` / `EmptyState` / `ErrorState` previews render their action with the design-system `Button` + `WText` instead of Material `ElevatedButton` / `Text`, keeping previews Wind-only and dropping the Material import churn.
- **Creating a team now switches to it.** `MagicStarterTeamController.doCreate` only set the local `currentTeamId` notifier after `POST /teams`; the backend's `current_team_id` stayed on the previous team, so the resolver-driven sidebar name and active-team highlight showed the OLD team while local state and the member fetch pointed at the new one (REPORT #14, confirmed via e2e: create opened the old team's settings). `doCreate` now calls `PUT /user/current-team` with the new id before `Auth.restore()` (Jetstream create-then-switch), so the server, resolver, sidebar, and settings all agree on the new team.
- **`Button` no longer forces full-width**: the `buttonRecipe` base dropped `justify-center`, which in Wind maps to WButton's `Container` alignment and made every default `Button()` expand to fill its constraints (stacking one-per-row in a variant row). A default button now shrinks to its content (its `inline-flex` intent), with the label centered by the shrink-wrapped padding box. Form/modal buttons are unaffected: they pass a `className` override (the form theme ships `w-full`), which bypasses the recipe base entirely.
- **Create team opens the new team's settings**: `MagicStarterTeamController.activeTeamName` now matches the local `currentTeamId` (when set) against the resolver's `allTeams()` by id, falling back to the resolver's `currentTeam()` when no match exists. Previously `activeTeamId` preferred the local `currentTeamId` notifier (set on create/switch) while `activeTeamName` read only the resolver's `currentTeam()`, so after creating a team the settings view pre-filled the OLD team's name and effectively opened the old team ([#14](https://github.com/fluttersdk/magic_starter/issues/14)).

### Removed
- **Breaking: Standalone CLI entrypoint** — removed `bin/magic_starter.dart` and `dart run magic_starter:*` commands. Commands now surface via the host app's artisan dispatcher. Migrate: `dart run magic_starter:install` becomes `dart run <app>:artisan starter:install` (register `StarterArtisanProvider` in your app's `artisan.providers` list).
- **Removed magic_cli dependency**: CLI now builds on `fluttersdk_artisan ^0.0.8`.

### Changed
- **plugin:install auto-scaffolds starter**: `install.yaml` now declares `bootstrap_command: starter:install` so `plugin:install magic_starter` automatically runs the full starter scaffold (config, routes, middleware, dashboard) without a separate manual step. Requires `fluttersdk_artisan ^0.0.9` which introduced auto-execution of the `bootstrap_command` field. Pass `--no-bootstrap` to skip the auto-run.
- **post_install message**: reworded so it no longer flatly claims the `starter:install` bootstrap succeeded (a chained-bootstrap failure previously left the message asserting a scaffold that never happened). It now tells the operator to run `dart run <app>:artisan starter:install` by hand if the bootstrap exited non-zero or `lib/config/magic_starter.dart` is missing, shows the `--features=` one-liner, and documents the `--no-bootstrap` opt-out. Pairs with `fluttersdk_artisan`'s fix that surfaces a non-zero bootstrap exit code.
- **Install is manifest-driven** — static scaffolding (config publish, provider injection) now driven by `install.yaml` manifest; dynamic logic (feature toggles, interactive mode) handled by fluent override in `MagicStarterInstallCommand`.

### Added
- **Read-only MCP tool** — `starter_doctor` diagnostic command exposed as a read-only MCP tool via `StarterArtisanProvider.mcpTools()`.

### 🐛 Bug Fixes
- **Social login translation keys**: the install-generated `assets/lang/en.json` (from `assets/stubs/install/en.stub`) now ships `auth.sign_in_with` and `auth.sign_up_with`. The social-login buttons (`SocialAuthButtons` from `magic_social_auth`) call `trans('auth.sign_in_with', {'provider': ...})`, but `magic_social_auth` ships no lang file and magic loads translations only from the consumer's `assets/lang`, so a fresh `starter:install` with `social_login` enabled previously rendered raw keys ("auth.sign_in_with") instead of "Sign in with Google". Surfaced by a full reference-app E2E bring-up.
- **Mobile Header Brand**: `MagicStarterAppLayout` mobile topbar now honors `navigationTheme.brandBuilder`, so custom brand widgets render consistently across breakpoints when provided ([#65](https://github.com/fluttersdk/magic_starter/issues/65))
- **Page Header Title Truncation**: `MagicStarterPageHeaderTheme` defaults now use `line-clamp-2` instead of `truncate` for `titleClassName` and `subtitleClassName`, so long titles wrap to a second line on narrow viewports (e.g. iPhone-width screens) instead of clipping to "AI sett..." ([#67](https://github.com/fluttersdk/magic_starter/issues/67))

### 🧪 Tests
- **wind 1.1.x widget-test compatibility**: the two-factor modal and password confirm dialog widget tests drove input via `find.byType(TextField)`, which broke once CI resolved `fluttersdk_wind` 1.1.x (the Material-free `WInput`/`WFormInput` rewrite renders an `EditableText` instead of a Material `TextField`). Both files now resolve the field via `find.descendant(of: find.byType(WFormInput), matching: find.byType(EditableText))`, scoping the search to the single form input so the two-factor setup step's selectable secret-key `EditableText` is not matched by accident.

### Fixed
- **Notification-preference toggles now carry an accessible name and expose a single Semantics node.** Each channel toggle (`MSSwitch`) had no `semanticLabel` and sat beside a visible `WText` of the same channel name, so a screen reader announced a bare "switch" while the row exposed TWO nodes sharing the label. The switch now takes `semanticLabel: <channel name>` and the visible label is wrapped in `ExcludeSemantics`, so the row exposes one correctly named toggle. This also gives an accessibility / E2E lookup a single stable target instead of resolving the inert text first. Touches `lib/src/ui/views/notifications/magic_starter_notification_preferences_view.dart`.

## [0.0.1-alpha.14] - 2026-04-16

### ✨ New Features
- **Unified Theme System**: Added `MagicStarterTheme` with 7 sub-themes (`form`, `card`, `navigation`, `modal`, `layout`, `pageHeader`, `auth`) set all theme tokens in one call via `MagicStarter.useTheme()`
- **Builder Slots**: Added `MagicStarter.view.slot()` for partial view customization — override specific sections (header, footer, sidebar) without replacing the entire view
- **Granular Publish Command**: `dart run magic_starter:publish --tag=views:auth.login` publishes a single view file to the host app for full ownership
- **Auto-wire Published Views**: Published views are automatically wired into `AppServiceProvider` so they take effect immediately without manual registration
- **Doctor: Published View Detection**: `dart run magic_starter:doctor` now detects published views and reports wiring status — flags views that are published but not registered
- **Layout Theme Drawer Shade**: Added `drawerBackgroundLightShade` to `MagicStarterLayoutTheme` for consistent drawer background customization

### 🐛 Bug Fixes
- **CLI: Cross-platform paths**: Replaced POSIX string manipulation with `package:path` in publish and doctor commands for Windows compatibility
- **CLI: boot() injection**: Publish auto-wire now locates the `boot()` method by signature and brace-depth tracking instead of fragile second-to-last `}` heuristic
- **Team Settings**: Invite button now reads className from `MagicStarter.modalTheme.primaryButtonClassName` instead of hardcoded Wind UI tokens

### 🧪 Tests
- Added slot injection widget tests for 7 views: `forgot_password`, `reset_password`, `two_factor_challenge`, `otp_verify`, `teams.create`, `teams.invitation_accept`, `notifications.preferences`
- Added `drawerBackgroundLightShade` default value test to theme test suite

### 📚 Documentation
- **Manager**: Added unified theme section, 5 new sub-theme sections (form, auth, card, page header, layout), updated facade methods table with all theme accessors
- **View Registry**: Added Builder Slots section documenting slot/hasSlot/buildSlot API
- **CLAUDE.md**: Added publish/uninstall commands, updated manager description, added customization gotchas, updated test count

## [0.0.1-alpha.13] - 2026-04-09

### 🐛 Bug Fixes
- **Icon Tree-Shaking**: Extracted all runtime-conditional `Icons.*` references into `static const` fields for Flutter web tree-shaking compatibility — fixes 11+ broken icon usages across 10 files (#37)

## [0.0.1-alpha.12] - 2026-04-09

### ✨ New Features
- **Sidebar Footer**: Added `sidebarFooterBuilder` slot via `MagicStarter.useSidebarFooter()` — renders custom widget between navigation and user menu in both desktop sidebar and mobile drawer (#27)
- **MagicStarterUserProfileDropdown**: Moved theme toggle from sidebar bottom bar into user profile dropdown menu — sidebar now shows only avatar, name, and notification bell (#30)

### 🐛 Bug Fixes
- **MagicStarterUserProfileDropdown**: Fixed menu overflow when many profile menu items are registered — wrapped menu items in scrollable `overflow-y-auto` WDiv, keeping header and logout footer fixed (#28)
- **Sidebar Navigation**: Fixed overflow when many nav items exceed viewport height — added `overflow-y-auto` to navigation WDiv so items scroll while brand, team selector, and user menu remain fixed (#29)

### 📚 Documentation
- **Manager**: Added `useSidebarFooter()` section and facade entry to manager doc
- **Views & Layouts**: Updated theme toggle location from sidebar to user profile dropdown
- **README**: Added layout customization section with `useHeader()` and `useSidebarFooter()` examples

## [0.0.1-alpha.11] - 2026-04-07

### ✨ New Features
- **MagicStarterPageHeader**: Added `titleSuffix` (Widget?) for inline widgets after title (e.g. status badges) and `inlineActions` (bool) to force single-row layout on all screen sizes (#24)

### 📚 Documentation
- **Release Command**: Added critical tag format warning — `publish.yml` requires tags without `v` prefix (#23)

## [0.0.1-alpha.10] - 2026-04-07

### 🐛 Bug Fixes
- **MagicStarterDialogShell**: Fixed bottom overflow when body content exceeds viewport — removed `flex flex-col` from outer WDiv that broke constraint propagation to inner Column; body now scrolls correctly with sticky header/footer (#21)

### 🔧 Improvements
- **Dependencies**: Bumped minimum `magic` to `^1.0.0-alpha.7` — updated all test setUp blocks to bind `AuthManager` in the IoC container, matching the new container-resolved `Auth` facade

## [0.0.1-alpha.9] - 2026-04-04

### ✨ New Features
- **MagicStarterHideBottomNav**: New `InheritedWidget` that signals `MagicStarterAppLayout` to hide the mobile bottom navigation bar for fullscreen routes — wired into layout and exported from barrel (#19)

### 📚 Documentation
- **State/Controller Registration Guide**: New architecture reference (`doc/architecture/controllers.md`) covering the lazy singleton pattern, `MagicController + MagicStateMixin` usage, controller lifecycle, view binding, and a decision tree for eager vs lazy vs per-view registration (#18)
- **State Management Getting-Started Guide**: New practical guide (`doc/guides/state-management.md`) with end-to-end examples — state class, view integration, and testing patterns for consumer apps (#18)
- **Scaffolded Stub**: `app_service_provider.stub` now includes state registration guidance comments showing the recommended `Magic.findOrPut()` pattern (#18)
- **Cross-References**: `doc/architecture/service-provider.md` now links to the new controllers doc (#18)

### 🔧 Improvements
- **CI**: Bumped `codecov/codecov-action` from v5 to v6 (#16)

## [0.0.1-alpha.8] - 2026-03-31

### 🐛 Bug Fixes
- **MagicStarterDialogShell**: Fixed mobile overflow — `maxHeight` now computed from safe area (`MediaQuery.viewPaddingOf`) instead of raw screen height; added vertical `insetPadding` (24px) to prevent dialog from extending to screen edges (#13)
- **MagicStarterPasswordConfirmDialog**: Same safe area fix — replaced hardcoded `maxHeight: 600` with `safeHeight * 0.85`; added vertical `insetPadding`
- **MagicStarterTwoFactorModal**: Same safe area fix — replaced hardcoded `maxHeight: 800` with `safeHeight * 0.85`; added vertical `insetPadding`

## [0.0.1-alpha.7] - 2026-03-29

### ✨ New Features
- **MagicStarterPasswordConfirmDialog**: Added `ConfirmDialogVariant` support (`primary`, `danger`, `warning`) — confirm button now resolves color from variant via `_resolveConfirmClassName()`, matching `MagicStarterConfirmDialog` behavior. Both constructor and `show()` accept optional `variant` parameter, defaults to `ConfirmDialogVariant.primary` for backwards compatibility.

### 🔧 Improvements
- **Profile Settings**: Standardized dialog variants across all password-confirm call sites — `danger` for session revocation, `warning` for 2FA disable and recovery code regeneration, `primary` for neutral confirmations (enable 2FA, view codes)

## [0.0.1-alpha.6] - 2026-03-29

### 🐛 Bug Fixes
- **MagicStarterPasswordConfirmDialog**: Footer buttons now right-aligned — added `w-full` to footer WDiv so `justify-end` stretches to container width
- **MagicStarterTwoFactorModal**: Footer buttons now right-aligned in both setup and recovery steps — same `w-full` fix applied to both footer locations

### 🔧 Improvements
- **MagicStarterTwoFactorModal**: Extracted duplicated footer className to shared `_footerClassName` const — reduces divergence risk

## [0.0.1-alpha.5] - 2026-03-29

### Changed
- **MagicStarterDialogShell**: Now exported publicly from the barrel (`package:magic_starter/magic_starter.dart`) — consumer apps can compose custom dialogs on top of it
- **MagicStarterDialogShell**: `footer` parameter replaced with `footerBuilder` (`Widget Function(BuildContext dialogContext)?`) — provides the dialog's own `BuildContext` so callers can call `Navigator.pop(dialogContext)` without needing an outer context

### Fixed
- **MagicStarterConfirmDialog** and **MagicStarterPasswordConfirmDialog**: Buttons are now compact and right-aligned (`justify-end gap-2 wrap`) — previously rendered as full-width (`flex-1`) buttons that stretched across the footer
- **MagicStarterDialogShell**: Body no longer creates a gap between scrollable content and the footer when content is shorter than the available height — switched from `SingleChildScrollView` to `ListView(shrinkWrap: true)`

## [0.0.1-alpha.4] - 2026-03-29

### ✨ New Features
- **MagicStarterModalTheme**: Added configurable modal theme system via `MagicStarter.useModalTheme()` with 13 Wind UI className token fields (containerClassName, headerClassName, bodyClassName, footerClassName, titleClassName, descriptionClassName, primaryButtonClassName, secondaryButtonClassName, dangerButtonClassName, warningButtonClassName, errorClassName, inputClassName, maxWidth). All fields optional — zero breaking changes.
- **MagicStarterConfirmDialog**: Generic confirmation dialog with `ConfirmDialogVariant` enum (`primary`, `danger`, `warning`). Static `show()` factory supports async `onConfirm` callback, custom labels, and description. Exported from barrel.
- **Modal View Registry**: Extended `MagicStarterViewRegistry` with `registerModal(key, builder)`, `hasModal(key)`, and `makeModal(key)`. Three default modals auto-registered: `modal.confirm`, `modal.password_confirm`, `modal.two_factor`.
- **MagicStarterDialogShell**: Internal composition widget with sticky header/footer and scrollable body. Uses Material Dialog shell + Wind UI content. Not exported — internal use only.

### 🔧 Improvements
- **PasswordConfirmDialog**: Now reads theme tokens from `MagicStarter.manager.modalTheme` instead of hardcoded classNames
- **TwoFactorModal**: Now reads theme tokens from `MagicStarter.manager.modalTheme` instead of hardcoded classNames
- **Team Settings**: Replaced Material `AlertDialog` with `MagicStarterConfirmDialog.show()` using `ConfirmDialogVariant.danger`

## [0.0.1-alpha.3] - 2026-03-26

### ✨ New Features
- **MagicStarterCard**: Added `CardVariant` enum (`surface`, `inset`, `elevated`) and a `variant` parameter so consumer apps can choose the card's visual style. Default is `CardVariant.surface`, which reproduces the original flat-border appearance and is fully backward-compatible.
- **MagicStarterPageHeader**: Existing `actions` (List<Widget>) and `subtitle` support documented; added widget tests covering all parameters including responsive `sm:flex-row` layout.
- **Configurable navigation theme**: Added `MagicStarterNavigationTheme` class and `MagicStarter.useNavigationTheme()` to allow consumer apps to override navigation colors and styles without breaking changes.
  - `activeItemClassName` — sidebar/drawer active item tokens (default: `active:text-primary active:bg-primary/10 dark:active:bg-primary/10`)
  - `hoverItemClassName` — sidebar/drawer hover tokens (default: `hover:bg-gray-100 dark:hover:bg-gray-800`)
  - `brandClassName` — brand/logo text className including gradient support (default: `text-lg font-bold text-primary`)
  - `brandBuilder` — custom brand widget builder (image/SVG/styled text); overrides `brandClassName` when set
  - `bottomNavActiveClassName` — bottom nav active icon/label tokens (default: `active:text-primary`)
  - `avatarClassName` — sidebar user menu avatar background (default: `bg-primary/10 dark:bg-primary/10`)
  - `avatarTextClassName` — sidebar user menu avatar initial color (default: `text-sm font-bold text-primary`)
  - `dropdownAvatarClassName` — profile dropdown trigger avatar background (default: `bg-gradient-to-tr from-primary to-gray-200`)
  - All fields optional — zero breaking changes, existing apps continue to work unchanged

## [0.0.1-alpha.2] - 2026-03-25

### 🐛 Bug Fixes
- **Install Command**: Use version dependency (`^0.0.1-alpha.1`) for `magic_notifications` instead of hardcoded relative path that only works in monorepo development environment

## [0.0.1-alpha.1] - 2026-03-25

### ✨ Core Features
- **Authentication**: Login, register, forgot/reset password with email and phone identity modes
- **Guest Auth**: OTP-based phone login with send and verify flow
- **Two-Factor Authentication**: Enable/disable 2FA with QR code setup, OTP confirmation, and recovery codes
- **Social Login**: OAuth integration with configurable providers
- **Profile Management**: Photo upload, email/password change, email verification, session management, timezone selection
- **Extended Profile**: Additional profile fields with locale and timezone defaults
- **Teams**: Create teams, switch active team, invite members, manage roles
- **Notifications**: Real-time polling, mark read/unread, notification preference matrix
- **Newsletter**: Simple subscribe/unsubscribe controller
- **13 Feature Toggles**: All opt-in — teams, profile_photos, registration, two_factor, sessions, guest_auth, phone_otp, newsletter, email_verification, extended_profile, social_login, notifications, timezones
- **9 Gate Abilities**: Authorization checks for profile sections (photo, email, phone, password, verify-email, two-factor, newsletter, sessions, delete-account)
- **View Registry**: String-keyed view factory — host app can override any screen or layout
- **Wind UI**: Tailwind-like className system — no Material widgets in layouts
- **CLI Tools**: install, configure, doctor, publish, uninstall commands with stub templates
- **2 Layouts**: AppLayout (authenticated) and GuestLayout (auth pages)
- **12 Views**: 6 auth, 1 profile, 3 teams, 2 notifications
- **10 Widgets**: Reusable Wind UI components (auth form card, card, password confirm dialog, team selector, notification dropdown, two-factor modal, timezone select, user profile dropdown, social divider, page header)

### 🐛 Bug Fixes
- **Timezone**: Fix API field name and add comprehensive null safety checks
- **Auth**: Correct register endpoint from `/auth/login` to `/auth/register`
- **UI**: Remove flex Row from password confirm dialog buttons to prevent overflow

### 🔧 Improvements
- **Auth Events**: Add auth restored listener for app reload on team switch
- **Validation**: Add input validation and network error handling to auth controllers
- **Config**: Add HTTP timeout and retry configuration
- **i18n**: Add notification and network error translation keys to en.stub

### 📚 Documentation
- **README**: Full pub.dev-ready README with badges, features table, quick start guide
- **doc/ folder**: Comprehensive documentation (installation, configuration, authentication, profile, teams, notifications, views, CLI, architecture)
- **CLAUDE.md**: Rewrite to match Magic ecosystem format
- **Publishing**: Package metadata, CI/CD workflows, issue templates, LICENSE
