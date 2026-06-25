// EmptyState has no variant axes — its layout is static. This file maintains
// the canonical 4-file atomic-component shape.

/// Root container className for [EmptyState].
String emptyStateRootClassName() =>
    'flex flex-col items-center justify-center gap-4 py-12 px-6 text-center';

/// Icon wrapper className.
String emptyStateIconWrapClassName() =>
    'w-16 h-16 rounded-full bg-surface-container flex items-center justify-center';

/// Icon className.
String emptyStateIconClassName() => 'text-4xl text-fg-muted';

/// Title className.
String emptyStateTitleClassName() =>
    'text-base font-semibold text-fg';

/// Description className.
String emptyStateDescriptionClassName() => 'text-sm text-fg-muted max-w-xs';
