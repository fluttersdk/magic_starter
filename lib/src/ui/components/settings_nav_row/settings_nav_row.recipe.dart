import 'package:magic/magic.dart';

/// The row layout axis key for the settings nav row recipe.
const String kSettingsNavRowLayoutAxis = 'layout';

/// Single layout value — nav rows have one fixed layout.
const String kSettingsNavRowLayoutDefault = 'default';

/// The settings nav row [WindRecipe].
///
/// A const recipe — no theme override hook needed here; semantic alias tokens
/// handle light/dark automatically. The row uses the same horizontal inset
/// (`px-5 py-3.5`) and 44-pt minimum height (`min-h-11`) as iOS list rows.
///
/// Emission order: `base ++ layout-variant`.
const WindRecipe settingsNavRowRecipe = WindRecipe(
  base: 'w-full flex flex-row items-center min-h-12 px-5 py-4 '
      'bg-surface-container '
      'hover:bg-surface-container-high',
  variants: {
    kSettingsNavRowLayoutAxis: {
      kSettingsNavRowLayoutDefault: '',
    },
  },
  defaultVariants: {
    kSettingsNavRowLayoutAxis: kSettingsNavRowLayoutDefault,
  },
);

/// Leading icon tile className (the colored square behind the icon).
const String kSettingsNavRowIconTileClassName =
    'grid place-items-center size-10 rounded-lg '
    'bg-surface-container-high';

/// Leading icon className (the icon inside the tile).
const String kSettingsNavRowIconClassName = 'text-fg-muted text-lg';

/// Title className for the nav row.
const String kSettingsNavRowTitleClassName = 'text-base font-medium text-fg';

/// Subtitle className for the nav row.
const String kSettingsNavRowSubtitleClassName = 'text-sm text-fg-muted';

/// Trailing value className for the nav row.
const String kSettingsNavRowValueClassName = 'text-sm text-fg-muted';

/// Trailing chevron icon className.
const String kSettingsNavRowChevronClassName = 'text-fg-muted';
