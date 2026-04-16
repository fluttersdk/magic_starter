import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Navigation theme
// ---------------------------------------------------------------------------

/// Theme configuration for navigation colors and styling.
///
/// Allows consumer apps to override the default Wind UI `text-primary` tokens
/// with custom colors, gradients, or light/dark mode-independent class names.
///
/// All fields are optional; defaults preserve the current behavior with no
/// breaking changes.
///
/// ### Example
/// ```dart
/// MagicStarter.useNavigationTheme(
///   MagicStarterNavigationTheme(
///     activeItemClassName:
///         'active:text-amber-500 active:bg-amber-500/10 dark:active:text-amber-400 dark:active:bg-amber-400/10',
///     brandClassName:
///         'text-lg font-bold bg-gradient-to-r from-primary-400 to-accent-500 bg-clip-text text-transparent',
///     bottomNavActiveClassName: 'active:text-amber-500 dark:active:text-amber-400',
///     avatarClassName: 'bg-amber-500/10 dark:bg-amber-400/10',
///     avatarTextClassName: 'text-sm font-bold text-amber-600 dark:text-amber-400',
///   ),
/// );
/// ```
class MagicStarterNavigationTheme {
  /// Active sidebar/drawer nav item className tokens.
  ///
  /// Applied to the `WDiv` that has `states: {if (isActive) 'active'}`. Each
  /// token must include the `active:` prefix so the Wind CSS state system
  /// activates it only when the item is selected.
  ///
  /// Defaults to `'active:text-primary active:bg-primary/10 dark:active:bg-primary/10'`.
  final String activeItemClassName;

  /// Hover className for sidebar/drawer nav items.
  ///
  /// Defaults to `'hover:bg-gray-100 dark:hover:bg-gray-800'`.
  final String hoverItemClassName;

  /// Brand/logo text className. Used when [brandBuilder] is `null`.
  ///
  /// Supports gradient text by combining Tailwind-like tokens, e.g.
  /// `'text-lg font-bold bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent'`.
  ///
  /// Defaults to `'text-lg font-bold text-primary'`.
  final String brandClassName;

  /// Custom brand/logo widget builder.
  ///
  /// When set, renders this widget instead of the default app name text.
  /// Receives the current [BuildContext] and should return any widget
  /// (image, SVG, styled text, etc.). When `null`, falls back to a [WText]
  /// using [brandClassName].
  ///
  /// ```dart
  /// brandBuilder: (context) => Image.asset('assets/logo.png', height: 28),
  /// ```
  final Widget Function(BuildContext context)? brandBuilder;

  /// Active bottom navigation item className tokens.
  ///
  /// Applied to both the icon and label [WIcon]/[WText] widgets that have
  /// `states: isActive ? {'active'} : {}`. Each token must include the
  /// `active:` prefix.
  ///
  /// Defaults to `'active:text-primary'`.
  final String bottomNavActiveClassName;

  /// Avatar background className for the sidebar user menu.
  ///
  /// Defaults to `'bg-primary/10 dark:bg-primary/10'`.
  final String avatarClassName;

  /// Avatar text/initial color className for the sidebar user menu.
  ///
  /// Defaults to `'text-sm font-bold text-primary'`.
  final String avatarTextClassName;

  /// Profile dropdown trigger avatar background className.
  ///
  /// Used for the default circular avatar rendered in
  /// [MagicStarterUserProfileDropdown] when no custom [triggerBuilder] is set.
  ///
  /// Defaults to `'bg-gradient-to-tr from-primary to-gray-200'`.
  final String dropdownAvatarClassName;

  const MagicStarterNavigationTheme({
    this.activeItemClassName =
        'active:text-primary active:bg-primary/10 dark:active:bg-primary/10',
    this.hoverItemClassName = 'hover:bg-gray-100 dark:hover:bg-gray-800',
    this.brandClassName = 'text-lg font-bold text-primary',
    this.brandBuilder,
    this.bottomNavActiveClassName = 'active:text-primary',
    this.avatarClassName = 'bg-primary/10 dark:bg-primary/10',
    this.avatarTextClassName = 'text-sm font-bold text-primary',
    this.dropdownAvatarClassName = 'bg-gradient-to-tr from-primary to-gray-200',
  });
}

// ---------------------------------------------------------------------------
// Modal theme
// ---------------------------------------------------------------------------

/// Theme configuration for modal/dialog colors and styling.
///
/// Allows consumer apps to override the default Wind UI class names used for
/// modal containers, headers, bodies, footers, buttons, inputs, and typography.
///
/// All fields are optional; defaults preserve a sensible dark-mode-aware style
/// with no breaking changes.
///
/// ### Example
/// ```dart
/// MagicStarter.useModalTheme(
///   MagicStarterModalTheme(
///     containerClassName: 'bg-zinc-900 rounded-2xl border border-zinc-700',
///     primaryButtonClassName:
///         'px-6 py-3 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white font-semibold',
///     maxWidth: 560.0,
///   ),
/// );
/// ```
class MagicStarterModalTheme {
  /// Container/dialog background and border-radius className.
  ///
  /// Defaults to `'bg-white dark:bg-gray-800 rounded-2xl'`.
  final String containerClassName;

  /// Header section className (wraps title + description).
  ///
  /// Defaults to `'px-6 pt-6 pb-4'`.
  final String headerClassName;

  /// Body section className (main content area).
  ///
  /// Defaults to `'px-6 pb-4'`.
  final String bodyClassName;

  /// Footer section className (action buttons row).
  ///
  /// Defaults to `'px-6 py-4 bg-gray-50 dark:bg-gray-800/50'`.
  final String footerClassName;

  /// Title text className.
  ///
  /// Defaults to `'text-xl font-semibold text-gray-900 dark:text-white mb-2'`.
  final String titleClassName;

  /// Description/subtitle text className.
  ///
  /// Defaults to `'text-sm text-gray-600 dark:text-gray-400'`.
  final String descriptionClassName;

  /// Primary action button className.
  ///
  /// Defaults to
  /// `'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium'`.
  final String primaryButtonClassName;

  /// Secondary/cancel action button className.
  ///
  /// Defaults to
  /// `'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium'`.
  final String secondaryButtonClassName;

  /// Destructive/danger action button className.
  ///
  /// Defaults to
  /// `'px-4 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white text-sm font-medium'`.
  final String dangerButtonClassName;

  /// Warning action button className.
  ///
  /// Defaults to
  /// `'px-4 py-2 rounded-lg bg-amber-500 hover:bg-amber-600 text-white text-sm font-medium'`.
  final String warningButtonClassName;

  /// Inline error message text className.
  ///
  /// Defaults to `'text-sm text-red-600 dark:text-red-400'`.
  final String errorClassName;

  /// Text input field className.
  ///
  /// Defaults to
  /// `'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary'`.
  final String inputClassName;

  /// Maximum width of the modal dialog in logical pixels.
  ///
  /// Defaults to `448.0`.
  final double maxWidth;

  const MagicStarterModalTheme({
    this.containerClassName = 'bg-white dark:bg-gray-800 rounded-2xl',
    this.headerClassName = 'px-6 pt-6 pb-4',
    this.bodyClassName = 'px-6 pb-4',
    this.footerClassName = 'px-6 py-4 bg-gray-50 dark:bg-gray-800/50',
    this.titleClassName =
        'text-xl font-semibold text-gray-900 dark:text-white mb-2',
    this.descriptionClassName = 'text-sm text-gray-600 dark:text-gray-400',
    this.primaryButtonClassName =
        'px-4 py-2 rounded-lg bg-primary hover:bg-primary/80 text-white text-sm font-medium',
    this.secondaryButtonClassName =
        'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm font-medium',
    this.dangerButtonClassName =
        'px-4 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white text-sm font-medium',
    this.warningButtonClassName =
        'px-4 py-2 rounded-lg bg-amber-500 hover:bg-amber-600 text-white text-sm font-medium',
    this.errorClassName = 'text-sm text-red-600 dark:text-red-400',
    this.inputClassName =
        'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary',
    this.maxWidth = 448.0,
  });
}

// ---------------------------------------------------------------------------
// Form theme
// ---------------------------------------------------------------------------

/// Theme configuration for form input styling across all Magic Starter views.
///
/// Controls Wind UI class names for inputs, labels, buttons, links, and error
/// messages used in auth forms, profile forms, and team forms.
///
/// All fields are optional; defaults preserve the current dark-mode-aware style.
///
/// ### Example
/// ```dart
/// MagicStarterFormTheme(
///   inputClassName: 'w-full px-4 py-4 rounded-xl bg-zinc-900 border border-zinc-700 text-white',
///   primaryButtonClassName: 'w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 rounded-xl font-semibold',
/// )
/// ```
class MagicStarterFormTheme {
  /// Text input field className.
  ///
  /// Defaults to
  /// `'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500'`.
  final String inputClassName;

  /// Label text className displayed above form inputs.
  ///
  /// Defaults to `'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1'`.
  final String labelClassName;

  /// Inline validation error text className.
  ///
  /// Defaults to `'text-sm text-red-600 dark:text-red-400'`.
  final String errorClassName;

  /// Placeholder text className inside inputs.
  ///
  /// Defaults to `'text-gray-400 dark:text-gray-500'`.
  final String placeholderClassName;

  /// Primary submit button className (e.g. "Sign In", "Save").
  ///
  /// Defaults to
  /// `'w-full bg-primary hover:bg-primary/80 text-white text-base font-semibold py-3 rounded-lg'`.
  final String primaryButtonClassName;

  /// Secondary/outline button className (e.g. social login, cancel).
  ///
  /// Defaults to
  /// `'w-full bg-transparent border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 py-3 rounded-lg text-sm font-medium'`.
  final String secondaryButtonClassName;

  /// Inline link text className (e.g. "Forgot password?").
  ///
  /// Defaults to `'text-sm font-medium text-primary'`.
  final String linkClassName;

  /// Checkbox label text className (e.g. "Remember me").
  ///
  /// Defaults to
  /// `'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200 ml-1'`.
  final String checkboxLabelClassName;

  const MagicStarterFormTheme({
    this.inputClassName =
        'w-full px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white focus:border-primary error:border-red-500',
    this.labelClassName =
        'text-sm font-medium text-gray-700 dark:text-gray-300 mb-1',
    this.errorClassName = 'text-sm text-red-600 dark:text-red-400',
    this.placeholderClassName = 'text-gray-400 dark:text-gray-500',
    this.primaryButtonClassName =
        'w-full bg-primary hover:bg-primary/80 text-white text-base font-semibold py-3 rounded-lg',
    this.secondaryButtonClassName =
        'w-full bg-transparent border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 py-3 rounded-lg text-sm font-medium',
    this.linkClassName = 'text-sm font-medium text-primary',
    this.checkboxLabelClassName =
        'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200 ml-1',
  });
}

// ---------------------------------------------------------------------------
// Card theme
// ---------------------------------------------------------------------------

/// Theme configuration for [MagicStarterCard] widget styling.
///
/// Controls Wind UI class names for card variants (surface, inset, elevated),
/// title text, border radius, and padding.
///
/// All fields are optional; defaults preserve the current dark-mode-aware style.
///
/// ### Example
/// ```dart
/// MagicStarterCardTheme(
///   surfaceClassName: 'bg-zinc-900 border border-zinc-700',
///   borderRadius: 'rounded-xl',
/// )
/// ```
class MagicStarterCardTheme {
  /// Surface variant card className (`CardVariant.surface`).
  ///
  /// Defaults to
  /// `'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700'`.
  final String surfaceClassName;

  /// Inset variant card className (`CardVariant.inset`).
  ///
  /// Defaults to
  /// `'bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700'`.
  final String insetClassName;

  /// Elevated variant card className (`CardVariant.elevated`).
  ///
  /// Defaults to `'bg-white dark:bg-gray-800 shadow-md'`.
  final String elevatedClassName;

  /// Card title text className.
  ///
  /// Defaults to `'text-lg font-semibold text-gray-900 dark:text-white'`.
  final String titleClassName;

  /// Container className for title when the card is in `noPadding` mode.
  ///
  /// Defaults to `'px-6 pt-6 pb-3'`.
  final String titleNoPaddingContainerClassName;

  /// Border radius className applied to the card root.
  ///
  /// Defaults to `'rounded-2xl'`.
  final String borderRadius;

  /// Content padding className for the card body.
  ///
  /// Defaults to `'p-6'`.
  final String paddingClassName;

  const MagicStarterCardTheme({
    this.surfaceClassName =
        'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700',
    this.insetClassName =
        'bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700',
    this.elevatedClassName = 'bg-white dark:bg-gray-800 shadow-md',
    this.titleClassName = 'text-lg font-semibold text-gray-900 dark:text-white',
    this.titleNoPaddingContainerClassName = 'px-6 pt-6 pb-3',
    this.borderRadius = 'rounded-2xl',
    this.paddingClassName = 'p-6',
  });
}

// ---------------------------------------------------------------------------
// Page header theme
// ---------------------------------------------------------------------------

/// Theme configuration for [MagicStarterPageHeader] widget styling.
///
/// Controls Wind UI class names for the header container, title, subtitle,
/// and action button row.
///
/// All fields are optional; defaults preserve the current responsive layout.
///
/// ### Example
/// ```dart
/// MagicStarterPageHeaderTheme(
///   titleClassName: 'text-3xl font-black text-white',
/// )
/// ```
class MagicStarterPageHeaderTheme {
  /// Default container className (stacked on mobile, row on desktop).
  ///
  /// Defaults to
  /// `'w-full flex flex-col sm:flex-row items-start sm:items-center sm:justify-between gap-4 p-2 lg:p-4 border-b border-gray-200 dark:border-gray-700'`.
  final String containerClassName;

  /// Container className when `inlineActions` mode is active.
  ///
  /// Defaults to
  /// `'w-full flex flex-row items-center justify-between gap-4 p-2 lg:p-4 border-b border-gray-200 dark:border-gray-700'`.
  final String containerInlineClassName;

  /// Title text className.
  ///
  /// Defaults to `'text-2xl font-bold text-gray-900 dark:text-white truncate'`.
  final String titleClassName;

  /// Subtitle text className.
  ///
  /// Defaults to `'text-sm text-gray-600 dark:text-gray-400 truncate'`.
  final String subtitleClassName;

  /// Action buttons container className.
  ///
  /// Defaults to `'flex flex-row items-center gap-2'`.
  final String actionContainerClassName;

  const MagicStarterPageHeaderTheme({
    this.containerClassName =
        'w-full flex flex-col sm:flex-row items-start sm:items-center sm:justify-between gap-4 p-2 lg:p-4 border-b border-gray-200 dark:border-gray-700',
    this.containerInlineClassName =
        'w-full flex flex-row items-center justify-between gap-4 p-2 lg:p-4 border-b border-gray-200 dark:border-gray-700',
    this.titleClassName =
        'text-2xl font-bold text-gray-900 dark:text-white truncate',
    this.subtitleClassName =
        'text-sm text-gray-600 dark:text-gray-400 truncate',
    this.actionContainerClassName = 'flex flex-row items-center gap-2',
  });
}

// ---------------------------------------------------------------------------
// Layout theme
// ---------------------------------------------------------------------------

/// Theme configuration for the app layout shell ([MagicStarterAppLayout]).
///
/// Controls sidebar, header, content background, drawer, brand bar, and bottom
/// navigation styling. Numeric fields control physical dimensions (logical
/// pixels); string fields are Wind UI class names or `wColor()` color keys.
///
/// All fields are optional; defaults preserve the current layout appearance.
///
/// ### Example
/// ```dart
/// MagicStarterLayoutTheme(
///   sidebarWidth: 280,
///   sidebarClassName: 'h-full flex flex-col bg-zinc-900 border-r border-zinc-700',
/// )
/// ```
class MagicStarterLayoutTheme {
  /// Sidebar container className.
  ///
  /// Defaults to
  /// `'h-full flex flex-col bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-700'`.
  final String sidebarClassName;

  /// Sidebar width in logical pixels.
  ///
  /// Defaults to `256`.
  final double sidebarWidth;

  /// Top header bar className.
  ///
  /// Defaults to
  /// `'h-16 px-4 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between'`.
  final String headerClassName;

  /// Top header bar height in logical pixels.
  ///
  /// Defaults to `64`.
  final double headerHeight;

  /// Light-mode content area background color key for `wColor()`.
  ///
  /// Defaults to `'gray'`.
  final String contentBackgroundLightColor;

  /// Light-mode content area background shade for `wColor()`.
  ///
  /// Defaults to `50`.
  final int contentBackgroundLightShade;

  /// Dark-mode content area background color key for `wColor()`.
  ///
  /// Defaults to `'gray'`.
  final String contentBackgroundDarkColor;

  /// Dark-mode content area background shade for `wColor()`.
  ///
  /// Defaults to `950`.
  final int contentBackgroundDarkShade;

  /// Light-mode drawer background color key for `wColor()`.
  ///
  /// Defaults to `'white'`.
  final String drawerBackgroundLightColor;

  /// Light-mode drawer background shade for `wColor()`.
  ///
  /// Defaults to `50`. Ignored when the color is `'white'` (non-shade color).
  final int drawerBackgroundLightShade;

  /// Dark-mode drawer background color key for `wColor()`.
  ///
  /// Defaults to `'gray'`.
  final String drawerBackgroundDarkColor;

  /// Dark-mode drawer background shade for `wColor()`.
  ///
  /// Defaults to `900`.
  final int drawerBackgroundDarkShade;

  /// Brand bar container className (top of sidebar).
  ///
  /// Defaults to
  /// `'h-14 px-5 flex items-center justify-between border-b border-gray-100 dark:border-gray-800'`.
  final String brandBarClassName;

  /// Bottom navigation bar className (mobile only).
  ///
  /// Defaults to `''` (empty, no default override).
  final String bottomNavClassName;

  const MagicStarterLayoutTheme({
    this.sidebarClassName =
        'h-full flex flex-col bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-700',
    this.sidebarWidth = 256,
    this.headerClassName =
        'h-16 px-4 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between',
    this.headerHeight = 64,
    this.contentBackgroundLightColor = 'gray',
    this.contentBackgroundLightShade = 50,
    this.contentBackgroundDarkColor = 'gray',
    this.contentBackgroundDarkShade = 950,
    this.drawerBackgroundLightColor = 'white',
    this.drawerBackgroundLightShade = 50,
    this.drawerBackgroundDarkColor = 'gray',
    this.drawerBackgroundDarkShade = 900,
    this.brandBarClassName =
        'h-14 px-5 flex items-center justify-between border-b border-gray-100 dark:border-gray-800',
    this.bottomNavClassName = '',
  });
}

// ---------------------------------------------------------------------------
// Auth theme
// ---------------------------------------------------------------------------

/// Theme configuration for authentication pages (login, register, forgot
/// password, reset password) and their shared widgets.
///
/// Controls Wind UI class names for the auth form card, title, error banner,
/// theme toggle, social divider, and guest/registration links.
///
/// All fields are optional; defaults preserve the current dark-mode-aware style.
///
/// ### Example
/// ```dart
/// MagicStarterAuthTheme(
///   cardClassName: 'rounded-3xl bg-zinc-900 border border-zinc-700 p-8 flex flex-col items-center',
///   titleClassName: 'text-3xl font-black text-white text-center',
/// )
/// ```
class MagicStarterAuthTheme {
  /// Auth form card container className.
  ///
  /// Defaults to
  /// `'rounded-2xl bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 p-4 lg:p-8 flex flex-col items-center'`.
  final String cardClassName;

  /// Auth page title text className.
  ///
  /// Defaults to `'text-2xl font-bold text-gray-900 dark:text-white text-center'`.
  final String titleClassName;

  /// Auth page subtitle text className.
  ///
  /// Defaults to `'text-sm text-gray-600 dark:text-gray-400 text-center'`.
  final String subtitleClassName;

  /// Error banner className displayed at the top of auth forms.
  ///
  /// Defaults to
  /// `'p-3 rounded-xl bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm text-center'`.
  final String errorBannerClassName;

  /// Theme toggle button className (light/dark mode switcher on auth pages).
  ///
  /// Defaults to
  /// `'p-2 rounded-lg duration-150 bg-transparent hover:bg-gray-100 dark:hover:bg-gray-800 flex items-center justify-center'`.
  final String themeToggleClassName;

  /// Theme toggle icon className.
  ///
  /// Defaults to `'text-2xl text-gray-500 dark:text-gray-400'`.
  final String themeToggleIconClassName;

  /// Social divider container className (the "or" separator row).
  ///
  /// Defaults to `'flex flex-row items-center my-4'`.
  final String socialDividerClassName;

  /// Social divider horizontal line className.
  ///
  /// Defaults to `'flex-1 h-[1px] bg-gray-200 dark:bg-gray-700'`.
  final String socialDividerLineClassName;

  /// Social divider "or" text className.
  ///
  /// Defaults to `'text-sm text-gray-500 dark:text-gray-400'`.
  final String socialDividerTextClassName;

  /// Guest action button className (e.g. "Continue as Guest").
  ///
  /// Defaults to
  /// `'w-full bg-transparent border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 py-3 rounded-lg text-sm font-medium'`.
  final String guestButtonClassName;

  /// Registration link container text className (e.g. "Don't have an account?").
  ///
  /// Defaults to `'text-sm text-gray-500 dark:text-gray-400'`.
  final String registrationLinkClassName;

  /// Registration link action text className (e.g. "Sign up").
  ///
  /// Defaults to `'text-sm font-semibold text-primary'`.
  final String registrationLinkTextClassName;

  const MagicStarterAuthTheme({
    this.cardClassName =
        'rounded-2xl bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 p-4 lg:p-8 flex flex-col items-center',
    this.titleClassName =
        'text-2xl font-bold text-gray-900 dark:text-white text-center',
    this.subtitleClassName =
        'text-sm text-gray-600 dark:text-gray-400 text-center',
    this.errorBannerClassName =
        'p-3 rounded-xl bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm text-center',
    this.themeToggleClassName =
        'p-2 rounded-lg duration-150 bg-transparent hover:bg-gray-100 dark:hover:bg-gray-800 flex items-center justify-center',
    this.themeToggleIconClassName = 'text-2xl text-gray-500 dark:text-gray-400',
    this.socialDividerClassName = 'flex flex-row items-center my-4',
    this.socialDividerLineClassName =
        'flex-1 h-[1px] bg-gray-200 dark:bg-gray-700',
    this.socialDividerTextClassName =
        'text-sm text-gray-500 dark:text-gray-400',
    this.guestButtonClassName =
        'w-full bg-transparent border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 py-3 rounded-lg text-sm font-medium',
    this.registrationLinkClassName = 'text-sm text-gray-500 dark:text-gray-400',
    this.registrationLinkTextClassName = 'text-sm font-semibold text-primary',
  });
}

// ---------------------------------------------------------------------------
// Unified theme wrapper
// ---------------------------------------------------------------------------

/// Unified theme configuration that aggregates all Magic Starter sub-themes.
///
/// Provides a single entry point to configure navigation, modal, form, card,
/// page header, layout, and auth styling in one place. Each sub-theme defaults
/// to its standard configuration when omitted.
///
/// Use [copyWith] to create a modified copy with only the sub-themes you want
/// to override.
///
/// ### Example
/// ```dart
/// final theme = MagicStarterTheme(
///   form: MagicStarterFormTheme(
///     primaryButtonClassName: 'w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 rounded-xl',
///   ),
///   card: MagicStarterCardTheme(
///     borderRadius: 'rounded-xl',
///   ),
/// );
///
/// final updated = theme.copyWith(
///   auth: MagicStarterAuthTheme(titleClassName: 'text-3xl font-black text-white'),
/// );
/// ```
class MagicStarterTheme {
  /// Navigation/sidebar theme tokens.
  ///
  /// Defaults to `const MagicStarterNavigationTheme()`.
  final MagicStarterNavigationTheme navigation;

  /// Modal/dialog theme tokens.
  ///
  /// Defaults to `const MagicStarterModalTheme()`.
  final MagicStarterModalTheme modal;

  /// Form input and button theme tokens.
  ///
  /// Defaults to `const MagicStarterFormTheme()`.
  final MagicStarterFormTheme form;

  /// Card widget theme tokens.
  ///
  /// Defaults to `const MagicStarterCardTheme()`.
  final MagicStarterCardTheme card;

  /// Page header theme tokens.
  ///
  /// Defaults to `const MagicStarterPageHeaderTheme()`.
  final MagicStarterPageHeaderTheme pageHeader;

  /// Layout shell theme tokens.
  ///
  /// Defaults to `const MagicStarterLayoutTheme()`.
  final MagicStarterLayoutTheme layout;

  /// Auth page theme tokens.
  ///
  /// Defaults to `const MagicStarterAuthTheme()`.
  final MagicStarterAuthTheme auth;

  const MagicStarterTheme({
    this.navigation = const MagicStarterNavigationTheme(),
    this.modal = const MagicStarterModalTheme(),
    this.form = const MagicStarterFormTheme(),
    this.card = const MagicStarterCardTheme(),
    this.pageHeader = const MagicStarterPageHeaderTheme(),
    this.layout = const MagicStarterLayoutTheme(),
    this.auth = const MagicStarterAuthTheme(),
  });

  /// Returns a copy of this theme with the given sub-themes replaced.
  MagicStarterTheme copyWith({
    MagicStarterNavigationTheme? navigation,
    MagicStarterModalTheme? modal,
    MagicStarterFormTheme? form,
    MagicStarterCardTheme? card,
    MagicStarterPageHeaderTheme? pageHeader,
    MagicStarterLayoutTheme? layout,
    MagicStarterAuthTheme? auth,
  }) {
    return MagicStarterTheme(
      navigation: navigation ?? this.navigation,
      modal: modal ?? this.modal,
      form: form ?? this.form,
      card: card ?? this.card,
      pageHeader: pageHeader ?? this.pageHeader,
      layout: layout ?? this.layout,
      auth: auth ?? this.auth,
    );
  }
}
