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
- Wind UI exclusively — no Material widgets except `Icons.*` for icon references
- Dark mode: always pair light/dark classes: `bg-white dark:bg-gray-800`
