import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/navbar/navbar.preview.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: SingleChildScrollView(child: widget),
        ),
      ),
    );
  }

  testWidgets('Navbar renders brand when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        MSNavbar(
          brand: const Text('My App'),
          children: const [],
        ),
      ),
    );
    expect(find.text('My App'), findsOneWidget);
  });

  testWidgets('Navbar renders children', (tester) async {
    const childKey = Key('navbar-child');
    await tester.pumpWidget(
      wrap(
        MSNavbar(
          children: [
            SizedBox(key: childKey, width: 10),
          ],
        ),
      ),
    );
    expect(find.byKey(childKey), findsOneWidget);
  });

  testWidgets('Navbar renders trailing widget when provided', (tester) async {
    const trailingKey = Key('navbar-trailing');
    await tester.pumpWidget(
      wrap(
        MSNavbar(
          trailing: SizedBox(key: trailingKey, width: 10),
          children: const [],
        ),
      ),
    );
    expect(find.byKey(trailingKey), findsOneWidget);
  });

  testWidgets('Navbar preview renders without error', (tester) async {
    // Use a wider surface so the responsive navbar preview does not overflow.
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(wrap(const NavbarPreview()));
    await tester.pump();
    expect(find.byType(NavbarPreview), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
