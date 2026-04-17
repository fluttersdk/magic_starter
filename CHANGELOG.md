# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### 🐛 Bug Fixes
- **Mobile Header Brand**: `MagicStarterAppLayout` mobile topbar now honors `navigationTheme.brandBuilder`, so custom brand widgets render consistently across breakpoints when provided ([#65](https://github.com/fluttersdk/magic_starter/issues/65))

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
