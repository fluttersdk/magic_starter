/// Default className constants for the [DropdownMenu] component slots.
///
/// These constants centralise the default token classes so they can be
/// referenced in tests and overridden by callers without coupling to the
/// [DropdownMenu] widget internals.
const String kDropdownMenuPanelClassName =
    'min-w-40 bg-surface border border-color-border rounded-lg shadow-lg py-1 overflow-hidden';

const String kDropdownMenuItemClassName =
    'flex flex-row items-center gap-2 px-4 py-2 text-sm text-fg hover:bg-surface-container';

const String kDropdownMenuItemDisabledClassName =
    'flex flex-row items-center gap-2 px-4 py-2 text-sm text-fg-disabled';
