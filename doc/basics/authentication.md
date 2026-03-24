# Authentication

- [Introduction](#introduction)
- [Login Flow](#login-flow)
- [Registration](#registration)
- [Forgot Password](#forgot-password)
- [Reset Password](#reset-password)
- [Two-Factor Authentication](#two-factor-authentication)
    - [Two-Factor Challenge](#two-factor-challenge)
    - [Enabling Two-Factor](#enabling-two-factor)
    - [Recovery Codes](#recovery-codes)
- [Social Login](#social-login)
- [OTP Flow](#otp-flow)
    - [Sending an OTP](#sending-an-otp)
    - [Verifying an OTP](#verifying-an-otp)
- [Identity Modes](#identity-modes)
- [Feature Gates](#feature-gates)
- [Controllers](#controllers)
- [Views](#views)

<a name="introduction"></a>
## Introduction

The Magic Starter authentication module provides a complete, feature-gated authentication system built on top of the Magic Framework. It covers login, registration, password reset, two-factor authentication, social login, phone OTP, and guest authentication — all driven by opt-in configuration flags.

Three controllers split the responsibilities:

| Controller | Scope |
|-----------|-------|
| `MagicStarterAuthController` | Login, register, forgot/reset password, two-factor challenge, logout |
| `MagicStarterGuestAuthController` | Device-ID-based guest login |
| `MagicStarterOtpController` | Phone OTP send and verify |

Every controller follows the Magic singleton pattern (`static T get instance => Magic.findOrPut(T.new)`) and mixes in `MagicStateMixin`, `ValidatesRequests`, and `NavigatesRoutes`.

> [!NOTE]
> All auth routes are registered under the configurable prefix `MagicStarterConfig.authPrefix()` (default `/auth`). Guest-facing routes use `GuestLayout`; post-login routes use `AppLayout`.

<a name="login-flow"></a>
## Login Flow

Call `MagicStarterAuthController.instance.doLogin()` with the user's credentials. The controller builds the identity payload based on the active [identity mode](#identity-modes), sends `POST /auth/login`, and handles the response:

```dart
await MagicStarterAuthController.instance.doLogin(
  email: form['email'],
  phone: form['phone'],
  password: form['password'],
  rememberMe: form.value<bool>('remember_me'),
);
```

The login flow has three possible outcomes:

1. **Success** — the controller extracts `token` and `user` from the nested `data` key, calls `Auth.login()`, sets success state, and navigates to `MagicStarterConfig.homeRoute()`.
2. **Two-factor required** — the controller detects the challenge flag and navigates to `MagicStarterConfig.twoFactorChallengeRoute()` with the encrypted token as a query parameter. No login occurs yet.
3. **Failure** — `handleApiError()` sets the error state with a localized fallback message.

> [!IMPORTANT]
> Two-factor detection checks **both** `response['two_factor']` and `response['data']['two_factor']`. Some backends nest the flag differently, and the controller handles both variants.

A `_isSubmitting` guard prevents double-submit — concurrent calls to `doLogin()` are silently discarded.

<a name="registration"></a>
## Registration

`doRegister()` collects `name`, `email`/`phone` (per identity mode), `password`, and `password_confirmation`:

```dart
await MagicStarterAuthController.instance.doRegister(
  name: form['name'],
  email: form['email'],
  phone: form['phone'],
  password: form['password'],
  passwordConfirmation: form['password_confirmation'],
  subscribeNewsletter: form.value<bool>('subscribe_newsletter'),
);
```

When the `newsletter` feature is active and `subscribeNewsletter` is `true`, the payload includes `subscribe_newsletter: true`.

The response determines the post-registration flow:

- **Auto-login** — when the server returns `token` + `user` in `data`, the controller calls `Auth.login()` and navigates home.
- **Email verification required** — when no credentials are returned, the controller navigates to the login page so the user can verify their email first.

> [!TIP]
> Registration is gated by `MagicStarterConfig.hasRegistrationFeatures()`. When disabled, the registration route is not registered and the view is inaccessible.

<a name="forgot-password"></a>
## Forgot Password

Sends a password reset link via `POST /auth/forgot-password`:

```dart
await MagicStarterAuthController.instance.doForgotPassword(
  email: form['email'],
);
```

On success, the controller sets success state. The view should display a confirmation message. No navigation occurs — the user stays on the same page.

<a name="reset-password"></a>
## Reset Password

Completes the password reset using the token from the email link. The view extracts the token and email from query parameters via `MagicRouter.instance.queryParameter()`:

```dart
final token = MagicRouter.instance.queryParameter('token') ?? '';
final email = MagicRouter.instance.queryParameter('email') ?? '';

await MagicStarterAuthController.instance.doResetPassword(
  token: token,
  email: email,
  password: form['password'],
  passwordConfirmation: form['password_confirmation'],
);
```

On success, the controller sets success state. The view should display a confirmation and provide a link back to login.

<a name="two-factor-authentication"></a>
## Two-Factor Authentication

Two-factor authentication spans two contexts: **challenging** (during login) and **managing** (in profile settings).

<a name="two-factor-challenge"></a>
### Two-Factor Challenge

When `doLogin()` detects a two-factor requirement, it navigates to the challenge view with the encrypted `two_factor_token`. The user enters either a TOTP code from their authenticator app or a recovery code:

```dart
await MagicStarterAuthController.instance.doTwoFactorChallenge(
  twoFactorToken: token,
  code: form['code'],         // TOTP from authenticator
  // OR
  recoveryCode: form['recovery_code'],  // One-time recovery code
);
```

Exactly one of `code` or `recoveryCode` must be provided — the controller asserts this invariant. On success, the flow completes the same as a normal login: `Auth.login()` followed by navigation to home.

<a name="enabling-two-factor"></a>
### Enabling Two-Factor

Enabling 2FA is a multi-step process managed by `MagicStarterProfileController`:

1. **Enable** — `doEnableTwoFactor(password:)` calls `POST /two-factor-authentication`. Returns a map containing `secret`, `qr_url`, `qr_svg`, and `recovery_codes`.
2. **Confirm** — `doConfirmTwoFactor(code:)` calls `POST /two-factor-authentication/confirm` with the TOTP code from the authenticator app.
3. **Disable** — `doDisableTwoFactor(password:)` uses Laravel method spoofing (`{'_method': 'DELETE'}`) via `Http.post()`.

> [!NOTE]
> The `isTwoFactorEnabled` getter reads `two_factor_enabled` from the authenticated user model. Use it to conditionally render the enable/disable UI.

<a name="recovery-codes"></a>
### Recovery Codes

Recovery codes can be viewed and regenerated via `MagicStarterProfileController`:

```dart
// View existing codes (requires password)
final codes = await controller.getRecoveryCodes(password: currentPassword);

// Regenerate codes (requires password)
final newCodes = await controller.doRegenerateRecoveryCodes(password: currentPassword);
```

Both methods call endpoints under `/two-factor-recovery-codes` and require the current account password for sudo-mode confirmation.

<a name="social-login"></a>
## Social Login

Social login is feature-gated via `magic_starter.features.social_login`. When enabled, the host app registers a builder that renders OAuth provider buttons:

```dart
MagicStarter.useSocialLogin((context, isLoading) {
  return SocialLoginButtons(
    onGoogle: () => controller.doSocialLogin('google'),
    onApple: () => controller.doSocialLogin('apple'),
  );
});
```

The builder is rendered on the login and register views when `MagicStarter.hasSocialLogin` returns `true`. The actual OAuth flow (token exchange, provider SDK calls) is implemented by the host app — the starter plugin only provides the UI integration point.

> [!TIP]
> Enable the feature flag **and** register a builder. The flag alone does not render anything — `MagicStarter.useSocialLogin()` must be called during app boot.

<a name="otp-flow"></a>
## OTP Flow

The phone OTP flow is a two-step process managed by `MagicStarterOtpController`. It requires both `guest_auth` and `phone_otp` feature flags to be enabled.

<a name="sending-an-otp"></a>
### Sending an OTP

Step 1 collects the phone number and sends the OTP via `POST /auth/otp/send`:

```dart
await MagicStarterOtpController.instance.sendOtp(
  phone: '+905301234567', // E.164 format
);
```

On success, the controller transitions from `OtpStep.phoneInput` to `OtpStep.codeInput` and stores the phone number internally for step 2.

<a name="verifying-an-otp"></a>
### Verifying an OTP

Step 2 verifies the 6-digit code via `POST /auth/otp/verify`:

```dart
await MagicStarterOtpController.instance.verifyOtp(
  phone: controller.phoneNumber ?? '',
  code: form['code'],
);
```

On success, the controller calls `Auth.login()` with the returned token and navigates home. Call `controller.resetToPhoneInput()` to restart the flow.

> [!NOTE]
> The `OtpStep` enum drives the view state. Check `controller.step` to determine which input (phone or code) to display.

<a name="identity-modes"></a>
## Identity Modes

The starter supports three identity modes configured via `magic_starter.auth.email` and `magic_starter.auth.phone`:

| `auth.email` | `auth.phone` | Mode | Behavior |
|:---:|:---:|---|---|
| `true` | `false` | Email-only (default) | Only `email` field is sent in the payload |
| `false` | `true` | Phone-only | Only `phone` field is sent in the payload |
| `true` | `true` | Both | Both fields sent when non-empty; phone takes precedence when resolving a single identity |

The `_applyIdentityToPayload()` helper centralizes this logic across login and registration. In "both" mode, every non-empty identity field is included so the backend receives the full picture.

```dart
// Config for phone-only mode
Config.set('magic_starter.auth.email', false);
Config.set('magic_starter.auth.phone', true);
```

> [!IMPORTANT]
> When both modes are enabled, phone takes precedence for single-identity resolution. If neither `email` nor `phone` is provided, the login controller sets an error and returns early.

<a name="feature-gates"></a>
## Feature Gates

Authentication features are controlled by these configuration toggles. All default to `false`.

| Config Key | Gate Method | Affects |
|-----------|------------|---------|
| `magic_starter.features.registration` | `hasRegistrationFeatures()` | Register view and route |
| `magic_starter.features.social_login` | `hasSocialLoginFeatures()` | Social login buttons on login/register |
| `magic_starter.features.two_factor` | `hasTwoFactorFeatures()` | 2FA enable/disable in profile, challenge route |
| `magic_starter.features.guest_auth` | `hasGuestAuthFeatures()` | Guest login flow |
| `magic_starter.features.phone_otp` | `hasPhoneOtpFeatures()` | Phone OTP send/verify |
| `magic_starter.features.newsletter` | `hasNewsletterFeatures()` | Newsletter checkbox on registration |
| `magic_starter.features.email_verification` | `hasEmailVerificationFeatures()` | Email verification flow |
| `magic_starter.auth.email` | `emailIdentity()` | Email field in login/register (default `true`) |
| `magic_starter.auth.phone` | `phoneIdentity()` | Phone field in login/register (default `false`) |

> [!TIP]
> Feature-gated routes throw `StateError` if accessed when the corresponding feature is disabled. Always check the config before navigating programmatically.

<a name="controllers"></a>
## Controllers

| Controller | Singleton | Key Methods |
|-----------|----------|-------------|
| `MagicStarterAuthController` | `.instance` | `doLogin()`, `doRegister()`, `doForgotPassword()`, `doResetPassword()`, `doTwoFactorChallenge()`, `logout()` |
| `MagicStarterGuestAuthController` | `.instance` | `doGuestLogin()`, `isGuestUser`, `getStoredDeviceId()` |
| `MagicStarterOtpController` | `.instance` | `sendOtp()`, `verifyOtp()`, `resetToPhoneInput()`, `step`, `phoneNumber` |

All controllers use the `NavigatesRoutes` mixin for safe navigation. Never call `context.go()` directly in a controller — the navigator context may not be mounted. The mixin checks `MagicRouter.instance.navigatorKey.currentContext` and no-ops when unavailable.

After successful login or registration, `Auth.login()` stores the token and user model. Call `Auth.restore()` when you need to refresh the user model from the backend (e.g., after profile updates).

<a name="views"></a>
## Views

All views extend `MagicStatefulView<ControllerType>` and are registered in the view registry with string keys:

| Registry Key | View | Layout |
|-------------|------|--------|
| `auth.login` | `LoginView` | `GuestLayout` |
| `auth.register` | `RegisterView` | `GuestLayout` |
| `auth.forgot_password` | `ForgotPasswordView` | `GuestLayout` |
| `auth.reset_password` | `ResetPasswordView` | `GuestLayout` |
| `auth.two_factor_challenge` | `TwoFactorChallengeView` | `GuestLayout` |
| `auth.otp_verify` | `OtpVerifyView` | `GuestLayout` |

Views are instantiated through the registry (`MagicStarter.view.make('auth.login')`) and wrapped in the appropriate layout (`MagicStarter.view.makeLayout('guest', child: view)`). The host app can override any view by registering a custom builder under the same key.

Views contain zero business logic — all async operations, state management, and navigation decisions live in the controllers.

---

**Related links:**

- [Configuration](https://magic.fluttersdk.com/packages/starter/configuration)
- [Profile Management](https://magic.fluttersdk.com/packages/starter/profile)
- [Teams](https://magic.fluttersdk.com/packages/starter/teams)
