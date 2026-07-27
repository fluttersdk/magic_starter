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
/// Uses the semantic `text-destructive` role rather than a raw palette pair, so
/// a consumer's own destructive colour drives it. The default expansion of that
/// role is the same `text-red-600 dark:text-red-400` this used to hardcode, so
/// an app with no override sees no change.
String errorStateIconClassName() => 'text-4xl text-destructive';

/// Title className (destructive tone).
String errorStateTitleClassName() => 'text-base font-semibold text-destructive';

/// Description className.
String errorStateDescriptionClassName() => 'text-sm text-fg-muted max-w-xs';
