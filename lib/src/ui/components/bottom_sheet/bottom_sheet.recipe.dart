import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_theme.dart';

/// Slot keys for the [BottomSheet] component's Wind slot recipe.
const String kBottomSheetSlotPanel = 'panel';
const String kBottomSheetSlotHeader = 'header';
const String kBottomSheetSlotTitle = 'title';
const String kBottomSheetSlotDescription = 'description';
const String kBottomSheetSlotBody = 'body';
const String kBottomSheetSlotFooter = 'footer';

/// Builds the bottom-sheet [WindSlotRecipe] from a [MagicStarterModalTheme].
///
/// Returns per-slot className strings that map to modal theme fields. The
/// recipe is theme-driven (not a top-level const) so theme overrides work
/// in tests and runtime customisation.
WindSlotRecipe buildBottomSheetSlotRecipe(MagicStarterModalTheme theme) {
  return WindSlotRecipe(
    slots: {
      kBottomSheetSlotPanel:
          '${theme.containerClassName} w-full rounded-t-2xl rounded-b-none overflow-hidden',
      kBottomSheetSlotHeader: theme.headerClassName,
      kBottomSheetSlotTitle: theme.titleClassName,
      kBottomSheetSlotDescription: theme.descriptionClassName,
      kBottomSheetSlotBody: theme.bodyClassName,
      kBottomSheetSlotFooter: theme.footerClassName,
    },
  );
}
