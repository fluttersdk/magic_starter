// MSDataTable has no variant axes: a table is a table. What varies is the
// COLUMNS, and those are data the caller passes rather than a style axis, so
// there is nothing for a WindRecipe's variant map to switch on. This file keeps
// the canonical 4-file atomic-component shape and holds the slot classNames.

/// Root className for [MSDataTable].
///
/// `min-w-*` lives on the table rather than on a column because a flex column
/// is a Flutter `Expanded`, which constrains its child tightly and IGNORES a
/// per-column minimum. The horizontal scroll wrapper outside it is what makes
/// that floor usable on a narrow screen.
String dataTableRootClassName() => 'flex flex-col w-full min-w-[560px]';

/// The horizontal scroll wrapper, so a wide table scrolls as one unit.
String dataTableScrollClassName() => 'overflow-x-auto';

/// Header row className.
String dataTableHeaderClassName() =>
    'flex flex-row items-center border-b border-color-border';

/// Body row className.
String dataTableRowClassName() =>
    'flex flex-row items-center border-b border-color-border';

/// Header cell className.
///
/// Carries no track: the track is the wrapper's job (see
/// [dataTableTrackClassName]), so alignment can be applied to a flexing column
/// as well as to a fixed one. It used to live here as a `flex-1`, which is why
/// `alignEnd` was silently ignored on every flexing column.
String dataTableHeaderCellClassName() =>
    'py-2 pr-3 text-xs font-medium uppercase tracking-wide text-fg-muted';

/// Body cell className. Carries no track, for the reason above.
String dataTableCellClassName() => 'py-3 pr-3 text-sm text-fg';

/// The className that puts a cell on its column's track.
///
/// [width] null means the column shares the remaining space (`flex-1`); a value
/// pins it to a track that does not resize with its content, which is what a
/// numeric column needs to line up down the page. [alignEnd] pushes the cell to
/// the end of whichever track it is on.
String dataTableTrackClassName(int? width, {required bool alignEnd}) {
  final String track = width == null ? 'flex-1' : 'w-[${width}px] shrink-0';

  return alignEnd ? '$track flex flex-row justify-end' : track;
}

/// Wrapper for the scrolling body in the paginated mode.
///
/// The height is applied by the widget, since it is a caller-tunable number
/// rather than a token.
String dataTableBodyClassName(int height) => 'h-[${height}px]';

/// ClassName for the tail row shown while the next page is in flight.
String dataTableLoadingFooterClassName() =>
    'flex flex-row items-center justify-center py-3';

/// ClassName for that row's label.
String dataTableLoadingLabelClassName() => 'text-xs text-fg-muted';
