// Navbar has no variant axes — its structure is responsive and handled by
// className tokens. This file maintains the canonical 4-file shape.

/// Root container className for [Navbar].
String navbarRootClassName() =>
    'w-full flex flex-row items-center justify-between '
    'bg-surface border-b border-color-border px-4 h-14';

/// Brand slot container className.
String navbarBrandClassName() => 'flex-shrink-0';

/// Children (nav links) container className.
String navbarChildrenClassName() =>
    'hidden sm:flex flex-row items-center gap-2 flex-1 px-4';

/// Trailing slot container className.
String navbarTrailingClassName() =>
    'flex flex-row items-center gap-2 flex-shrink-0';
