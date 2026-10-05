# Connected Accounts

- [Introduction](#introduction)
- [Requirements](#requirements)
- [The Page](#the-page)
- [Connecting a Provider](#connecting-a-provider)
- [Disconnecting a Provider](#disconnecting-a-provider)
- [Controller Methods](#controller-methods)
- [User Data](#user-data)
- [Overriding the Page](#overriding-the-page)

<a name="introduction"></a>
## Introduction

Connected accounts is a settings sub-page where a signed-in user links Google, Apple, GitHub or Microsoft to the account they already have, or removes a link. It is drilled into from the Security group of the Settings hub and stacked over it.

<a name="requirements"></a>
## Requirements

The route exists while `magic_starter.features.social_login` is `true`. It is registered on the feature alone: the app's bridge is set by a provider that boots after the one that registers routes, so the route cannot wait for it. The hub row additionally needs a bridge registered with `MagicStarter.useSocialAuth(...)` (see [Social Login](authentication.md#social-login)); a page opened without one lists no provider.

The route is `MagicStarterConfig.settingsConnectedAccountsRoute()`, `<profile_prefix>/security/connected-accounts` (`/settings/security/connected-accounts` by default), titled `magic_starter.titles.connected_accounts`. The view registry key is `settings.security.connected_accounts`. The backend is `magic-starter-laravel` with its `social-login` feature on: `POST /user/social-accounts/link-ticket` and `DELETE /user/social-accounts/{provider}`.

<a name="the-page"></a>
## The Page

One row per provider the bridge offers (`MagicStarterSocialAuth.providers()`), with the provider's icon and label.

| State | Row shows | Action |
|---|---|---|
| Linked (an entry in `social_accounts` with `revoked_at` null) | The address the provider was linked with (`email_at_link`) | **Disconnect** |
| Not linked | Nothing more | **Connect** |

A link the provider revoked (`revoked_at` set) is treated as not linked: it no longer counts as a way to sign in. The footer explains that the account always keeps at least one way to sign in. A refusal appears as a sentence above the list.

<a name="connecting-a-provider"></a>
## Connecting a Provider

A linked identity is a new way into the account, so **Connect** confirms the user's identity first.

1. [`confirmIdentity`](identity-confirmation.md) asks for the proof the account can give (the password, a TOTP code or a provider confirmation; none for a guest). The proof is minted for this attempt only.
2. `MagicStarterProfileController.beginSocialConnect(provider, proof:)` asks the bridge to begin: the network half (the backend link ticket) happens here, and it answers the call that opens the provider.
3. On iOS and Android the provider opens at once. **On the web the page shows a "Continue with <provider>" button instead**, because a popup opened after the awaits behind steps 1 and 2 is blocked as not user-initiated; the user's tap runs the opener.
4. `doConnectSocialAccount(opener)` runs the opener, then `Auth.restore()` so the new link shows.

Every retry starts over at step 1: a new proof, a new link ticket, a new PKCE pair. A cancelled flow shows nothing. A refusal shows its `social.<code>` sentence: `social_email_taken`, `social_account_taken` (the provider account is already linked to another user, or the caller already holds another account of that provider), `step_up_required`, `flow_expired`.

<a name="disconnecting-a-provider"></a>
## Disconnecting a Provider

**Disconnect** calls `doDisconnectSocialAccount(provider)`, which sends `DELETE /user/social-accounts/{provider}` and restores the user. No proof is asked.

The last way to sign in cannot be removed. For an account with no password and at most one active link, the page disables **Disconnect** as a courtesy and shows the `social.last_login_method` sentence. The backend holds that line whatever the page shows (422 `last_login_method`), and the refusal is read by its `code`. Set a password first (see [Set a Password](set-password.md)) or link another provider.

<a name="controller-methods"></a>
## Controller Methods

On `MagicStarterProfileController`:

| Method | Does |
|---|---|
| `doDisconnectSocialAccount(provider)` | `DELETE /user/social-accounts/{provider}`, then `Auth.restore()`. Returns `true` on success. |
| `beginSocialConnect(provider, {proof})` | Asks the bridge to begin a connect; answers the opener, or `null` when the bridge refused or the user backed out. |
| `doConnectSocialAccount(opener)` | Runs the opener, then `Auth.restore()`. Calls the opener before anything is awaited, so call it straight from a tap on the web. |

<a name="user-data"></a>
## User Data

`MagicStarterAuthUser` carries what the page reads:

| Getter | Source | Meaning |
|---|---|---|
| `hasPassword` | `has_password` | Whether the account can sign in with a password. `true` when a backend that predates social login does not send the field. |
| `isGuest` | `is_guest` | A device-bound guest account. |
| `socialAccounts` | `social_accounts` | Linked identities: `provider`, `email_at_link`, `created_at`, `revoked_at`. |
| `deletionScheduledAt` | `deletion_scheduled_at` | When a scheduled account deletion runs, or `null`. |

<a name="overriding-the-page"></a>
## Overriding the Page

Replace the view through the registry like any other starter screen:

```dart
MagicStarter.view.register(
  'settings.security.connected_accounts',
  () => const MyConnectedAccountsView(),
);
```

See [View Registry](../architecture/view-registry.md).
