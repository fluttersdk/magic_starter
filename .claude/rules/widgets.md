---
path: "lib/src/ui/widgets/**/*.dart"
---

# UI Widgets

- Class hierarchy: `extends StatefulWidget` or `extends StatelessWidget` — NOT MagicStatefulView
- Dialog factory: `static Future<T?> show(BuildContext context, ...)` with `showDialog()` or `showModalBottomSheet()`
- Password confirm dialog: inline error handling via `setState()` — never auto-close on error
- Card widget: `noPadding` option for full-bleed list content inside card body; `variant` enum (`CardVariant.surface` default, `CardVariant.inset`, `CardVariant.elevated`) controls background/border/shadow; title in `noPadding` mode gets `px-6 pt-6 pb-3` so it aligns with row content
- Auth form card: wraps `WDiv` + `WText` title + child, reusable across login/register/forgot/reset
- Team selector: dropdown built from `MagicStarter.manager.teamResolver` callbacks
- Notification dropdown: `StreamBuilder<List<DatabaseNotification>>` for real-time unread badge
- Timezone select: debounced async API search via `Http.get('/timezones')` — NOT local data
- Two-factor modal: multi-step wizard (enable → QR code → OTP confirm → recovery codes)
- Social divider: `WDiv` + `WText('or')` centered — used between form and social login buttons
- Page header: `WDiv` with `flex-col sm:flex-row` responsive layout, `border-b` separator, required `title`, optional `subtitle` (`String?`), optional `leading` widget (e.g. back button), optional `actions` (`List<Widget>?`) — rendered in a trailing `flex flex-row gap-2` row only when non-empty
- User profile dropdown: `PopupMenuButton` with avatar, name, role — navigates to profile/logout
- User profile dropdown avatar: uses `MagicStarter.navigationTheme.dropdownAvatarClassName` for the trigger avatar background — override via `MagicStarter.useNavigationTheme()`
- Confirm dialog: `MagicStarterConfirmDialog` with `static Future<bool> show(BuildContext context, {required String title, String? description, String? confirmLabel, String? cancelLabel, ConfirmDialogVariant variant, Future<void> Function()? onConfirm})`; variant enum `ConfirmDialogVariant.primary` (default), `.danger`, `.warning` — controls confirm button styling
- Confirm dialog variant usage: `ConfirmDialogVariant.danger` for destructive actions (delete team, revoke session), `.warning` for caution (leave team), `.primary` for neutral confirmations
- Modal theme consumption: all dialogs (ConfirmDialog, PasswordConfirmDialog, TwoFactorModal) read tokens from `MagicStarter.manager.modalTheme` at build time — never hardcode dialog classNames; use theme fields (titleClassName, primaryButtonClassName, dangerButtonClassName, etc.)
- Dialog shell: `MagicStarterDialogShell` is internal-only (NOT exported from barrel) — sticky header/footer with scrollable body; uses Material Dialog shell + Wind UI content; all exported dialogs compose on top of it
- Wind UI exclusively — no Material widgets except `Icons.*` for icon references and `Dialog` shell in `MagicStarterDialogShell`
- Dark mode: always pair light/dark classes: `bg-white dark:bg-gray-800`
