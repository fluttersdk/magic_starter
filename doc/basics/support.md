# Support

- [Introduction](#introduction)
- [Enabling the Desk](#enabling-the-desk)
- [Screens](#screens)
- [Live Updates](#live-updates)
- [Contact Sales](#contact-sales)
- [Overriding a Screen](#overriding-a-screen)

<a name="introduction"></a>
## Introduction

The support desk lets a signed-in customer write to your team and follow the answer without leaving the app. It is the client of `magic-starter-laravel`'s support API (`support/conversations`), which scopes every conversation to the user who opened it: a teammate asking for someone else's thread gets the same 404 as a missing one. Staff answer from the backend's admin panel; nothing on this side reads or writes another user's conversation.

<a name="enabling-the-desk"></a>
## Enabling the Desk

Turn the feature on in `lib/config/magic_starter.dart`:

```dart
'features': {
  'support': true,
},
```

Then register the routes from your route provider, beside the other starter routes:

```dart
registerMagicStarterAuthRoutes();
registerMagicStarterProfileRoutes();
registerMagicStarterTeamRoutes();
registerMagicStarterSupportRoutes();
```

The profile dropdown shows its Support item whenever the feature is on, so a host that enables the feature without registering the routes ships a menu item that leads nowhere. A host that draws its own account menu instead of `MSUserProfileDropdown` adds its own entry pointing at `MagicStarterConfig.supportRoute()`.

The backend has to enable the same feature (`Features::support()` in `config/magic-starter.php`); with it off the endpoints do not exist and the screens show their error state.

<a name="screens"></a>
## Screens

| Path | View key | What it shows |
|------|----------|---------------|
| `/support` | `support.index` | The user's conversations, newest activity first, with a status badge and an unread dot when staff wrote since the last read |
| `/support/new` | `support.create` | A subject and a message, posted with source `in_app` |
| `/support/:id` | `support.thread` | The messages by who wrote them and a composer |

`/support/new` and `/support/:id` are pushed (`.stacked()`), so the back gesture returns to the list. Opening a thread that has an unread staff reply sends a seen receipt and clears the dot; a thread with nothing unread sends none.

All three screens share one `MagicStarterSupportController`. A thread read that answers after the reader has already opened another thread is dropped, so a slow response never puts one conversation's messages under another's composer.

<a name="live-updates"></a>
## Live Updates

The list and the thread refetch when the backend broadcasts `support.conversation.updated` on the private channel `App.Models.User.{id}`. They subscribe through `BroadcastListeners`, which the notification bell shares, so neither listener replaces the other. With no broadcast driver configured, or while the socket is down, both screens poll every 30 seconds instead.

<a name="contact-sales"></a>
## Contact Sales

With the support feature on, the billing screen's custom tier ("Contact sales") opens a conversation with source `contact_sales` and the subject `Contact sales: <plan name>`, then lands on its thread. With the feature off the button keeps its toast. A refusal toasts the backend's message and stays on the billing screen.

<a name="overriding-a-screen"></a>
## Overriding a Screen

Each screen resolves through the view registry, so a host replaces one the usual way:

```dart
MagicStarter.view.register('support.thread', () => const MySupportThreadView());
```

Copy lives under `magic_starter.support.*`, `magic_starter.nav.support` and `magic_starter.titles.support*`. A host that published its own `en.json` adds those keys from `assets/stubs/install/en.stub`.
