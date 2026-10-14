# Support

- [Introduction](#introduction)
- [Enabling the Desk](#enabling-the-desk)
- [Screens](#screens)
- [The AI Desk](#the-ai-desk)
- [Topics](#topics)
- [Live Updates](#live-updates)
- [Contact Sales](#contact-sales)
- [Rating a Resolved Conversation](#rating-a-resolved-conversation)
- [Attachments](#attachments)
- [Screenshot and Client Info](#screenshot-and-client-info)
- [The Feedback Card](#the-feedback-card)
- [Store Review](#store-review)
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

Five further flags build on it. All default to `false`, and the first four need the backend to turn on the feature of the same name (`Features::supportCsat()`, `supportFeedback()`, `supportAttachments()`, `supportDiagnostics()`) because they call routes and fields it adds:

```dart
'features': {
  'support': true,
  'support_csat': true,
  'support_feedback': true,
  'support_attachments': true,
  'support_diagnostics': true,
  'store_review': true,
},
```

| Flag | Adds |
|------|------|
| `support_csat` | A thumbs rating under a resolved thread |
| `support_feedback` | `MagicStarterFeedbackCard`, a "Send feedback" page and menu item |
| `support_attachments` | Image and PDF files on a new conversation and on a reply, and in the thread |
| `support_diagnostics` | Client info and a previewed screenshot on a new conversation |
| `store_review` | The native review prompt and a "Rate us" menu item (client only; the backend has no counterpart) |

`starter:install --features=support` adds `registerMagicStarterSupportRoutes();` to `route_service_provider.dart`, `starter:uninstall` removes it, and `starter:doctor` warns when the feature is on and the call is missing.

<a name="screens"></a>
## Screens

| Path | View key | What it shows |
|------|----------|---------------|
| `/support` | `support.index` | The user's conversations in an Open and a Resolved tab, newest activity first. Each row shows the sender and a preview of the last message, a status badge and an unread dot when staff or the AI wrote since the last read. A "Load more" button reads the next page (20 a page); a refresh rereads every page already loaded, so the poll never collapses them, and the Resolved tab offers "Load more" instead of an empty claim while pages remain |
| `/support/new` | `support.create` | Topic chips and a message with a character counter, posted with source `in_app`. A "How it works" card sits beside the form on a wide screen and collapses to one line above it on a phone |
| `/support/:id` | `support.thread` | Chat bubbles by who wrote them, activity lines for handoffs, and a composer docked at the bottom |

`/support/new` and `/support/:id` are pushed (`.stacked()`), so the back gesture returns to the list. Opening a thread that has an unread reply sends a seen receipt and clears the dot; a thread with nothing unread sends none.

All three screens share one `MagicStarterSupportController`. A thread read that answers after the reader has already opened another thread is dropped, so a slow response never puts one conversation's messages under another's composer. A page of the list that answers after the list was reloaded is dropped the same way, and a row already held is not added twice when new activity moves it between two page reads.

<a name="the-ai-desk"></a>
## The AI Desk

When the backend has an AI responder bound, a verified customer's conversation starts with the AI answering. The screens read three fields the backend computes and never guess at them:

| Field | Meaning | What the screen shows |
|-------|---------|-----------------------|
| `awaiting_ai` | Pending, and the newest customer message has no AI answer yet | An "AI answering" pill, a typing bubble in the thread and the line "Our AI answers right away and hands off to the team when needed" above the composer |
| `waiting_on_team` | Open and waiting on a person | A "Team answering" pill and the line "Our team usually replies within a few hours" above the composer |
| neither | Answered, or finished | The plain "Open" badge, or the "Resolved" pill |

"AI answering", "Team answering" and "Resolved" are soft tinted pills with a leading dot (`bg-ai-soft`, `bg-warning-soft`, `bg-success-soft`); the assistant's bubble carries a 2px `border-ai` left edge. A customer message sent on a `pending` conversation flips the local copy to `awaiting_ai` at once, so the typing bubble shows before the next refetch.

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

The backend derives the subject from the first line of the message (the topic is shown beside it as a tag), so the create form asks for none; `createConversation` still accepts an optional `subject`.

The counter under the message field reads `magic_starter.support.message_max_length` (`MagicStarterConfig.supportMessageMaxLength()`, default 2000). It is display only: set it to the backend's `support.message_max_length`, which is what refuses a longer message.

On a phone the thread hides the bottom navigation, like a chat screen: `registerMagicStarterSupportRoutes()` registers it in its own route group (`layoutId: 'app.chat'`) wrapped in `MagicStarterHideBottomNav`. The list and the create page keep it.

<a name="live-updates"></a>
## Live Updates

The list and the thread refetch when the backend broadcasts `support.conversation.updated` on the private channel `App.Models.User.{id}`. They subscribe through `BroadcastListeners`, which the notification bell shares, so neither listener replaces the other. With no broadcast driver configured, or while the socket is down, both screens poll every 30 seconds instead.

<a name="contact-sales"></a>
## Contact Sales

With the support feature on, the billing screen's custom tier ("Contact sales") opens a conversation with source `contact_sales` and the subject `Contact sales: <plan name>`, then lands on its thread. It names no topic: the backend files a Contact sales conversation under `sales`. With the feature off the button keeps its toast. A refusal toasts the backend's message and stays on the billing screen.

<a name="rating-a-resolved-conversation"></a>
## Rating a Resolved Conversation

With `support_csat` on, a resolved thread ends with "How did we do?": a thumbs up or down and an optional comment (1000 characters at most), posted to `support/conversations/{id}/rating`. The block shows when the backend reports `can_rate`, or when the conversation already carries a `rating`, which the customer can then change: the backend overwrites it for as long as the conversation stays resolved. A down rating alerts staff on the backend, once per resolution. `MagicStarterSupportController.rate()` does the write and a refusal lands in `getError('rating')`.

<a name="attachments"></a>
## Attachments

With `support_attachments` on, the create form and the thread composer get an "Attach files" button, and a message that has files may have no text. A bubble lists its files: an image shows as a thumbnail that opens full size, a PDF as a row that opens in the system viewer.

The files go up in the same request as the message. As soon as one is attached the request is `multipart/form-data` with one part per file (`attachments[0]` to `attachments[2]`); without a file it stays JSON. The controller refuses a pick the backend would refuse before it uploads it, from these keys:

```dart
'support': {
  'attachments': {
    'max_files': 3,
    'max_bytes': 5 * 1024 * 1024,
    'extensions': ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
  },
},
```

The defaults match the backend's `support.attachments` (`max_files`, `max_kb`, `types`); a host that changes one changes the other, since the backend enforces its own. An image is read with the bearer token (`MagicStarterSupportController.attachmentHeaders()`), because the file endpoint answers to the token alone. A PDF asks for a 60 second signed url (`attachmentLink()`) and hands it to the system viewer.

<a name="screenshot-and-client-info"></a>
## Screenshot and Client Info

With `support_diagnostics` on, a new conversation carries two things the customer did not type.

**Client info** (`MagicStarterSupportClientContext.collect()`), sent as `client_context[...]`: `route`, `app_version`, `build_number`, `platform`, `os_version`, `locale` and `timezone`. Each value is cut to 120 characters, the route loses its query and fragment, and a value the device cannot tell is left out.

**A screenshot** of the screen the customer left to ask for help, taken once as navigation crosses into a support route (the profile menu's Support item, Contact sales, a link of your own). The create form shows it full width before anything is sent, and "Remove screenshot" keeps it off this conversation and out of memory. It is sent as `screenshot.png` only if kept. Wrap the app once so there is a frame to capture:

```dart
MagicApplication(
  builder: (context, child) => MagicStarterScreenCapture.wrap(child!),
)
```

`registerMagicStarterSupportRoutes()` adds the observer that tells whether a dialog is open, so it has to run before the router is built, like every route registration.

A screenshot is never taken of a screen on the deny-list, nor while a dialog or popup is open, and a refused capture also empties the held one, so an older picture is never offered for a newer visit. The starter's own list is the profile, security, two-factor challenge, billing and teams routes. An entry matches its path and everything under it, and a `:param` or `*` segment matches any one segment. A host adds the screens that show something private of its own:

```dart
'diagnostics': {
  'deny_capture_routes': ['/reports/:id', '/vault'],
},
```

The bytes live in memory only and are dropped on the next sign-in. Turn `support_attachments` on with this flag: the backend serves a screenshot through the attachment endpoint, and one it stores but cannot serve is read by nobody.

<a name="the-feedback-card"></a>
## The Feedback Card

With `support_feedback` on, `MagicStarterFeedbackCard` asks "How likely are you to recommend us?" on a 0 to 10 scale with an optional comment (2000 characters at most). Place it yourself, on the screen where a customer finishes something:

```dart
const MagicStarterFeedbackCard()
```

It renders nothing until the backend says the account is due (`GET support/feedback`, which the backend paces by account age and time since the last answer), and nothing for a guest or a signed-out visitor. "Not now" records a dismissal, which paces it like an answer. A score the backend counts as low opens, or continues, a conversation, and the thanks line then links to it. The backend never lets the AI desk answer that conversation.

The same form is the "Send feedback" page (`/support/feedback`, view key `support.feedback`) behind a profile menu item. That page and `MagicStarterFeedbackCard(onDemand: true)` skip the eligibility read and the dismissal. A guest or an account with an unverified email is not offered the menu item, since the backend refuses it.

<a name="store-review"></a>
## Store Review

With `store_review` on, the app can ask for the native store review sheet and offer a "Rate us" link.

Ask for the review yourself, at a moment that went well (a first check passed, a tenth incident resolved):

```dart
await MagicStarterStoreReview.maybeRequest();
```

`maybeRequest()` stays quiet unless every rule holds:

- never on the web;
- never for a guest or a signed-out user;
- never in the first 7 days of an account (`magic_starter.store_review.min_account_days`);
- at most once per 120 days on this device (`magic_starter.store_review.interval_days`, remembered in the `Vault`);
- never in a run where the feedback card was shown, so a customer is not asked a question and then asked for a review in the same session;
  With `support_feedback` on, the call first waits for the card's eligibility read (shared with the card) and stays quiet when the card is due, even if the card has not rendered yet;
- never from a button. The platforms decide whether a sheet appears and say nothing back, so a button wired to it would sometimes do nothing. Call it from your own milestone.

It answers whether the platform was asked, not whether a sheet showed. "Rate us" in the profile menu is the button instead: it calls `MagicStarterStoreReview.openStoreListing()`, which opens the store page and has no quota. It shows on Android, and on iOS and macOS once the App Store id is set:

```dart
'store_review': {
  'app_store_id': '1234567890',
  'min_account_days': 7,
  'interval_days': 120,
},
```

Android finds its listing from the package name. The feature uses the `in_app_review` package; the client info uses `package_info_plus` for the version and build number. Both come with `magic_starter`, and a host with no other use for them adds nothing.

<a name="overriding-a-screen"></a>
## Overriding a Screen

Each screen resolves through the view registry, so a host replaces one the usual way:

```dart
MagicStarter.view.register('support.thread', () => const MySupportThreadView());
```

`support.feedback` joins the three screens above when `support_feedback` is on.

Copy lives under `magic_starter.support.*`, `magic_starter.nav.support` and `magic_starter.titles.support*`. A host that published its own `en.json` adds those keys from `assets/stubs/install/en.stub`.
