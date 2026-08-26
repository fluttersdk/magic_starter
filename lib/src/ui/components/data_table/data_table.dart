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
class MSDataTable<E> extends StatelessWidget {
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

  /// Rendered instead of the table once a first page has arrived empty.
  final Widget? emptyState;

  /// Label for the tail row shown while the next page is in flight.
  ///
  /// Already translated, for the reason [MSDataColumn.label] gives. Null renders
  /// no footer.
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final MagicPaginator<E>? paginator = this.paginator;

    return WDiv(
      className: dataTableScrollClassName(),
      child: WDiv(
        className: dataTableRootClassName(),
        children: [
          _buildHeader(),
          if (paginator == null)
            for (final E row in rows) _buildRow(row)
          else
            WDiv(
              className: dataTableBodyClassName(bodyHeight.toInt()),
              // `emptyState` is forwarded rather than checked here, because this
              // widget is stateless and does not listen: reading
              // `paginator.isEmpty` at build time only worked when the caller
              // had already awaited the first page, and the ordinary order
              // (build the view, let the controller load) left a bare header
              // forever. The list view listens, so the state belongs to it.
              child: MagicPaginatedListView<E>(
                paginator: paginator,
                itemBuilder: (_, E row, _) => _buildRow(row),
                emptyState: emptyState,
                loadingFooter: loadingLabel == null
                    ? null
                    : WDiv(
                        className: dataTableLoadingFooterClassName(),
                        child: WText(
                          loadingLabel!,
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
        for (final MSDataColumn<E> column in columns)
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
        for (final MSDataColumn<E> column in columns)
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
