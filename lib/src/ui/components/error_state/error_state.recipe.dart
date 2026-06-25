// ErrorState has no variant axes — its layout is static. This file maintains
// the canonical 4-file atomic-component shape.

/// Root container className for [ErrorState].
String errorStateRootClassName() =>
    'flex flex-col items-center justify-center gap-4 py-12 px-6 text-center';

/// Icon wrapper className (destructive tinted background).
String errorStateIconWrapClassName() =>
    'w-16 h-16 rounded-full bg-destructive-container flex items-center justify-center';

/// Icon className (destructive tone).
String errorStateIconClassName() => 'text-4xl text-red-600 dark:text-red-400';

/// Title className (destructive tone).
String errorStateTitleClassName() =>
    'text-base font-semibold text-red-700 dark:text-red-400';

/// Description className.
String errorStateDescriptionClassName() => 'text-sm text-fg-muted max-w-xs';
