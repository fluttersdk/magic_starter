# Set a Password

- [Introduction](#introduction)
- [The Page](#the-page)
- [doSetPassword](#dosetpassword)
- [Refusals](#refusals)

<a name="introduction"></a>
## Introduction

An account created through a provider has no password (`has_password` is `false`), so there is nothing to change. The Security password page becomes **Set password** for it, and the user can then also sign in with email and password.

<a name="the-page"></a>
## The Page

`MagicStarterPasswordView` reads `has_password` on every build:

| `has_password` | Page |
|---|---|
| `true` (or absent, on a backend that predates social login) | The change form: current, new and confirm password, `doUpdatePassword`. |
| `false` | **Set password**: new and confirm password only, with the `profile.set_password_description` footer. |

Submitting the set form confirms the user's identity first (see [Confirming Identity](identity-confirmation.md)): a first password is a new way into the account, so a password-less account steps up with a TOTP `code` or a `confirmation_token`, and a guest passes without a dialog. The dialog stays open while the backend refuses, so the user retries with a fresh proof. On success the user is restored, which flips `has_password` and with it the page from set to change.

<a name="dosetpassword"></a>
## doSetPassword

```dart
final success = await MagicStarterProfileController.instance.doSetPassword(
  password: form['password'],
  passwordConfirmation: form['password_confirmation'],
  proof: proof,
);
```

Sends `POST /user/password/set` with `password`, `password_confirmation` and the spread `proof`. The backend applies the same rules as a password change (at least 8 characters with letters, numbers and mixed case, confirmed). On success it calls `Auth.restore()`, shows the `profile.password_set` toast and sets success state; on a refusal it shows the `profile.password_set_failed` fallback or the refusal's own sentence.

<a name="refusals"></a>
## Refusals

| Code | Meaning | Client behaviour |
|---|---|---|
| `password_already_set` (422) | The account already has a password. | The user is restored; the page rebuilds with the change form. |
| `step_up_required` (422) | The proof was missing or spent. | The step-up dialog narrows to `accepts` and stays open. |

The mirror case: `PUT /user/password` on a password-less account answers 422 `password_not_set`, and the page rebuilds with the set form. Both are read by `code`.
