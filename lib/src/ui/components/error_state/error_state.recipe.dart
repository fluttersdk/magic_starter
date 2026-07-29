// ErrorState has no variant axes — its layout is static. This file maintains
// the canonical 4-file atomic-component shape.

/// Root container className for [MSErrorState].
String errorStateRootClassName() =>
    'flex flex-col items-center justify-center gap-4 py-12 px-6 text-center';

/// Icon wrapper className (destructive tinted background).
String errorStateIconWrapClassName() =>
    'w-16 h-16 rounded-full bg-destructive-container flex items-center justify-center';

/// Icon className (destructive tone).
///
/// A raw palette pair on purpose. The alias contract ships `bg-destructive`,
/// `text-on-destructive` and `bg-destructive-container` but NO destructive TEXT
/// role, so `text-destructive` is not a key in
/// [MagicStarterTokens.defaultAliases] nor in the map `design:sync` generates
/// for a consumer. Wind's text parser claims a `text-<name>` token and then
/// resolves `destructive` to no colour, dropping the class silently, so writing
/// the semantic-looking token here would render no colour at all. See
/// `_windRoleFallbacks` in `lib/src/configuration/magic_starter_theme.dart`,
/// which encodes the same gap for the sub-themes.
String errorStateIconClassName() => 'text-4xl text-red-600 dark:text-red-400';

/// Title className (destructive tone).
///
/// Raw palette pair for the reason given on [errorStateIconClassName].
String errorStateTitleClassName() =>
    'text-base font-semibold text-red-700 dark:text-red-400';

/// Description className.
String errorStateDescriptionClassName() => 'text-sm text-fg-muted max-w-xs';
