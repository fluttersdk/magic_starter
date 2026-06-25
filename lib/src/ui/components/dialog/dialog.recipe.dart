import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_theme.dart';

/// Slot keys for the [Dialog] component's Wind slot recipe.
///
/// The dialog uses a [WindSlotRecipe] to emit per-slot classNames driven
/// by `MagicStarterModalTheme`. Callers that need raw className strings
/// (e.g. for sub-widget previews or custom shells) can call
/// [buildDialogSlotRecipe] directly.
const String kDialogSlotContainer = 'container';
const String kDialogSlotHeader = 'header';
const String kDialogSlotTitle = 'title';
const String kDialogSlotDescription = 'description';
const String kDialogSlotBody = 'body';
const String kDialogSlotFooter = 'footer';

/// Builds the dialog [WindSlotRecipe] from a [MagicStarterModalTheme].
///
/// The recipe is theme-driven (not a top-level const) because all classNames
/// are overridable via `MagicStarter.useModalTheme()`. Returns per-slot
/// className strings that map directly to the modal theme fields.
///
/// Slot keys: [kDialogSlotContainer], [kDialogSlotHeader],
/// [kDialogSlotTitle], [kDialogSlotDescription], [kDialogSlotBody],
/// [kDialogSlotFooter].
WindSlotRecipe buildDialogSlotRecipe(MagicStarterModalTheme theme) {
  return WindSlotRecipe(
    slots: {
      kDialogSlotContainer: theme.containerClassName,
      kDialogSlotHeader: theme.headerClassName,
      kDialogSlotTitle: theme.titleClassName,
      kDialogSlotDescription: theme.descriptionClassName,
      kDialogSlotBody: theme.bodyClassName,
      kDialogSlotFooter: theme.footerClassName,
    },
  );
}
