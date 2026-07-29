# Session Scope

- [Introduction](#introduction)
- [The Leak](#the-leak)
- [The Contract](#the-contract)
- [Clear Before You Refetch](#clear-before-you-refetch)
- [Wiring the Sync](#wiring-the-sync)
- [The Identity Key](#the-identity-key)
- [Why Logout Does Not Reset](#why-logout-does-not-reset)
- [Error Isolation](#error-isolation)
- [Testing](#testing)
- [Related](#related)

<a name="introduction"></a>
## Introduction

Any controller that caches data belonging to one signed-in user (or to one of that user's teams) has to be told when that user changes. Magic Starter ships two pieces for this: the `SessionScopedController` contract, which a controller implements to declare "my rows belong to exactly one session", and `SessionScopeSync`, which watches `Auth.stateNotifier` and resets every registered controller whenever the authenticated identity changes.

> [!IMPORTANT]
> This is a privacy guard, not a freshness nicety. Without it, a logout followed by a login as a different user leaves the previous user's rows on screen. On a team-scoped product that is a cross-tenant data exposure.

<a name="the-leak"></a>
## The Leak

Magic resolves controllers as **Type-keyed singletons**: `Magic.findOrPut(ProjectController.new)` returns the same instance for the whole process lifetime. The initial fetch usually lives in `onInit()`, and `MagicStatefulViewState.initState` only calls it while the controller has not been initialized yet:

```dart
// magic/lib/src/ui/magic_view.dart
if (!_controller.initialized) {
  _controller.onInit();
}
```

So `onInit()` runs **once per instance lifetime**, not once per mount. Follow the consequence through:

1. User A signs in, opens the projects screen. `ProjectController.onInit()` fetches A's projects.
2. A signs out. The controller instance survives: nothing disposes it, and its rows are still in memory.
3. User B signs in on the same device and opens the projects screen. The controller is already initialized, so `onInit()` does not run and no fetch happens.
4. B is looking at A's projects until the app is restarted.

The same thing happens without a logout at all: a **team switch** changes which rows the API would return, while every cached controller keeps the old team's data.

<a name="the-contract"></a>
## The Contract

Implement `SessionScopedController` on every controller that caches session-scoped data:

```dart
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class ProjectController extends MagicController
    with MagicStateMixin<List<Project>>
    implements SessionScopedController {
  static ProjectController get instance =>
      Magic.findOrPut(ProjectController.new);

  final List<Project> projects = [];

  @override
  Future<void> onInit() async {
    super.onInit();
    await loadProjects();
  }

  @override
  Future<void> resetForSession() async {
    // 1. Publish the cleared state BEFORE the refetch.
    projects.clear();
    setLoading();

    // 2. Refetch for whoever is authenticated now.
    await loadProjects();
  }
}
```

`resetForSession()` is the only member of the contract. It is called on login and on team switch, and it is expected to drop every cached row, publish that cleared state, and then refetch.

<a name="clear-before-you-refetch"></a>
## Clear Before You Refetch

This is the single most misunderstood part of the design, so it is worth being explicit: **`resetForSession()` is destructive on purpose, and the clear must land before the refetch is attempted.**

An ordinary `reload()` is deliberately *non*-destructive. When a refresh fails, keeping the last-known-good rows is the right call: a five-second network blip should not blank a dashboard the user is reading. Almost every controller in a Magic app is written that way.

Across an identity change that behaviour is exactly wrong. The rows on screen belong to the *previous* session, so "keep what we have when the refetch fails" means "keep showing user A's data to user B". The failure mode inverts:

| | Ordinary `reload()` | `resetForSession()` |
|---|---|---|
| Refetch succeeds | new rows | new rows |
| Refetch fails | previous rows stay (correct: same user, stale data) | **must** be empty (previous rows belong to another session) |

So the order inside `resetForSession()` is load-bearing:

```dart
@override
Future<void> resetForSession() async {
  projects.clear();      // 1. Drop the previous session's rows.
  setLoading();          // 2. Publish it, so the UI is empty even if step 3 throws.
  await loadProjects();  // 3. Only now go to the network.
}
```

> [!WARNING]
> Do not write `resetForSession()` as a plain `await reload()`, and do not clear inside a `try` whose `catch` restores the old rows. A failed refetch must leave an empty screen, never a populated one.

<a name="wiring-the-sync"></a>
## Wiring the Sync

`SessionScopeSync` is the driver. Attach it once, from your app's service provider `boot()`:

```dart
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    MagicStarter.useUserModel((data) => User.fromMap(data));
    MagicStarter.useTeamResolver(/* ... */);

    // Register last: notification polling, realtime subscriptions and locale
    // should already point at the new session before its data is refetched.
    SessionScopeSync.attach();
  }
}
```

`attach()` subscribes to `Auth.stateNotifier` and records the identity the app boots with. It does not reset anything at boot: no view has resolved a controller yet, so there is nothing cached to clear, and recording the boot identity means the first *real* change is the first one that resets.

The API is three members:

| Member | Purpose |
|--------|---------|
| `SessionScopeSync.attach()` | Subscribe to auth state changes. Idempotent; a second call while attached is a no-op. |
| `SessionScopeSync.detach()` | Unsubscribe and forget the recorded identity. Mainly for tests. |
| `SessionScopeSync.isAttached` | Whether a subscription is active. |

> [!NOTE]
> The state is static rather than per-instance because everything it coordinates is already process-wide: `Auth.stateNotifier` is one notifier per guard and `Magic.controllers` is one static registry. Two instances would both listen to that single notifier and reset every controller twice per identity change.

<a name="the-identity-key"></a>
## The Identity Key

The sync compares a string key, not object identity:

```
<userId>:<teamId>
```

| Leg | Source | Null when |
|-----|--------|-----------|
| `userId` | `Auth.id()` | never while `Auth.check()` is true |
| `teamId` | `MagicStarter.teamResolver?.currentTeam()?.id` | teams are disabled, or no team resolver is registered |

Two legs, because a team-scoped API scopes its endpoints to the current team and not just to the user: switching teams changes every response body while `Auth.id()` stays put. Reading the team through the starter's own [team resolver](https://magic.fluttersdk.com/packages/starter/basics/teams) is what keeps this package independent of your `User` model.

The whole key is null when, and only when, nobody is signed in (`Auth.check()` is the discriminator). Two rules follow from that:

- **An unchanged key is a no-op.** `Auth.stateNotifier` also bumps on a plain session restore. Without this check, every incidental bump would stampede a fresh wave of refetches, visible as flicker and wasted requests.
- **Only a change to a non-null key resets.** See below.

Team switching triggers the sync for free: `MagicStarterTeamController.switchTeam()` calls `Auth.restore()` after the write, which bumps `Auth.stateNotifier`. If you implement your own switch path, keep that `Auth.restore()` call.

<a name="why-logout-does-not-reset"></a>
## Why Logout Does Not Reset

On logout the key goes from `1:10` to `null`, and nothing is reset. That is deliberate.

There is no identity to refetch for. A reset on logout would clear every controller and then fire a wave of requests from the login screen, where the token is already gone, so they can only come back `401`. That is noise at best, and at worst a forced-logout loop for any app that reacts to a `401`.

The stale rows are not a problem in the meantime: they sit unreachable in memory behind the auth guard, and the next login resets them **before** any authenticated view renders, because `Auth.login` bumps `Auth.stateNotifier` before the post-login navigation runs.

The key is still *recorded* on logout (as null). That is what makes signing back in as the *same* user count as a change (`null` to `1:10`) and refetch anyway.

<a name="error-isolation"></a>
## Error Isolation

Each `resetForSession()` is fired independently: `Auth.stateNotifier` listeners are synchronous, so the sync does not await them, and each future carries its own error guard. One controller throwing does not stop the others from resetting, and the failure is logged rather than swallowed:

```
[SessionScopeSync] session reset failed: <error>
```

Implementations should still handle their own failures the way any other reload does (`setError()`, a fallback message). A throw that escapes leaves that one controller cleared and unrefetched, which is safe but shows an empty screen with no explanation.

<a name="testing"></a>
## Testing

`SessionScopeSync` holds process-wide statics that neither `MagicApp.reset()` nor `Magic.flush()` clears, so call `detach()` in both `setUp` and `tearDown` to keep tests order-independent:

```dart
setUp(() {
  MagicApp.reset();
  Magic.flush();
  // bind 'log', 'auth' and 'magic_starter', register the team resolver...
  SessionScopeSync.detach();
});

tearDown(() => SessionScopeSync.detach());

test('drops the previous tenant rows when another user logs in', () async {
  await Auth.login({'token': 'a'}, userA);
  SessionScopeSync.attach();

  final controller = Magic.put(ProjectController());
  controller.projects.addAll(projectsOfA);

  await Auth.login({'token': 'b'}, userB);
  await pumpEventQueue();

  expect(controller.projects, isNot(contains(projectsOfA.first)));
});
```

`detach()` unsubscribes from the exact notifier instance it subscribed to. That matters in tests: `Auth.stateNotifier` resolves through the IoC container, so rebinding the guard hands back a different notifier and unsubscribing through the facade would leave the old listener alive.

<a name="related"></a>
## Related

- [State Management](https://magic.fluttersdk.com/packages/starter/guides/state-management): `MagicController`, `MagicStateMixin`, and the singleton accessor pattern this contract sits on
- [Teams](https://magic.fluttersdk.com/packages/starter/basics/teams): the team resolver that supplies the second leg of the identity key
- [Authentication](https://magic.fluttersdk.com/packages/starter/basics/authentication): `Auth.stateNotifier`, login, logout, and session restore
- [Service Providers](https://magic.fluttersdk.com/packages/starter/architecture/service-provider): where `attach()` belongs in the boot sequence
