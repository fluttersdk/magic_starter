# Profile Management

- [Introduction](#introduction)
- [Profile Photo](#profile-photo)
- [Email & Password](#email--password)
    - [Updating Profile Information](#updating-profile-information)
    - [Changing Password](#changing-password)
- [Email Verification](#email-verification)
- [Session Management](#session-management)
- [Timezone Selection](#timezone-selection)
- [Extended Profile](#extended-profile)
- [Newsletter](#newsletter)
- [Delete Account](#delete-account)
- [Two-Factor Management](#two-factor-management)
- [Gate Abilities](#gate-abilities)
- [Controller](#controller)
- [View](#view)

<a name="introduction"></a>
## Introduction

The profile module provides a unified settings page where authenticated users manage their account information, security settings, and preferences. Every section is independently feature-gated — the host app enables only what it needs.

`MagicStarterProfileController` is the central controller. It uses the `withoutNotifying()` pattern to prevent full-page rebuilds during form-level submissions, and section-level `ValueNotifier` fields for fine-grained reactivity.

> [!NOTE]
> Profile routes are registered under `MagicStarterConfig.profilePrefix()` (default `/settings`). All profile routes require the `EnsureAuthenticated` middleware and render inside `AppLayout`.

<a name="profile-photo"></a>
## Profile Photo

Gated by `MagicStarterConfig.hasProfilePhotoFeatures()` (`magic_starter.features.profile_photos`).

Upload a profile photo via `Http.upload()`:

```dart
final success = await MagicStarterProfileController.instance.doUpdateProfilePhoto(
  file: magicFile,
);
```

The controller sends a multipart `POST` to `/user/profile-photo` with the file under the `photo` key. On success, it calls `Auth.restore()` to refresh the user model (which includes the new `profile_photo_url`).

Delete the current photo:

```dart
final success = await MagicStarterProfileController.instance.doDeleteProfilePhoto();
```

This sends `DELETE /user/profile-photo` and restores the auth state afterward.

> [!TIP]
> Both photo operations call `Auth.restore()` on success so the UI immediately reflects the change without a manual refresh.

<a name="email--password"></a>
## Email & Password

<a name="updating-profile-information"></a>
### Updating Profile Information

`doUpdateProfile()` sends `PUT /user/profile` with the updated fields. Only non-empty optional fields are included in the payload:

```dart
final success = await controller.withoutNotifying(
  () => controller.doUpdateProfile(
    name: form['name'],
    email: form['email'],
    phone: form['phone'],
    timezone: form['timezone'],
    language: form['language'],
  ),
);
```

The `withoutNotifying()` wrapper suppresses full-page `notifyListeners()` calls while the form-level `MagicFormData.process()` drives the submit button's loading state. This prevents the entire settings page from rebuilding during a single section's save.

On success, `Auth.restore()` refreshes the user model and a toast confirmation is shown.

<a name="changing-password"></a>
### Changing Password

`doUpdatePassword()` sends `PUT /user/password` with `current_password`, `password`, and `password_confirmation`:

```dart
final success = await controller.doUpdatePassword(
  currentPassword: form['current_password'],
  password: form['password'],
  passwordConfirmation: form['password_confirmation'],
);
```

> [!IMPORTANT]
> Password changes require the current password for verification. The confirmation dialog in the view uses inline error handling via `setState()` — it never auto-closes on error.

<a name="email-verification"></a>
## Email Verification

Gated by `MagicStarterConfig.hasEmailVerificationFeatures()` (`magic_starter.features.email_verification`).

Send or resend a verification email:

```dart
await MagicStarterProfileController.instance.sendEmailVerification();
```

This calls `POST /email/verification-notification`. On success, a toast message confirms the email was sent.

Check the current verification status:

```dart
final isVerified = controller.isEmailVerified;
```

The getter reads `email_verified_at` from the authenticated user model — it returns `true` only when the field is a non-null, non-empty string.

> [!NOTE]
> The verification link is handled by the backend. When the user clicks the link in their email, the backend marks the account as verified. Call `Auth.restore()` to pull the updated status.

<a name="session-management"></a>
## Session Management

Gated by `MagicStarterConfig.hasSessionsFeatures()` (`magic_starter.features.sessions`).

View active sessions:

```dart
final sessions = await MagicStarterProfileController.instance.getSessions();
```

Returns a list of session maps from `GET /sessions`, each containing device info, IP address, and last activity timestamp.

Revoke a specific session:

```dart
final success = await controller.doRevokeSession(
  tokenId: session['id'],
  password: currentPassword,
);
```

Revoke all other sessions except the current one:

```dart
final success = await controller.doRevokeOtherSessions(
  password: currentPassword,
);
```

Both revocation methods use Laravel method spoofing — `{'_method': 'DELETE'}` in an `Http.post()` call — and require the current account password for sudo-mode confirmation.

> [!TIP]
> Session revocation is destructive. Always prompt the user for their password via a confirmation dialog before calling these methods.

<a name="timezone-selection"></a>
## Timezone Selection

Gated by `MagicStarterConfig.hasTimezoneFeatures()` (`magic_starter.features.timezones`). Also visible when `MagicStarterConfig.hasExtendedProfileFeatures()` is enabled — the config helper `hasTimezoneOrExtendedProfileFeatures()` checks both.

Timezone data is fetched via a **debounced async API search**, not from local data:

```dart
final response = await Http.get('/timezones', query: {'search': query});
```

The timezone select widget debounces user input before firing the API request. Results are displayed as a searchable dropdown. The selected timezone identifier is included in the profile update payload.

> [!IMPORTANT]
> The API returns timezone entries with an `identifier` field. Entries with null values are filtered out on the client side. This is a known backend behavior — the null-safety checks are critical.

<a name="extended-profile"></a>
## Extended Profile

Gated by `MagicStarterConfig.hasExtendedProfileFeatures()` (`magic_starter.features.extended_profile`).

When enabled, the profile form includes additional fields:

- **Phone** — optional phone number
- **Timezone** — async search via `/timezones` API
- **Language** — locale selection from `MagicStarter.localeOptions`

These fields are conditionally included in the `doUpdateProfile()` payload — only non-empty values are sent:

```dart
final data = <String, dynamic>{
  'name': name,
  'email': email,
  if (phone != null && phone.isNotEmpty) 'phone': phone,
  if (timezone != null && timezone.isNotEmpty) 'timezone': timezone,
  if (language != null && language.isNotEmpty) 'language': language,
};
```

<a name="newsletter"></a>
## Newsletter

Gated by `MagicStarterConfig.hasNewsletterFeatures()` (`magic_starter.features.newsletter`).

`MagicStarterNewsletterController` manages subscription state independently from the profile controller:

```dart
// Fetch current subscription status
await MagicStarterNewsletterController.instance.getNewsletterStatus();

// Update subscription
await MagicStarterNewsletterController.instance.updateNewsletterSubscription(
  subscribe: true,
);
```

The controller calls `GET /user/newsletter` and `PUT /user/newsletter` respectively. It follows the standard `MagicStateMixin` pattern — check `controller.isSuccess` or `controller.hasErrors` after each call.

> [!TIP]
> Customize the newsletter label shown in the UI via `MagicStarter.useNewsletterLabel('Subscribe to our updates')`.

<a name="delete-account"></a>
## Delete Account

Account deletion requires password confirmation and uses Laravel method spoofing:

```dart
final success = await MagicStarterProfileController.instance.doDeleteAccount(
  password: confirmedPassword,
);
```

The controller sends `POST /user` with `{'_method': 'DELETE', 'password': password}`. On success, it calls `Auth.logout()` and navigates to the login page.

> [!IMPORTANT]
> This action is irreversible. Always use a confirmation dialog that requires the user to re-enter their password. The dialog should handle inline errors via `setState()` — never auto-close on API failure.

<a name="two-factor-management"></a>
## Two-Factor Management

Two-factor enable, disable, confirm, and recovery code management are handled by `MagicStarterProfileController`. See the [Authentication - Two-Factor Authentication](authentication.md#two-factor-authentication) section for full details.

Key profile-side getters:

```dart
// Check if 2FA is currently enabled
final enabled = controller.isTwoFactorEnabled;
```

<a name="gate-abilities"></a>
## Gate Abilities

The service provider auto-registers 9 `starter.*` Gate abilities that control section visibility in the profile view. These abilities let the host app fine-tune which sections a specific user can see, beyond the global feature flags:

| Ability | Controls |
|---------|----------|
| `starter.update-profile-photo` | Profile photo upload/remove section |
| `starter.update-email` | Email field in profile information |
| `starter.update-phone` | Phone and country code in extended profile |
| `starter.update-password` | Password change section |
| `starter.verify-email` | Email verification banner |
| `starter.manage-two-factor` | Two-factor authentication section |
| `starter.manage-newsletter` | Newsletter preferences section |
| `starter.logout-sessions` | Logout/revoke buttons in browser sessions |
| `starter.delete-account` | Account deletion section |

Feature flags control whether the feature exists; Gate abilities control whether a specific user can access it.

<a name="controller"></a>
## Controller

`MagicStarterProfileController` is accessed via the singleton:

```dart
final controller = MagicStarterProfileController.instance;
```

Key patterns:

- **`withoutNotifying()`** — wraps async actions to suppress `notifyListeners()` during form-level loading. The `_suppressNotifications` flag is set to `true` before the action and restored in a `finally` block.
- **Return type** — all mutation methods return `bool` (or `Map?` for 2FA enable) so the calling view can branch without reading controller state.
- **`Auth.restore()`** — called after every successful mutation that changes the user model (profile update, photo change, password change).

<a name="view"></a>
## View

The profile settings view is registered under the key `profile.settings` and rendered inside `AppLayout`:

```dart
MagicStarter.view.make('profile.settings');
```

The view uses multiple techniques for fine-grained reactivity:

- **`ValueListenableBuilder`** — for controller `ValueNotifier` fields (e.g., session list, 2FA state).
- **Section-level `ValueNotifier<bool>`** — local loading indicators (`_photoLoading`, `_emailVerificationLoading`) for independent section spinners.
- **Multiple `MagicFormData` instances** — each section (profile info, password, extended) has its own form. Field names must not collide across forms.
- **Feature-gated spreads** — sections are conditionally rendered at build time:

```dart
if (MagicStarterConfig.hasProfilePhotoFeatures()) ...[
  _buildPhotoSection(),
],
if (MagicStarterConfig.hasSessionsFeatures()) ...[
  _buildSessionsSection(),
],
```

---

**Related links:**

- [Authentication](https://magic.fluttersdk.com/packages/starter/authentication)
- [Configuration](https://magic.fluttersdk.com/packages/starter/configuration)
- [Teams](https://magic.fluttersdk.com/packages/starter/teams)
