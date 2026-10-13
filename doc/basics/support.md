# Support

- [Introduction](#introduction)
- [Enabling the Desk](#enabling-the-desk)
- [Screens](#screens)
- [The AI Desk](#the-ai-desk)
- [Topics](#topics)
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

The backend has to enable the same feature (`Features::support()` in `config/magic-starter.php`); with it off the endpoints do not exist and the screens show their error state. The screens below need `magic-starter-laravel` with the AI desk columns (`topic`, `awaiting_ai`, `last_message` and the paginated list); an older backend still requires a `subject`, which the create form no longer sends.

`starter:install --features=support` adds `registerMagicStarterSupportRoutes();` to `route_service_provider.dart`, `starter:uninstall` removes it, and `starter:doctor` warns when the feature is on and the call is missing.

<a name="screens"></a>
## Screens

| Path | View key | What it shows |
|------|----------|---------------|
| `/support` | `support.index` | The user's conversations in an Open and a Resolved tab, newest activity first. Each row shows the sender and a preview of the last message, a status badge and an unread dot when staff or the AI wrote since the last read. A "Load more" button reads the next page (20 a page) |
| `/support/new` | `support.create` | Topic chips and a message with a character counter, posted with source `in_app`. A "How it works" card sits beside the form on a wide screen and collapses to one line above it on a phone |
| `/support/:id` | `support.thread` | Chat bubbles by who wrote them, activity lines for handoffs, and a composer docked at the bottom |

`/support/new` and `/support/:id` are pushed (`.stacked()`), so the back gesture returns to the list. Opening a thread that has an unread reply sends a seen receipt and clears the dot; a thread with nothing unread sends none.

All three screens share one `MagicStarterSupportController`. A thread read that answers after the reader has already opened another thread is dropped, so a slow response never puts one conversation's messages under another's composer. A page of the list that answers after the list was reloaded is dropped the same way, and a row already held is not added twice when new activity moves it between two page reads.

<a name="the-ai-desk"></a>
## The AI Desk

When the backend has an AI responder bound, a verified customer's conversation starts with the AI answering. The screens read three fields the backend computes and never guess at them:

| Field | Meaning | What the screen shows |
|-------|---------|-----------------------|
| `awaiting_ai` | Pending, and the newest customer message has no AI answer yet | An "AI answering" badge, a typing bubble in the thread and the line "Our AI answers right away and hands off to the team when needed" above the composer |
| `waiting_on_team` | Open and waiting on a person | A "Team answering" badge and the line "Our team usually replies within a few hours" above the composer |
| neither | Answered, or finished | The plain "Open" or "Resolved" badge |

`pending` and `snoozed` are the desk's own bookkeeping and read as open. A message from the assistant carries `sender_type` `ai` and its name; it renders on the left with a sparkle avatar on `bg-ai-soft` and a chip under the bubble, a teammate shows their first name and photo or initials, and the customer sits on the right. A message with `kind` `activity` (the handoff line, a status change) renders as a centred divider line, not a bubble.

If the AI has been pending for 45 seconds, counted from when the screen first saw it pending, the typing bubble gives way to "This is taking longer than usual. If the AI cannot answer, our team will take over." The backend's sweeper hands the turn to staff after a few minutes, so a stranded thread does not stay in the typing state.

The composer sits in the page scaffold's `footer`, above the keyboard. On web and desktop Enter sends and Shift+Enter breaks the line (a pending IME composition keeps Enter); on a phone Enter breaks the line and the round send button sends. A write the backend refuses for a reason other than validation shows under the field as `writeError`.

<a name="topics"></a>
## Topics

A new conversation is filed under a topic. The chips come from `magic_starter.support.topics` (read by `MagicStarterConfig.supportTopics()`), which defaults to `billing`, `technical`, `account`, `sales` and `other`. The keys are wire values the backend validates against its own `support.topics`, so a topic added here has to exist there as well. A chip's label is `magic_starter.support.topic.<topic>`, and a topic a host added without translating it shows its key.

```dart
'support': {
  'topics': ['billing', 'technical', 'other'],
},
```

The backend derives the subject from the topic and the first line of the message, so the create form asks for none; `createConversation` still accepts an optional `subject`.

<a name="live-updates"></a>
## Live Updates

The list and the thread refetch when the backend broadcasts `support.conversation.updated` on the private channel `App.Models.User.{id}`. They subscribe through `BroadcastListeners`, which the notification bell shares, so neither listener replaces the other. With no broadcast driver configured, or while the socket is down, both screens poll every 30 seconds instead.

<a name="contact-sales"></a>
## Contact Sales

With the support feature on, the billing screen's custom tier ("Contact sales") opens a conversation with source `contact_sales` and the subject `Contact sales: <plan name>`, then lands on its thread. It names no topic: the backend files a Contact sales conversation under `sales`. With the feature off the button keeps its toast. A refusal toasts the backend's message and stays on the billing screen.

<a name="overriding-a-screen"></a>
## Overriding a Screen

Each screen resolves through the view registry, so a host replaces one the usual way:

```dart
MagicStarter.view.register('support.thread', () => const MySupportThreadView());
```

Copy lives under `magic_starter.support.*`, `magic_starter.nav.support` and `magic_starter.titles.support*`. A host that published its own `en.json` adds those keys from `assets/stubs/install/en.stub`.
