import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'data_table.recipe.dart';

/// One column of an [MSDataTable].
///
/// A column is DATA, not a style variant: the caller says what the header reads
/// and how one row becomes a cell, and the table owns the tracks, the dividers
/// and the header styling. That split is why this component has no variant axis
/// to switch on.
@immutable
class MSDataColumn<E> {
  /// Creates a column.
  ///
  /// [width] puts the column on a fixed track instead of letting it flex, which
  /// is what a numeric column wants: a right-aligned amount or a status code
  /// lines up down the page only if its track does not resize with its content.
  const MSDataColumn({
    required this.label,
    required this.cell,
    this.width,
    this.alignEnd = false,
  });

  /// The header label, already translated.
  ///
  /// A key would make this component decide the caller's i18n namespace, and
  /// half the callers render a label that is not a key at all (a currency code,
  /// a region name).
  final String label;

  /// Builds this column's cell for one row.
  final Widget Function(E row) cell;

  /// Fixed track width in logical pixels, or null to flex.
  final double? width;

  /// Whether the column's content is right-aligned.
  final bool alignEnd;
}

/// **A table with a header and a body of rows.**
///
/// The shared shape behind the account surface's list screens (a billing
/// history, a session list, a team roster) and any consumer table that wants the
/// same tracks and dividers. Columns are passed in, so the component carries the
/// layout and the caller carries the vocabulary.
///
/// ## Two modes, and when each is right
///
/// The default constructor renders one row per element, eagerly, which is right
/// for a short and complete list. [MSDataTable.paginated] hands the body to
/// `MagicPaginatedListView` inside a bounded box instead, so a long collection
/// costs the viewport rather than the result and reaching the tail asks the
/// paginator for the next page.
///
/// The HEADER stays outside the scrolling body in both modes: a header that
/// scrolls away with its rows is not a table header.
///
/// ### Example Usage:
///
/// ```dart
/// MSDataTable<Invoice>.paginated(
///   paginator: controller.invoices,
///   columns: [
///     MSDataColumn(
///       label: trans('magic_starter.billing.invoice_date'),
///       cell: (invoice) => WText(formatDate(invoice.createdAt)),
///     ),
///     MSDataColumn(
///       label: trans('magic_starter.billing.invoice_total'),
///       width: 120,
///       alignEnd: true,
///       cell: (invoice) => WText(invoice.total),
///     ),
///   ],
/// )
/// ```
@immutable
class MSDataTable<E> extends StatefulWidget {
  /// Creates a table that renders [rows] eagerly.
  const MSDataTable({super.key, required this.columns, required this.rows})
    : paginator = null,
      bodyHeight = 0,
      emptyState = null,
      loadingLabel = null;

  /// Creates a table that pages [paginator] as the reader scrolls.
  const MSDataTable.paginated({
    super.key,
    required this.columns,
    required MagicPaginator<E> this.paginator,
    this.bodyHeight = 420,
    this.emptyState,
    this.loadingLabel,
  }) : rows = const <Never>[];

  /// The columns, left to right.
  final List<MSDataColumn<E>> columns;

  /// The rows, in the eager mode.
  final List<E> rows;

  /// The collection to page, in the paginated mode.
  final MagicPaginator<E>? paginator;

  /// Height of the scrolling body, in the paginated mode.
  ///
  /// A `ListView` needs a bound and this is it. Unbounded throws, and
  /// `shrinkWrap: true` would "fix" that by measuring every row, which builds
  /// all of them and saves nothing.
  final double bodyHeight;

  /// Rendered in place of the ROWS once a first page has arrived empty.
  ///
  /// The header stays: the columns are context for what would have been there,
  /// and the row box is dropped, so an empty table is its own height rather than
  /// [bodyHeight] of mostly blank space.
  final Widget? emptyState;

  /// Label for the tail row shown while the next page is in flight.
  ///
  /// Already translated, for the reason [MSDataColumn.label] gives. Null renders
  /// no footer.
  final String? loadingLabel;

  @override
  State<MSDataTable<E>> createState() => _MSDataTableState<E>();
}

/// Listens to the paginator, which is what lets the empty state work in both
/// orderings and lets it render WITHOUT the row box.
///
/// A stateless version read `paginator.isEmpty` once at build time, so an empty
/// state only appeared when the caller had already awaited the first page.
/// Forwarding the state into the lazy list fixed that ordering but put it inside
/// the `h-[bodyHeight]px` box, so an empty history reserved 420px around one
/// sentence. Listening answers both: the box is for rows, and with no rows there
/// is nothing to bound.
class _MSDataTableState<E> extends State<MSDataTable<E>> {
  @override
  void initState() {
    super.initState();
    widget.paginator?.addListener(_onPaginatorChanged);
  }

  @override
  void didUpdateWidget(MSDataTable<E> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.paginator, widget.paginator)) {
      oldWidget.paginator?.removeListener(_onPaginatorChanged);
      widget.paginator?.addListener(_onPaginatorChanged);
    }
  }

  @override
  void dispose() {
    widget.paginator?.removeListener(_onPaginatorChanged);
    super.dispose();
  }

  void _onPaginatorChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final MagicPaginator<E>? paginator = widget.paginator;
    final Widget? emptyState = widget.emptyState;
    final bool isEmpty =
        paginator != null && paginator.isEmpty && emptyState != null;

    return WDiv(
      className: dataTableScrollClassName(),
      child: WDiv(
        className: dataTableRootClassName(),
        children: [
          _buildHeader(),
          if (paginator == null)
            for (final E row in widget.rows) _buildRow(row)
          else if (isEmpty)
            // No row box: it exists to bound a list, and there is no list.
            emptyState
          else
            WDiv(
              className: dataTableBodyClassName(widget.bodyHeight.toInt()),
              child: MagicPaginatedListView<E>(
                paginator: paginator,
                itemBuilder: (_, E row, _) => _buildRow(row),
                loadingFooter: widget.loadingLabel == null
                    ? null
                    : WDiv(
                        className: dataTableLoadingFooterClassName(),
                        child: WText(
                          widget.loadingLabel!,
                          className: dataTableLoadingLabelClassName(),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Private builders
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return WDiv(
      className: dataTableHeaderClassName(),
      children: [
        for (final MSDataColumn<E> column in widget.columns)
          _track(
            column,
            WText(column.label, className: dataTableHeaderCellClassName()),
          ),
      ],
    );
  }

  Widget _buildRow(E row) {
    return WDiv(
      className: dataTableRowClassName(),
      children: [
        for (final MSDataColumn<E> column in widget.columns)
          _track(
            column,
            WDiv(className: dataTableCellClassName(), child: column.cell(row)),
          ),
      ],
    );
  }

  /// Puts [child] on [column]'s track.
  ///
  /// Always wraps, for both the flexing and the fixed case. The track used to
  /// live on the cell's own className as a `flex-1`, which meant a flexing
  /// column had no wrapper to align inside and `alignEnd` was a silent no-op on
  /// it: the cell rendered at the start of its track with no error and no hint.
  Widget _track(MSDataColumn<E> column, Widget child) {
    return WDiv(
      className: dataTableTrackClassName(
        column.width?.toInt(),
        alignEnd: column.alignEnd,
      ),
      child: child,
    );
  }
}
