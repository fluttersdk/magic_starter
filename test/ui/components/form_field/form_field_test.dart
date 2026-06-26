import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/form_field/form_field.preview.dart';

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
        child: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Slot / structure tests
  // ---------------------------------------------------------------------------

  testWidgets('MagicFormField renders label when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        MagicFormField(
          label: 'Email',
          child: const WDiv(className: 'h-10'),
        ),
      ),
    );
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('MagicFormField renders child widget', (tester) async {
    const childKey = Key('form-field-child');
    await tester.pumpWidget(
      wrap(
        MagicFormField(
          label: 'Name',
          child: SizedBox(key: childKey, height: 10),
        ),
      ),
    );
    expect(find.byKey(childKey), findsOneWidget);
  });

  testWidgets('MagicFormField renders hint when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        MagicFormField(
          label: 'Password',
          hint: 'Must be at least 8 characters',
          child: const WDiv(className: 'h-10'),
        ),
      ),
    );
    expect(find.text('Must be at least 8 characters'), findsOneWidget);
  });

  testWidgets('MagicFormField does not render hint when omitted',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        MagicFormField(
          label: 'Name',
          child: const WDiv(className: 'h-10'),
        ),
      ),
    );
    // Only label WText present; no hint
    final texts = tester.widgetList<WText>(find.byType(WText)).toList();
    expect(texts.length, 1);
  });

  testWidgets('MagicFormField renders error when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        MagicFormField(
          label: 'Email',
          error: 'Invalid email address',
          child: const WDiv(className: 'h-10'),
        ),
      ),
    );
    expect(find.text('Invalid email address'), findsOneWidget);
  });

  testWidgets('MagicFormField error text uses destructive tone class',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        MagicFormField(
          label: 'Email',
          error: 'Required field',
          child: const WDiv(className: 'h-10'),
        ),
      ),
    );
    final texts = tester.widgetList<WText>(find.byType(WText)).toList();
    // The error WText should contain a destructive/error tone class
    final errorText = texts.last;
    expect(
      errorText.className,
      anyOf(contains('text-red'), contains('destructive'), contains('error')),
    );
  });

  testWidgets('MagicFormField does not render error when omitted',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        MagicFormField(
          label: 'Name',
          child: const WDiv(className: 'h-10'),
        ),
      ),
    );
    expect(find.text('Required'), findsNothing);
  });

  testWidgets('MagicFormField renders without label when label is null',
      (tester) async {
    await tester.pumpWidget(
      wrap(MagicFormField(child: const WDiv(className: 'h-10'))),
    );
    expect(find.byType(MagicFormField), findsOneWidget);
  });

  testWidgets('MagicFormField preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const MagicFormFieldPreview()));
    await tester.pump();
    expect(find.byType(MagicFormFieldPreview), findsOneWidget);
  });
}
