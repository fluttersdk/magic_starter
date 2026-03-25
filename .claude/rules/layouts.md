---
path: "lib/src/ui/layouts/**/*.dart"
---

# UI Layouts

- Two layout shells: `MagicStarterAppLayout` (authenticated) and `MagicStarterGuestLayout` (auth/guest pages)
- Both registered in the view registry: `layout.app` and `layout.guest` — override via `MagicStarter.view.registerLayout()`
- `MagicStarterAppLayout` is responsive: sidebar + brand on desktop, drawer + bottom nav on mobile
- `MagicStarterAppLayout.refreshNotifier` — static `ValueNotifier<int>` that triggers full layout rebuilds; bumped automatically on auth state changes — never poke manually
- Navigation theme: all color/style tokens read from `MagicStarter.navigationTheme` at build time — never hardcode `text-primary` or `bg-primary/10` in layout code
  - `_navItem` uses `activeItemClassName` + `hoverItemClassName`
  - `_buildBrand` dispatches to `brandBuilder` when set, else `WText` with `brandClassName`
  - `_bottomNavItem` uses `bottomNavActiveClassName` on icon and label
  - `_buildUserMenu` avatar uses `avatarClassName` + `avatarTextClassName`
- Guest layout: minimal centered wrapper — constrains content to 480px max width with scroll
- Guest layout background: `wColor()` for theme-aware color — no hardcoded hex values
- Route transitions: guest routes use `RouteTransition.none` — no animation between auth screens
- Notification polling: `MagicStarterAppLayout` starts polling on mount when notifications feature is enabled — stop in `deactivate()` or `dispose()`
- Header builder: when `MagicStarter.manager.headerBuilder` is set, renders custom header instead of default — receives `(BuildContext context, bool isDesktop)`
- Logout: checks `MagicStarter.manager.onLogout` callback first — falls back to `MagicStarterAuthController.instance.logout()`
- Wind UI exclusively — no Material widgets in layout code; `Icons.*` only for icon data
