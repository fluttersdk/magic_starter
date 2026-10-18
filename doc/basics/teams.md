# Teams

- [Introduction](#introduction)
- [Team Resolver](#team-resolver)
- [Creating Teams](#creating-teams)
- [Team Switching](#team-switching)
    - [The Billable Subject](#billable-subject)
    - [Price Format](#price-format)
    - [Free Trials](#free-trials)
    - [Changing a Web Plan](#changing-a-web-plan)
    - [Campaigns](#campaigns)
- [Invitation](#invitation)
    - [Sending Invitations](#sending-invitations)
    - [Accepting Invitations](#accepting-invitations)
    - [Canceling Invitations](#canceling-invitations)
- [Team Settings](#team-settings)
    - [Updating Team Name](#updating-team-name)
    - [Managing Members](#managing-members)
- [Feature Gate](#feature-gate)
- [Controller](#controller)
- [Views](#views)
- [Widget: MSTeamSelector](#widget-msteamselector)
- [Model: MagicStarterTeam](#model-magicstarterteam)

<a name="introduction"></a>
## Introduction

The teams module provides multi-tenancy support for Magic Starter applications. Users can create teams, invite members by email with role assignments, switch between teams, and manage team settings. The entire module is gated behind a single feature flag and relies on a **team resolver** pattern that bridges the host app's team model with the starter plugin's lightweight DTO.

> [!NOTE]
> All team routes are registered under `MagicStarterConfig.teamsPrefix()` (default `/teams`). Team routes require the `EnsureAuthenticated` middleware and render inside `AppLayout`.

<a name="team-resolver"></a>
## Team Resolver

The team resolver is the bridge between your application's team model and the starter plugin. Register it during app boot via `MagicStarter.useTeamResolver()`:

```dart
MagicStarter.useTeamResolver(
  currentTeam: () => User.current.currentTeam?.toMagicStarterTeam(),
  allTeams: () => User.current.allTeams
      .map((t) => t.toMagicStarterTeam())
      .toList(),
  onSwitch: (id) => MagicStarter.switchTeam('$id'),
);
```

The resolver provides three callbacks:

| Callback | Return Type | Purpose |
|----------|------------|---------|
| `currentTeam` | `MagicStarterTeam?` | Returns the user's currently active team |
| `allTeams` | `List<MagicStarterTeam>` | Returns all teams the user belongs to |
| `onSwitch` | `Future<void>` | Called when the user selects a different team |

The starter plugin reads these callbacks to populate the team selector dropdown, display the active team name, and handle team switching. Your app's Team model should provide a `toMagicStarterTeam()` conversion method.

> [!IMPORTANT]
> The team resolver must be registered before any team-related UI is rendered. Call `MagicStarter.useTeamResolver()` in your service provider's `boot()` method.

<a name="creating-teams"></a>
## Creating Teams

Create a new team via `MagicStarterTeamController.instance.doCreate()`:

```dart
final success = await MagicStarterTeamController.instance.doCreate(
  name: form['name'],
);
```

The controller sends `POST /teams` with the team name. On success:

1. The returned team `id` is stored in `currentTeamId.value`.
2. `Auth.restore()` is called to refresh the user model (which now includes the new team).
3. A toast confirmation is shown.

The create team view is registered under `teams.create` and accessible at `MagicStarterConfig.teamCreateRoute()` (default `/teams/create`).

<a name="team-switching"></a>
## Team Switching

Switch the active team via `MagicStarter.switchTeam()`, which answers whether the backend accepted it:

```dart
if (!await MagicStarter.switchTeam(teamId)) return;

MagicRoute.to('/projects/$projectId');
```

It goes through `MagicStarterTeamController.instance.switchTeam()`, which sends `PUT /user/current-team` with the target `team_id` and, on success, updates `currentTeamId.value` and applies the signed-in user the switch answers with, so the session is on the new team before the future completes. An answer without that user (an empty `data`, a team record) falls back to `Auth.restore()`. In an app that never calls `SessionScope.attach()`, the switch also resets every `SessionScoped` controller registered with `Magic` (team settings, billing, your own team screens). A refused switch answers `false` and leaves the session on the team it was on, so a caller that navigates after a switch (a deep link into another team's page) must check the answer first.

On success it also re-identifies the store rail as the paying subject (`StoreIdentitySync.syncNow()` from `magic_payments`), so a purchase made after the switch is not attributed to the team that was left. It identifies the team the switch was accepted for, not what the resolver reads at that moment: on the `Auth.restore()` fallback the cached user comes back first and the fresh one syncs in the background, so the resolver can still name the old team for a moment. A build without a store rail (web, desktop) identifies nothing. A refused switch identifies nothing.

Pass it as the resolver's `onSwitch` (above) so the team selector gets the same behaviour. `MagicStarter.currentTeamId()` answers the active team's id as a string (`null` without a resolver or an active team), so an int id from your model and a string id from a link or a push payload compare equal.

The team selector dropdown (see [Widget: MSTeamSelector](#widget-msteamselector)) is built from the resolver's `allTeams()` callback and triggers `onSwitch()` when a selection changes.

<a name="billable-subject"></a>
### The Billable Subject

`magic_starter.billing.billable` names what a store purchase is billed to, and it mirrors magic-starter-laravel's key of the same name. The two must agree:

| Value | The store rail is identified as |
|---|---|
| `'user'` (default) | `Auth.id()` |
| `'team'` | the active team id |

```dart
'billing': {
  'web_origin': 'https://app.example.com',
  'billable': 'team',
},
```

`MagicStarterServiceProvider` reads it at boot and sets `StoreIdentitySync.billableId`; any other value refuses the boot with a `StateError`, because a typo that fell back to `'user'` would bind every purchase to the wrong subject. Identifying on login and restore as well stays your call: add `StoreIdentitySync.attach()` to your provider's `boot()`.

<a name="price-format"></a>
### Price Format

Every web price the billing screen shows (the plan card, the trial line, the renewal line and the trialing line) reads the producer's `display` string, `379.00 TRY`, which carries no separator and no symbol. An app that writes money its own way registers a `MagicStarterPriceFormat` on the controller:

```dart
Magic.put(
  MagicStarterBillingController(
    usageCopy: withUsageCopy,
    formatNumber: Number.format,
    formatPrice: (MagicStarterWebPrice price) => switch (price.currency) {
      'TRY' => '${Number.format(price.amountMinor / 100)} TL',
      _ => price.display,
    },
  ),
);
```

`MagicStarterWebPrice` carries `amountMinor` (in the currency's minor unit), `currency` (the ISO 4217 code) and `display`. Return `price.display` for any currency the app does not format itself. `MagicStarterBillingController.priceText(price)` is what the screen calls.

<a name="free-trials"></a>
### Free Trials

The billing screen (`teams.billing`) shows a trial and a store introductory offer without any setup beyond the right versions: `magic_payments` ^0.0.9 and `magic-starter-laravel` 0.0.23, whose catalogue rows carry `trial_days` per product.

`MagicStarterProduct.trialDays` is the free days a purchase of that product starts with, and `0` for none. The backend answers it for the signed-in caller, so `0` also means a trial already used, and a positive value is safe to advertise. `MagicStarterBillingController.trialEnd` is the date a running trial ends (`null` unless the plan status is `trialing`); a store trial has no `trial_ends_at`, so it falls back to the entitlement's current period end.

| Where | What it shows |
|---|---|
| Current plan card | A "Trial" badge beside the plan name, and one line in place of the renewal line: "Free trial ends :date (:left), then :price per :cycle" (a web trial with a known price and cycle), the same without the price and cycle, the same with the store sentence (a store trial), or "Free trial ends :date. It will not renew." once the trial is cancelled |
| Web plan card | Above the call to action, "Free for :period. Card required, then :price per :cycle.", and the call to action reads "Start free trial". Only on a web build, only for a product with `trialDays` above zero, and the billed price stays the large figure. The first upgrade with a trial takes the grid's one filled button (otherwise the cheapest upgrade keeps it), and that button glows in its own fill colour, pulsing three times when the card first paints; reduced motion keeps the glow and drops the pulse |
| Store plan card (disclosure) | "Free for :intro_period, then :price per :period" for a free introductory offer. Only when the store says this customer is eligible (`StoreProductOffer.introEligible`); otherwise the plain "per period" line |

The translator has no plural API, so each count is chosen in Dart: `:count == 1` reads the `_one` key and any other count the `_other` key. The keys, all under `magic_starter.billing` in `en.stub`:

| Key | Default |
|---|---|
| `trial_badge` | `Trial` |
| `trial_line_renews` | `Free trial ends :date (:left), then :price per :cycle` |
| `trial_line_cycleless` | `Free trial ends :date (:left)` |
| `trial_line_store` | `Free trial ends :date (:left), then billed through the store that sold this plan.` |
| `trial_line_ends` | `Free trial ends :date. It will not renew.` |
| `trial_days_left_one`, `trial_days_left_other` | `1 day left`, `:count days left` |
| `trial_card_required` | `Free for :period. Card required, then :price per :cycle.` |
| `trial_cta` | `Start free trial` |
| `store_disclosure_intro_free` | `Free for :intro_period, then :price per :period` |
| `period_day_*`, `period_week_*`, `period_month_*`, `period_year_*` (each `_one` and `_other`) | `:count day`, `:count days`, and so on |

An app that publishes its own `en.json` adds these keys by hand. A store introductory period is read from its ISO 8601 form when it is one whole unit (`P14D`, `P2W`, `P1M`, `P1Y`); anything else (`P1Y2M`) states no offer and keeps the plain line.

<a name="changing-a-web-plan"></a>
### Changing a Web Plan

A team that already holds a web (Stripe) subscription changes tier or cycle by moving that subscription, never by buying a second one: magic-starter-laravel refuses a checkout with a 409 `subscription_exists` while one still grants. `MagicStarterBillingController.holdsWebSubscription` is `true` once the entitlement names `BillingProvider.stripe` with a plan status that still grants (`trialing`, `active`, `pastDue`, `grace`), and while it is, a tap on another paid tier opens a confirmation instead of a checkout. On confirm the screen calls `WebBillingService.swap(productKey:)` (`POST /billing/swap`) with the card's catalogue product, re-reads the payment method and the invoices, and polls the entitlement with `MagicStarterBillingController.awaitEntitlementChange(before)` (the store purchase's backoff, 60 seconds in all), because the backend answers the swap before Stripe's webhook writes the new tier. A team with no web subscription still goes through the hosted checkout, and the move to the free tier still opens the billing portal.

The confirmation states what the backend (0.0.28 or later) does with the money:

| Move | The sentence |
|---|---|
| During a running trial (a trial end still ahead) | Nothing is charged until the trial ends |
| A higher tier, or a held tier the catalogue cannot rank | The card on file is charged the prorated difference now |
| A lower tier on another cycle | The new billing period is billed at once, less the unused time on the current plan |
| A lower tier on the same cycle | The change applies now and the unused time is credited to the next invoice |

An upgrade is refused with a 402 when the card declines or the bank asks for 3D Secure, which `magic_payments` 0.0.10 reports as `BillingErrorCode.paymentDeclined` and `paymentRequiresAction`; the toast says the plan has not changed and why. The keys, all under `magic_starter.billing` in `en.stub`:

| Key | Default |
|---|---|
| `swap_confirm_title` | `Change to :name?` |
| `swap_confirm_charge_now` | `Billed :cycle from now on. Your card on file is charged the prorated difference now.` |
| `swap_confirm_credit` | `Billed :cycle from now on. The change applies now and the unused time is credited to your next invoice.` |
| `swap_confirm_period_now` | `Billed :cycle from now on. The change applies now, and the new billing period is billed to your card at once, less the unused time on your current plan.` |
| `swap_confirm_trial` | `Billed :cycle from now on. Your trial continues; you are charged when it ends.` |
| `swap_confirm_button`, `swap_cancel_button` | `Change plan`, `Keep current plan` |
| `toast_swap_description` | `Billed :cycle. The change applies now.` |
| `errors.payment_declined` | `Your card was declined, so your plan has not changed. Update your payment method and try again.` |
| `errors.payment_requires_action` | `Your bank asked to confirm this payment, which a plan change cannot do here, so your plan has not changed. Try a card that does not ask for confirmation, or contact us.` |

An app that publishes its own `en.json` adds these keys by hand.

<a name="campaigns"></a>
### Campaigns

A staff-run, time-boxed offer on `magic-starter-laravel` (`GET /billing/campaign`) reaches a floor-tier team owner on the web rail as an app-wide banner and a tag on the plan cards it discounts. The backend answers `{"data": null}` unless the caller is the audience, so nothing here decides who qualifies; the client only declines to ask when it could not act on the offer.

`MagicStarterBillingController.loadCampaign()` reads the offer. It is separate from `load()`, which stays the billing screen's six reads, and it asks only when the `billing` feature is on and `canPurchaseViaWeb` holds (a web rail, no store managing the subscription, not a known non-owner). The answer lives on the controller instance as `MagicStarterBillingController.campaign`, a `MagicStarterCampaign` (`id`, `startsAt`, `endsAt`, `products`, `discount`, and `headlineFor(languageCode)` / `bodyFor(languageCode)`, which pick the app locale, then `magic_starter.defaults.locale`, then any copy the backend sent). A team switch or a sign-in (`resetForSession`) clears it and the mounted banner asks again for the new team. The backend answers 404 when its `campaigns` feature is off (the default), which is read as no campaign and logs nothing; any other failed read is logged as a warning.

| Where | What it shows |
|---|---|
| `MagicStarterCampaignBanner` | The headline and body above every page, a "See plans" action that goes to `MagicStarterConfig.billingRoute()` and a "Dismiss" action. `MagicStarterAppLayout` mounts it beside the app update banner when `billing` is on; a host that maps `layout.app` to its own layout places it itself. It resolves the registered billing controller without running its `onInit`, so it never starts the six billing reads. It hides itself once `endsAt` has passed, without waiting for another read |
| Plan card | For a card whose product at the selected billing cycle is in the campaign, a "Limited offer" tag and the discount (":value% off", or ":amount off" for a fixed sum) in the card's highlight spot. The tag follows the cycle toggle: a campaign on `pro_monthly` only tags the Pro card while Monthly is selected. It also hides once `endsAt` has passed. The billing screen reads the campaign itself, so a host without the banner still gets the tag |

"Dismiss" stores the campaign id in the `Vault` under `MagicStarterCampaignBanner.dismissalKey()`, which is `dismissedCampaignKey` plus the signed-in account's id, so a second account on the same device does not inherit the first one's dismissal. That campaign stays hidden across launches; the next campaign has a new id and shows again.

The tag is the DEFAULT content of the `plan_card_highlight` slot. An app that registers that slot replaces it, and reads `MagicStarterBillingController.campaign` to render the offer itself. A fixed-sum discount is a minor-unit amount, taken from the coupon's amount in the currency the card is priced in (`discount.currency_options`), else the campaign's own `value` and `currency`: the tag passes it through the app's `MagicStarterPriceFormat` when one is registered, and otherwise writes it the producer's way (`5.00 USD`), which assumes a currency with two decimals.

The package ships English copy only. The headline and body come from the backend per language; the labels are keys under `magic_starter.billing` in `en.stub`, and an app that publishes its own `en.json` adds them by hand:

| Key | Default |
|---|---|
| `campaign_see_plans` | `See plans` |
| `campaign_dismiss` | `Dismiss` |
| `campaign_badge` | `Limited offer` |
| `campaign_discount_percent` | `:value% off` |
| `campaign_discount_amount` | `:amount off` |

<a name="invitation"></a>
## Invitation

<a name="sending-invitations"></a>
### Sending Invitations

Invite a member to the current team by email and role:

```dart
final success = await MagicStarterTeamController.instance.doInvite(
  email: 'colleague@example.com',
  role: 'editor',
);
```

The controller sends `POST /teams/{teamId}/invitations` and automatically refreshes the invitations list via `loadMembersAndInvitations()` on success.

> [!NOTE]
> The `activeTeamId` is resolved from either the explicit `currentTeamId.value` or the team resolver's `currentTeam()` callback. If neither provides a team ID, the controller sets an error and returns `false`.

<a name="accepting-invitations"></a>
### Accepting Invitations

Accept an invitation using the token from the invitation URL:

```dart
final success = await MagicStarterTeamController.instance.doAcceptInvitation(
  token: invitationToken,
);
```

This sends `POST /invitations/{token}/accept`. On success, `Auth.restore()` refreshes the user model to include the newly joined team.

The invitation accept view is registered under `teams.invitation_accept`, on the route `/invitations/:token/accept`. The view reads the token from its own route's path once, in `didChangeDependencies` (route state cannot be read in `initState`):

```dart
_token ??= MagicRouter.instance.pathParameterOf(context, 'token');
```

The static `pathParameter()` would answer for whichever page was built last, which across layout shells is not always this one.

<a name="canceling-invitations"></a>
### Canceling Invitations

Cancel a pending invitation (team admin action):

```dart
final success = await MagicStarterTeamController.instance.cancelInvitation(
  invitationId,
);
```

This sends `DELETE /teams/{teamId}/invitations/{invitationId}` and removes the invitation from the local `invitations` ValueNotifier without requiring a full refresh.

<a name="team-settings"></a>
## Team Settings

<a name="updating-team-name"></a>
### Updating Team Name

Update the active team's name:

```dart
final success = await MagicStarterTeamController.instance.doUpdate(
  name: form['name'],
);
```

Sends `PUT /teams/{teamId}` and calls `Auth.restore()` on success.

<a name="managing-members"></a>
### Managing Members

Load the full member and invitation lists for the active team:

```dart
await MagicStarterTeamController.instance.loadMembersAndInvitations();
```

This fires `GET /teams/{teamId}/members` and `GET /teams/{teamId}/invitations` in parallel via `Future.wait()`. Results are stored in the `members` and `invitations` ValueNotifier fields.

Remove a member from the team:

```dart
final success = await MagicStarterTeamController.instance.removeMember(
  memberId,
);
```

Sends `DELETE /teams/{teamId}/members/{memberId}` and updates the local `members` list immediately.

> [!TIP]
> Use `ValueListenableBuilder` to react to changes in `controller.members` and `controller.invitations` — both are `ValueNotifier<List<Map<String, dynamic>>>` for fine-grained rebuilds.

<a name="feature-gate"></a>
## Feature Gate

The entire teams module is gated by a single configuration flag:

```dart
Config.set('magic_starter.features.teams', true);
```

Check programmatically:

```dart
if (MagicStarterConfig.hasTeamFeatures()) {
  // Team UI and routes are available
}
```

When disabled, team routes are not registered and attempting to navigate to them throws a `StateError`. The team selector widget and team-related profile sections are hidden via feature-gated spreads in the view layer.

<a name="controller"></a>
## Controller

`MagicStarterTeamController` is accessed via the singleton:

```dart
final controller = MagicStarterTeamController.instance;
```

Key reactive fields:

| Field | Type | Purpose |
|-------|------|---------|
| `currentTeamId` | `ValueNotifier<dynamic>` | Explicitly set team ID — overrides resolver |
| `members` | `ValueNotifier<List<Map<String, dynamic>>>` | Current team members |
| `invitations` | `ValueNotifier<List<Map<String, dynamic>>>` | Pending invitations |

Computed properties:

| Property | Type | Description |
|----------|------|-------------|
| `activeTeamId` | `dynamic` | Resolves from `currentTeamId.value` or resolver's `currentTeam()` |
| `activeTeamName` | `String?` | Name from the resolver's `currentTeam()` |

> [!IMPORTANT]
> The controller's `dispose()` method disposes all three `ValueNotifier` fields. Always call `controller.dispose()` in `tearDown()` during tests, and ensure `ValueNotifier` disposal in any widget that creates a local reference.

<a name="views"></a>
## Views

| Registry Key | View | Route |
|-------------|------|-------|
| `teams.create` | `TeamCreateView` | `/teams/create` |
| `teams.settings` | `TeamSettingsView` | `/teams/settings` |
| `teams.invitation_accept` | `TeamInvitationAcceptView` | `/invitations/{token}/accept` |

All views extend `MagicStatefulView<MagicStarterTeamController>` and are rendered inside `AppLayout`. They are instantiated through the view registry:

```dart
MagicStarter.view.make('teams.create');
MagicStarter.view.make('teams.settings');
MagicStarter.view.make('teams.invitation_accept');
```

The host app can override any view by registering a custom builder under the same key.

<a name="widget-msteamselector"></a>
## Widget: MSTeamSelector

The `MSTeamSelector` is a dropdown widget built from the team resolver callbacks. It displays the user's teams and triggers a team switch on selection:

```dart
MSTeamSelector()
```

The widget reads `MagicStarter.teamResolver` to populate the dropdown options and calls the resolver's `onSwitch` callback when the user selects a different team. It is typically placed in the app layout's sidebar or header.

> [!NOTE]
> The team selector only renders when `MagicStarter.hasTeamResolver` returns `true`. If no resolver is registered, the widget renders nothing.

<a name="model-magicstarterteam"></a>
## Model: MagicStarterTeam

`MagicStarterTeam` is a lightweight DTO that bridges your app's team model with the starter plugin:

```dart
class MagicStarterTeam {
  final dynamic id;
  final String? name;
  final String? photoUrl;
  final bool isPersonalTeam;

  const MagicStarterTeam({
    required this.id,
    this.name,
    this.photoUrl,
    this.isPersonalTeam = false,
  });

  factory MagicStarterTeam.fromMap(Map<String, dynamic> map);
}
```

The `fromMap()` factory handles backend response normalization, including `personal_team` which may arrive as `true` or `1`.

Your app's Team model should provide a conversion method:

```dart
extension on Team {
  MagicStarterTeam toMagicStarterTeam() {
    return MagicStarterTeam(
      id: id,
      name: name,
      photoUrl: profilePhotoUrl,
      isPersonalTeam: personalTeam,
    );
  }
}
```

---

**Related links:**

- [Authentication](https://magic.fluttersdk.com/packages/starter/authentication)
- [Profile Management](https://magic.fluttersdk.com/packages/starter/profile)
- [Configuration](https://magic.fluttersdk.com/packages/starter/configuration)
