import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// A phone, the width the controls are 44 px tall at by their own recipes.
const Size kPhone = Size(390, 844);

/// A desktop window, above the `lg` breakpoint.
const Size kDesktop = Size(1440, 900);

/// The one control standard of a host design system: 44 px tall, 17 on 22 type.
///
/// Shared by the control tests so that every one of them measures the same
/// strings. Each control reaches 44 px its own way, because the boxes differ:
///
/// - [MSInput] paints its border inside the padding (WInput draws it in a
///   `DecoratedBox`), so 11 + 22 + 11 is the whole 44.
/// - The select and combobox triggers are Wind boxes whose border adds to the
///   size, so 10 + 22 + 10 + 2 is 44.
/// - A segmented item is a 36 px pill, 7 + 22 + 7, in a root with 4 px around
///   it; below `lg` the 44 px hit cell supplies that room, so the root keeps no
///   vertical padding there.
const MagicStarterFieldTheme hostFieldTheme = MagicStarterFieldTheme(
  inputSizeClassName: 'py-[11px] text-[17px] leading-[22px]',
  selectSizeClassName: 'py-2.5 text-[17px] leading-[22px]',
  segmentedSmClassName: 'py-[7px] text-[17px] leading-[22px]',
  segmentedMdClassName: 'py-[7px] text-[17px] leading-[22px]',
  segmentedPaddingClassName: 'px-1 py-0 lg:py-1',
);

/// Mounts [widget] at the top of a scroll view on a surface of [size] logical
/// pixels, in the Wind [brightness] given.
///
/// Both `physicalSize` and `devicePixelRatio` are set, since setting only the
/// first lays the tree out at the wrong logical width. The scroll view hands the
/// control an unbounded height, as a page does: in a `Center` a column-shaped
/// control fills the height of the surface and has no size to measure.
/// `syncWithSystem: false` keeps a dark theme dark, since a syncing theme is
/// forced to the test platform's brightness.
Future<void> pumpControlAt(
  WidgetTester tester,
  Size size,
  Widget widget, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: WindTheme(
        data: WindThemeData(brightness: brightness, syncWithSystem: false),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Align(alignment: Alignment.topCenter, child: widget),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The style the paragraph reading [text] paints with.
TextStyle? paintedStyle(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text)).text.style;
}

/// The line height, in logical pixels, of the paragraph reading [text].
double lineHeightOf(WidgetTester tester, String text) {
  final TextStyle style = paintedStyle(tester, text)!;

  return style.fontSize! * style.height!;
}

/// The vertical centre of the glyphs of [text], not of the box Flutter lays the
/// paragraph in: under a minimum height the paragraph is stretched to fill it
/// with its glyphs at the top, so the box centre would lie.
double glyphCentre(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      )
      .first;

  return paragraph.localToGlobal(box.toRect().center).dy;
}
