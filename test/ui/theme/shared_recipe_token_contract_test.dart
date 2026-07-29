import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/ui/components/empty_state/empty_state.recipe.dart';
import 'package:magic_starter/src/ui/components/error_state/error_state.recipe.dart';
import 'package:magic_starter/src/ui/components/upgrade_dialog/upgrade_dialog.recipe.dart';
import 'package:magic_starter/src/ui/components/upgrade_nudge/upgrade_nudge.recipe.dart';
import 'package:magic_starter/src/ui/theme/magic_starter_tokens.dart';

/// Every colour token a SHARED component emits must be resolvable by the theme
/// this package ships, either as an alias key or as a colour family name.
///
/// This exists because a token that resolves to nothing does not throw and does
/// not warn: Wind claims a `text-<name>` / `bg-<name>` class, fails to resolve
/// the name, and drops the class, so the surface renders the inherited value.
/// Two real defects shipped that way, both in components moved in from a
/// consumer app: `bg-ai-soft` / `text-ai` (defined only in that app's
/// hand-authored supplement) and then `text-destructive` (semantic-looking, but
/// the alias contract ships `bg-destructive` / `text-on-destructive` only, with
/// no destructive TEXT role).
///
/// The per-component render tests catch a specific instance; this catches the
/// whole family, including in components that do not exist yet.
void main() {
  /// Colour-bearing prefixes Wind resolves through the alias map or the palette.
  /// A `text-` class can also be a size or weight, so those are filtered out by
  /// the known-utility list rather than treated as colours.
  const List<String> colourPrefixes = <String>[
    'bg-',
    'text-',
    'border-color-',
  ];

  /// `text-*` values that are NOT colours.
  const Set<String> nonColourTextUtilities = <String>{
    'xs',
    'sm',
    'base',
    'lg',
    'xl',
    '2xl',
    '3xl',
    '4xl',
    '5xl',
    '6xl',
    'left',
    'right',
    'center',
    'justify',
    'start',
    'end',
    'wrap',
    'nowrap',
    'balance',
    'pretty',
    'ellipsis',
    'clip',
  };

  /// Wind resolves a bare colour family (`primary`) through
  /// [WindThemeData.colors], which merges into its own defaults. The starter
  /// requires a `primary` swatch from the consumer, so that family always
  /// resolves.
  final Set<String> colourFamilies = WindThemeData().colors.keys.toSet();

  /// Palette shades (`red-600`, `gray-100`, `gray-950`) are Wind built-ins.
  ///
  /// 950 is included because the shipped aliases themselves use it
  /// (`bg-surface` expands to `bg-white dark:bg-gray-950`), so omitting it would
  /// make this guard reject a token the package already relies on.
  final RegExp paletteShade = RegExp(r'^[a-z]+-(?:50|950|[1-9]00)$');

  bool resolves(String token) {
    if (MagicStarterTokens.defaultAliases.containsKey(token)) return true;

    for (final String prefix in colourPrefixes) {
      if (!token.startsWith(prefix)) continue;
      final String body = token.substring(prefix.length);
      if (colourFamilies.contains(body)) return true;
      if (paletteShade.hasMatch(body)) return true;
      // `bg-primary/50`, `text-fg/80`: the opacity suffix does not change
      // whether the family resolves.
      final String bare = body.split('/').first;
      if (colourFamilies.contains(bare) || paletteShade.hasMatch(bare)) {
        return true;
      }
    }

    return false;
  }

  /// Pulls the candidate colour tokens out of a className string.
  Iterable<String> colourTokensIn(String className) {
    return className.split(RegExp(r'\s+')).where((String raw) {
      if (raw.isEmpty) return false;
      // Drop variant prefixes (`dark:`, `md:`, `hover:`) and test the base.
      final String token = raw.contains(':') ? raw.split(':').last : raw;
      if (!colourPrefixes.any(token.startsWith)) return false;
      if (token.startsWith('text-') &&
          nonColourTextUtilities.contains(token.substring(5))) {
        return false;
      }
      return true;
    }).map((String raw) => raw.contains(':') ? raw.split(':').last : raw);
  }

  /// Every className string the four shared components emit, keyed by origin so
  /// a failure names the exact recipe entry to fix.
  final Map<String, String> sharedClassNames = <String, String>{
    'emptyState.root': emptyStateRootClassName(),
    'emptyState.iconWrap': emptyStateIconWrapClassName(),
    'emptyState.icon': emptyStateIconClassName(),
    'emptyState.title': emptyStateTitleClassName(),
    'emptyState.description': emptyStateDescriptionClassName(),
    'errorState.root': errorStateRootClassName(),
    'errorState.iconWrap': errorStateIconWrapClassName(),
    'errorState.icon': errorStateIconClassName(),
    'errorState.title': errorStateTitleClassName(),
    'errorState.description': errorStateDescriptionClassName(),
    for (final MapEntry<String, String> slot
        in upgradeNudgeRecipe(variants: const {}).entries)
      'upgradeNudge.${slot.key}': slot.value,
    for (final MapEntry<String, String> slot
        in upgradeDialogRecipe(variants: const {}).entries)
      'upgradeDialog.${slot.key}': slot.value,
  };

  group('shared component recipes only emit resolvable colour tokens', () {
    sharedClassNames.forEach((String origin, String className) {
      test(origin, () {
        final List<String> unresolvable = colourTokensIn(className)
            .where((String token) => !resolves(token))
            .toList();

        expect(
          unresolvable,
          isEmpty,
          reason: 'these tokens resolve to nothing, so the class is dropped '
              'silently and the surface renders the inherited value: '
              '$unresolvable (in "$className"). Use a key from '
              'MagicStarterTokens.defaultAliases, a colour family, or a raw '
              'palette pair.',
        );
      });
    });
  });

  test('the guard itself rejects a token that resolves to nothing', () {
    // Without this, a bug in `resolves` would make every case above vacuous.
    expect(colourTokensIn('bg-ai-soft text-ai p-4').toList(),
        <String>['bg-ai-soft', 'text-ai']);
    expect(resolves('bg-ai-soft'), isFalse);
    expect(resolves('text-ai'), isFalse);
    expect(resolves('text-destructive'), isFalse);

    // And accepts the three shapes that do resolve.
    expect(resolves('bg-primary-container'), isTrue);
    expect(resolves('text-primary'), isTrue);
    expect(resolves('text-red-600'), isTrue);
    expect(resolves('bg-gray-950'), isTrue);
  });
}
