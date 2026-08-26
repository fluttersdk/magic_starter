import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/data_table/data_table.preview.dart';

/// One row of the fixture.
class _Row {
  const _Row(this.id, this.total);

  final int id;
  final String total;

  static _Row fromMap(Map<String, dynamic> map) =>
      _Row(map['id'] as int, map['total'] as String);
}

/// A cursor-paginated body of [count] rows.
Map<String, dynamic> _page(int count, {String? next, int offset = 0}) {
  return <String, dynamic>{
    'data': <Map<String, dynamic>>[
      for (int index = 0; index < count; index++)
        <String, dynamic>{'id': offset + index, 'total': '\$${offset + index}'},
    ],
    'meta': <String, dynamic>{'next_cursor': next, 'per_page': count},
  };
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  tearDown(() {
    Http.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  /// The eager mode is free to grow, so it gets a scroll view; the paginated
  /// mode brings its own bound and must NOT get one, or the outer scroll would
  /// hide the very thing under test.
  Widget wrap(Widget widget, {bool scrollable = true}) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: scrollable ? SingleChildScrollView(child: widget) : widget,
        ),
      ),
    );
  }

  List<MSDataColumn<_Row>> columns() => <MSDataColumn<_Row>>[
    MSDataColumn<_Row>(
      label: 'Id',
      cell: (_Row row) => SizedBox(height: 40, child: Text('row ${row.id}')),
    ),
    MSDataColumn<_Row>(
      label: 'Total',
      width: 100,
      alignEnd: true,
      cell: (_Row row) => Text(row.total),
    ),
  ];

  testWidgets('the eager mode renders the header and one row per element', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MSDataTable<_Row>(
          columns: columns(),
          rows: const <_Row>[_Row(1, '\$1'), _Row(2, '\$2')],
        ),
      ),
    );

    expect(find.text('ID'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('row 1'), findsOneWidget);
    expect(find.text('row 2'), findsOneWidget);
  });

  testWidgets('the paginated mode keeps its header and builds only the '
      'viewport', (tester) async {
    // The reason the paginated mode exists. The eager alternative builds all 200
    // rows on the first frame whether or not the reader scrolls that far; the
    // header is outside the scrolling body, so it survives either way.
    Http.fake((_) => Http.response(_page(200), 200));
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'invoices',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();
    expect(paginator.items.length, 200);

    await tester.pumpWidget(
      wrap(
        MSDataTable<_Row>.paginated(
          columns: columns(),
          paginator: paginator,
          bodyHeight: 300,
        ),
        scrollable: false,
      ),
    );
    await tester.pump();

    expect(find.text('ID'), findsOneWidget);
    final int built = tester.widgetList(find.textContaining('row ')).length;
    expect(
      built,
      lessThan(30),
      reason: '200 rows must not cost 200 rows of build in a 300px body',
    );
    expect(built, greaterThan(0));
  });

  testWidgets('scrolling the paginated body asks for the next page', (
    tester,
  ) async {
    int requests = 0;
    Http.fake((MagicRequest request) {
      requests++;

      return request.queryParameters?['cursor'] == null
          ? Http.response(_page(50, next: 'page-2'), 200)
          : Http.response(_page(50, offset: 100), 200);
    });
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'invoices',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();
    expect(requests, 1);

    await tester.pumpWidget(
      wrap(
        MSDataTable<_Row>.paginated(
          columns: columns(),
          paginator: paginator,
          bodyHeight: 300,
        ),
        scrollable: false,
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(requests, 2, reason: 'reaching the tail is what fetches page two');
    expect(paginator.items.length, 100);
  });

  testWidgets('an empty first page renders the empty state', (tester) async {
    Http.fake(
      (_) => Http.response(<String, dynamic>{'data': <dynamic>[]}, 200),
    );
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'invoices',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();

    await tester.pumpWidget(
      wrap(
        MSDataTable<_Row>.paginated(
          columns: columns(),
          paginator: paginator,
          emptyState: const Text('no invoices'),
        ),
        scrollable: false,
      ),
    );

    expect(find.text('no invoices'), findsOneWidget);
    expect(
      find.text('ID'),
      findsNothing,
      reason: 'an empty state replaces the table, header included',
    );
  });

  testWidgets('a loading label renders only while a page is in flight', (
    tester,
  ) async {
    Http.fake((_) => Http.response(_page(50, next: 'page-2'), 200));
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'invoices',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();

    await tester.pumpWidget(
      wrap(
        MSDataTable<_Row>.paginated(
          columns: columns(),
          paginator: paginator,
          bodyHeight: 300,
          loadingLabel: 'Loading more',
        ),
        scrollable: false,
      ),
    );
    await tester.pump();

    expect(
      find.text('Loading more'),
      findsNothing,
      reason: 'nothing is in flight, so the tail row would be a lie',
    );
  });

  testWidgets('DataTablePreview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const DataTablePreview()));
    await tester.pump();

    expect(find.text('DATE'), findsOneWidget);
    expect(
      find.text('\$29.00'),
      findsNWidgets(3),
      reason: 'the fixture is three invoices at the same monthly price',
    );
  });
}
