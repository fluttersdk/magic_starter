import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'data_table.dart';

/// One row of the preview's fixture.
class _PreviewInvoice {
  const _PreviewInvoice(this.date, this.total, this.status);

  final String date;
  final String total;
  final String status;
}

/// Static preview for [MSDataTable].
///
/// Renders the eager mode only. The paginated mode needs a live
/// [MagicPaginator], and a catalog entry that fires real requests would make the
/// preview depend on a signed-in session and a reachable backend; the widget
/// tests cover that mode instead. One preview class per file.
class DataTablePreview extends StatelessWidget {
  const DataTablePreview({super.key});

  static const List<_PreviewInvoice> _rows = <_PreviewInvoice>[
    _PreviewInvoice('12 Aug 2026', '\$29.00', 'Paid'),
    _PreviewInvoice('12 Jul 2026', '\$29.00', 'Paid'),
    _PreviewInvoice('12 Jun 2026', '\$29.00', 'Refunded'),
  ];

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-8 p-6',
      children: [
        MSDataTable<_PreviewInvoice>(
          rows: _rows,
          columns: <MSDataColumn<_PreviewInvoice>>[
            MSDataColumn<_PreviewInvoice>(
              label: 'Date',
              cell: (_PreviewInvoice row) => WText(row.date),
            ),
            MSDataColumn<_PreviewInvoice>(
              label: 'Status',
              cell: (_PreviewInvoice row) => WText(row.status),
            ),
            MSDataColumn<_PreviewInvoice>(
              label: 'Total',
              width: 100,
              alignEnd: true,
              cell: (_PreviewInvoice row) => WText(row.total),
            ),
          ],
        ),
      ],
    );
  }
}
