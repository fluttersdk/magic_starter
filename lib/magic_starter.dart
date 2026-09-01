// Magic Starter plugin exports

export 'src/ui/theme/magic_starter_tokens.dart';
export 'src/cli/starter_artisan_provider.dart';
export 'src/facades/magic_starter.dart';
export 'src/magic_starter_manager.dart';
export 'src/testing/magic_starter_test_utils.dart';
export 'src/providers/magic_starter_service_provider.dart';
export 'src/ui/magic_starter_view_registry.dart';
export 'src/configuration/magic_starter_config.dart';
export 'src/configuration/magic_starter_theme.dart';
export 'src/models/magic_starter_team.dart';
export 'src/models/magic_starter_nav_item.dart';
export 'src/http/controllers/magic_starter_auth_controller.dart';
export 'src/models/magic_starter_auth_user.dart';
export 'src/models/magic_starter_plan.dart';
export 'src/http/controllers/magic_starter_profile_controller.dart';
export 'src/http/controllers/magic_starter_team_controller.dart';
export 'src/http/controllers/magic_starter_otp_controller.dart';
export 'src/http/controllers/magic_starter_guest_auth_controller.dart';
export 'src/http/controllers/magic_starter_billing_controller.dart';

/// `BillingCycle` is re-exported because `MagicStarterBillingController.cycle`
/// is public and answers one, and nothing else in this barrel re-exports
/// `magic_payments`. Without this line an adopter can read that getter and
/// cannot NAME its type: they would have to add `magic_payments` to their own
/// pubspec for a type this package's own API hands them, and that package is not
/// on pub.dev yet. Deliberately the one member rather than the whole barrel: the
/// entitlement contract belongs to `magic_payments` and an adopter using it
/// depends on it directly.
export 'package:magic_payments/magic_payments.dart' show BillingCycle;

export 'src/http/controllers/magic_starter_newsletter_controller.dart';
export 'src/routes/auth_routes.dart';
export 'src/routes/profile_routes.dart';
export 'src/routes/team_routes.dart';
export 'src/routes/notification_routes.dart';
export 'src/ui/views/auth/magic_starter_login_view.dart';
export 'src/ui/views/auth/magic_starter_register_view.dart';
export 'src/ui/views/auth/magic_starter_forgot_password_view.dart';
export 'src/ui/views/auth/magic_starter_reset_password_view.dart';
export 'src/ui/views/auth/magic_starter_two_factor_challenge_view.dart';
export 'src/ui/views/auth/magic_starter_otp_verify_view.dart';
export 'src/ui/views/profile/magic_starter_profile_settings_view.dart';
export 'src/ui/views/teams/magic_starter_billing_view.dart';
export 'src/ui/views/teams/magic_starter_team_create_view.dart';
export 'src/ui/views/teams/magic_starter_team_settings_view.dart';
export 'src/ui/layouts/magic_starter_app_layout.dart';
export 'src/ui/layouts/magic_starter_guest_layout.dart';
export 'src/ui/widgets/magic_starter_auth_form_card.dart';
export 'src/ui/components/team_selector/index.dart';
export 'src/ui/components/card/index.dart';
export 'src/ui/components/user_profile_dropdown/index.dart';
export 'src/ui/components/social_divider/index.dart';
export 'src/ui/widgets/magic_starter_password_confirm_dialog.dart';
export 'src/ui/widgets/magic_starter_confirm_dialog.dart';
export 'src/ui/widgets/magic_starter_two_factor_modal.dart';
export 'src/ui/widgets/magic_starter_timezone_select.dart';
export 'src/ui/components/page_header/index.dart';
export 'src/ui/widgets/magic_starter_dialog_shell.dart';
export 'src/ui/widgets/magic_starter_hide_bottom_nav.dart';
export 'src/ui/views/teams/magic_starter_team_invitation_accept_view.dart';

// Design-system components (Wave 4 atomic-component library).
// Migrated components (card, page_header, social_divider,
// user_profile_dropdown, team_selector, confirm_dialog) are already reachable
// through their existing alias exports above and are intentionally excluded here.
export 'src/ui/components/button/index.dart';
export 'src/ui/components/input/index.dart';
export 'src/ui/components/textarea/index.dart';
export 'src/ui/components/checkbox/index.dart';
export 'src/ui/components/switch/index.dart';
export 'src/ui/components/radio/index.dart';
export 'src/ui/components/badge/index.dart';
export 'src/ui/components/typography/index.dart';
export 'src/ui/components/skeleton/index.dart';
export 'src/ui/components/select/index.dart';
export 'src/ui/components/combobox/index.dart';
export 'src/ui/components/segmented_control/index.dart';
export 'src/ui/components/tabs/index.dart';
export 'src/ui/components/accordion/index.dart';
export 'src/ui/components/dialog/index.dart';
export 'src/ui/components/bottom_sheet/index.dart';
export 'src/ui/components/toast/index.dart';
export 'src/ui/components/tooltip/index.dart';
export 'src/ui/components/dropdown_menu/index.dart';
export 'src/ui/components/form_field/index.dart';
export 'src/ui/components/navbar/index.dart';
export 'src/ui/components/data_table/index.dart';
export 'src/ui/components/empty_state/index.dart';
export 'src/ui/components/error_state/index.dart';
export 'src/ui/components/settings_section/index.dart';
export 'src/ui/components/settings_row/index.dart';
export 'src/ui/components/settings_nav_row/index.dart';
export 'src/ui/components/page_container/index.dart';
export 'src/ui/components/page_scaffold/index.dart';
export 'src/ui/components/upgrade_dialog/index.dart';
export 'src/ui/components/upgrade_nudge/index.dart';
export 'src/ui/components/usage_meter/index.dart';
export 'src/support/plan_upgrade.dart';
export 'src/support/upgrade_prompt.dart';
export 'src/http/session_scoped_controller.dart';
export 'src/http/session_scope_sync.dart';
export 'src/middleware/ensure_authenticated.dart';
export 'src/middleware/redirect_if_authenticated.dart';
