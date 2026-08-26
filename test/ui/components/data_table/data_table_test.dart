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
      findsOneWidget,
      reason: 'the empty state replaces the ROWS; the header is still context',
    );
  });

  testWidgets('the empty state arrives even when the page lands after the '
      'first frame', (tester) async {
    // The ordinary consumer order: build the view, then let the controller load.
    // Reading `isEmpty` once at build time made the empty state depend on the
    // paginator having already resolved, so this order left a bare header
    // forever. The inner list view listens, so the state belongs to it.
    Http.fake(
      (_) => Http.response(<String, dynamic>{'data': <dynamic>[]}, 200),
    );
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'invoices',
      fromMap: _Row.fromMap,
    );

    await tester.pumpWidget(
      wrap(
        MSDataTable<_Row>.paginated(
          columns: columns(),
          paginator: paginator,
          bodyHeight: 300,
          emptyState: const Text('no invoices'),
        ),
        scrollable: false,
      ),
    );
    expect(find.text('no invoices'), findsNothing);

    await paginator.loadFirst();
    await tester.pumpAndSettle();

    expect(find.text('no invoices'), findsOneWidget);
  });

  testWidgets('an empty table does not reserve the whole body height', (
    tester,
  ) async {
    // Forwarding the empty state into the list view put it INSIDE the
    // `h-[bodyHeight]px` box, so an empty billing history was a header plus 420px
    // of mostly blank space around one sentence. The box is for rows; with no
    // rows there is nothing to bound.
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
          emptyState: const SizedBox(height: 24, child: Text('no invoices')),
        ),
        scrollable: false,
      ),
    );
    await tester.pumpAndSettle();

    final double height = tester.getSize(find.byType(MSDataTable<_Row>)).height;

    expect(find.text('no invoices'), findsOneWidget);
    expect(
      height,
      lessThan(200),
      reason:
          'the default bodyHeight is 420, and an empty table must not '
          'reserve it',
    );
  });

  testWidgets('alignEnd is honoured on a flexing column too', (tester) async {
    // It used to be applied only on the fixed track, so `alignEnd: true` with no
    // width rendered left-aligned with no error and no hint.
    //
    // Measured with a FIXED-SIZE cell on purpose. A `Text` fills its track, so
    // its box sits at the same coordinates either way and alignment only moves
    // the glyphs inside it: probing the text's own edges reports 400..788 for a
    // left-aligned cell and passes an "is it on the right" assertion that means
    // nothing. A 40px box has to actually move.
    await tester.pumpWidget(
      wrap(
        MSDataTable<_Row>(
          rows: const <_Row>[_Row(1, 'R')],
          columns: <MSDataColumn<_Row>>[
            MSDataColumn<_Row>(
              label: 'Left',
              cell: (_Row row) => Text('row ${row.id}'),
            ),
            MSDataColumn<_Row>(
              label: 'Right',
              alignEnd: true,
              cell: (_Row row) =>
                  SizedBox(width: 40, height: 20, child: Text(row.total)),
            ),
          ],
        ),
      ),
    );

    final Finder cell = find.byType(SizedBox).last;
    final double left = tester.getTopLeft(cell).dx;
    final double tableRight = tester
        .getTopRight(find.byType(MSDataTable<_Row>))
        .dx;

    expect(
      left,
      greaterThan(tableRight * 0.75),
      reason:
          'a 40px cell on a right-aligned track sits at the far end of it, '
          'not at its start',
    );
  });

  testWidgets('a loading label reaches the list view as a footer', (
    tester,
  ) async {
    // Scoped to the WIRING on purpose. Whether that footer appears while a page
    // is in flight is `MagicPaginatedListView`'s behaviour and is asserted in
    // magic's own suite, where holding a request open is possible; here the
    // question is only whether `loadingLabel` gets there. Proving it end to end
    // in this repo needed `MagicPaginator.fetcher`, and depending on an unmerged
    // magic API from a TEST turned this package's own gate red for a reason that
    // had nothing to do with the component.
    Http.fake((_) => Http.response(_page(3, next: 'page-2'), 200));
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

    final MagicPaginatedListView<_Row> list = tester
        .widget<MagicPaginatedListView<_Row>>(
          find.byType(MagicPaginatedListView<_Row>),
        );

    expect(list.loadingFooter, isNotNull);
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
