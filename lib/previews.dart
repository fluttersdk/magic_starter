/// **Dev-only barrel of magic_starter component previews.**
///
/// This is intentionally SEPARATE from the `magic_starter.dart` release barrel:
/// per the atomic-component contract, `*.preview.dart` files never join the
/// release barrel. A consumer's dev-only preview catalog imports THIS library
/// instead, behind a `kReleaseMode` / `PREVIEW_ENABLED` guard, so release builds
/// that do not reach it tree-shake every preview (and the components they pull
/// in only for preview).
///
/// [starterComponentPreviews] returns the full set as `(label, slug, builder)`
/// records from a FUNCTION (never a top-level const holding widget refs — the
/// dart-lang/sdk#33920 foot-gun), so the set stays droppable when unreferenced.
library;

import 'package:flutter/widgets.dart';

import 'src/ui/components/accordion/accordion.preview.dart';
import 'src/ui/components/badge/badge.preview.dart';
import 'src/ui/components/settings_nav_row/settings_nav_row.preview.dart';
import 'src/ui/components/settings_row/settings_row.preview.dart';
import 'src/ui/components/page_container/page_container.preview.dart';
import 'src/ui/components/page_scaffold/page_scaffold.preview.dart';
import 'src/ui/components/settings_section/settings_section.preview.dart';
import 'src/ui/components/bottom_sheet/bottom_sheet.preview.dart';
import 'src/ui/components/button/button.preview.dart';
import 'src/ui/components/card/card.preview.dart';
import 'src/ui/components/checkbox/checkbox.preview.dart';
import 'src/ui/components/combobox/combobox.preview.dart';
import 'src/ui/components/confirm_dialog/confirm_dialog.preview.dart';
import 'src/ui/components/dialog/dialog.preview.dart';
import 'src/ui/components/dropdown_menu/dropdown_menu.preview.dart';
import 'src/ui/components/empty_state/empty_state.preview.dart';
import 'src/ui/components/error_state/error_state.preview.dart';
import 'src/ui/components/form_field/form_field.preview.dart';
import 'src/ui/components/input/input.preview.dart';
import 'src/ui/components/navbar/navbar.preview.dart';
import 'src/ui/components/notification_dropdown/notification_dropdown.preview.dart';
import 'src/ui/components/page_header/page_header.preview.dart';
import 'src/ui/components/radio/radio.preview.dart';
import 'src/ui/components/segmented_control/segmented_control.preview.dart';
import 'src/ui/components/select/select.preview.dart';
import 'src/ui/components/skeleton/skeleton.preview.dart';
import 'src/ui/components/social_divider/social_divider.preview.dart';
import 'src/ui/components/switch/switch.preview.dart';
import 'src/ui/components/tabs/tabs.preview.dart';
import 'src/ui/components/team_selector/team_selector.preview.dart';
import 'src/ui/components/textarea/textarea.preview.dart';
import 'src/ui/components/toast/toast.preview.dart';
import 'src/ui/components/tooltip/tooltip.preview.dart';
import 'src/ui/components/typography/typography.preview.dart';
import 'src/ui/components/user_profile_dropdown/user_profile_dropdown.preview.dart';

/// One registered starter component preview: a human [label], a URL-safe
/// [slug] (the component folder name), and a [builder] that renders the
/// component's variant matrix.
typedef StarterComponentPreview = ({
  String label,
  String slug,
  WidgetBuilder builder,
});

/// Every magic_starter component preview, as `(label, slug, builder)` records.
///
/// Dev-only: call this only from a preview catalog behind a release guard.
List<StarterComponentPreview> starterComponentPreviews() {
  return <StarterComponentPreview>[
    (
      label: 'Accordion',
      slug: 'accordion',
      builder: (_) => const AccordionPreview()
    ),
    (label: 'Badge', slug: 'badge', builder: (_) => const BadgePreview()),
    (
      label: 'Bottom Sheet',
      slug: 'bottom_sheet',
      builder: (_) => const BottomSheetPreview()
    ),
    (label: 'Button', slug: 'button', builder: (_) => const ButtonPreview()),
    (label: 'Card', slug: 'card', builder: (_) => const CardPreview()),
    (
      label: 'Checkbox',
      slug: 'checkbox',
      builder: (_) => const CheckboxPreview()
    ),
    (
      label: 'Combobox',
      slug: 'combobox',
      builder: (_) => const ComboboxPreview()
    ),
    (
      label: 'Confirm Dialog',
      slug: 'confirm_dialog',
      builder: (_) => const ConfirmDialogPreview()
    ),
    (label: 'Dialog', slug: 'dialog', builder: (_) => const DialogPreview()),
    (
      label: 'Dropdown Menu',
      slug: 'dropdown_menu',
      builder: (_) => const DropdownMenuPreview()
    ),
    (
      label: 'Empty State',
      slug: 'empty_state',
      builder: (_) => const EmptyStatePreview()
    ),
    (
      label: 'Error State',
      slug: 'error_state',
      builder: (_) => const ErrorStatePreview()
    ),
    (
      label: 'Form Field',
      slug: 'form_field',
      builder: (_) => const MagicFormFieldPreview()
    ),
    (label: 'Input', slug: 'input', builder: (_) => const InputPreview()),
    (label: 'Navbar', slug: 'navbar', builder: (_) => const NavbarPreview()),
    (
      label: 'Notification Dropdown',
      slug: 'notification_dropdown',
      builder: (_) => const NotificationDropdownPreview()
    ),
    (
      label: 'Page Header',
      slug: 'page_header',
      builder: (_) => const PageHeaderPreview()
    ),
    (label: 'Radio', slug: 'radio', builder: (_) => const RadioPreview()),
    (
      label: 'Segmented Control',
      slug: 'segmented_control',
      builder: (_) => const SegmentedControlPreview()
    ),
    (label: 'Select', slug: 'select', builder: (_) => const SelectPreview()),
    (
      label: 'Settings Nav Row',
      slug: 'settings_nav_row',
      builder: (_) => const SettingsNavRowPreview()
    ),
    (
      label: 'Settings Row',
      slug: 'settings_row',
      builder: (_) => const SettingsRowPreview()
    ),
    (
      label: 'Page Container',
      slug: 'page_container',
      builder: (_) => const PageContainerPreview()
    ),
    (
      label: 'Page Scaffold',
      slug: 'page_scaffold',
      builder: (_) => const PageScaffoldPreview()
    ),
    (
      label: 'Settings Section',
      slug: 'settings_section',
      builder: (_) => const SettingsSectionPreview()
    ),
    (
      label: 'Skeleton',
      slug: 'skeleton',
      builder: (_) => const SkeletonPreview()
    ),
    (
      label: 'Social Divider',
      slug: 'social_divider',
      builder: (_) => const SocialDividerPreview()
    ),
    (label: 'Switch', slug: 'switch', builder: (_) => const SwitchPreview()),
    (label: 'Tabs', slug: 'tabs', builder: (_) => const TabsPreview()),
    (
      label: 'Team Selector',
      slug: 'team_selector',
      builder: (_) => const TeamSelectorPreview()
    ),
    (
      label: 'Textarea',
      slug: 'textarea',
      builder: (_) => const TextareaPreview()
    ),
    (label: 'Toast', slug: 'toast', builder: (_) => const ToastPreview()),
    (label: 'Tooltip', slug: 'tooltip', builder: (_) => const TooltipPreview()),
    (
      label: 'Typography',
      slug: 'typography',
      builder: (_) => const TypographyPreview()
    ),
    (
      label: 'User Profile Dropdown',
      slug: 'user_profile_dropdown',
      builder: (_) => const UserProfileDropdownPreview()
    ),
  ];
}
