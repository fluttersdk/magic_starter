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

    if (paginator != null && paginator.isEmpty && emptyState != null) {
      return emptyState!;
    }

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
              child: MagicPaginatedListView<E>(
                paginator: paginator,
                itemBuilder: (_, E row, _) => _buildRow(row),
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
            WText(
              column.label,
              className: column.width == null
                  ? dataTableHeaderCellClassName()
                  : dataTableHeaderCellFixedClassName(),
            ),
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
            WDiv(
              className: column.width == null
                  ? dataTableCellClassName()
                  : dataTableCellFixedClassName(),
              child: column.cell(row),
            ),
          ),
      ],
    );
  }

  /// Puts [child] on [column]'s track.
  ///
  /// A flexing column is already `flex-1` through its own className, so it needs
  /// no wrapper; a fixed one gets a `w-*` box that does not resize with its
  /// content, which is the whole reason a numeric column asks for one.
  Widget _track(MSDataColumn<E> column, Widget child) {
    final double? width = column.width;
    if (width == null) return child;

    return WDiv(
      className: column.alignEnd
          ? 'w-[${width.toInt()}px] shrink-0 flex flex-row justify-end'
          : 'w-[${width.toInt()}px] shrink-0',
      child: child,
    );
  }
}
