# Teams

- [Introduction](#introduction)
- [Team Resolver](#team-resolver)
- [Creating Teams](#creating-teams)
- [Team Switching](#team-switching)
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
- [Widget: MagicStarterTeamSelector](#widget-magicstarterteamselector)
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
  onSwitch: (id) => MagicStarterTeamController.instance.switchTeam(id),
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

Switch the active team via `switchTeam()`:

```dart
final success = await MagicStarterTeamController.instance.switchTeam(teamId);
```

This sends `PUT /user/current-team` with the target `team_id`. On success, the controller updates `currentTeamId.value` and calls `Auth.restore()` to refresh the user model with the new team context.

The team selector dropdown (see [Widget: MagicStarterTeamSelector](#widget-magicstarterteamselector)) is built from the resolver's `allTeams()` callback and triggers `onSwitch()` when a selection changes.

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

The invitation accept view is registered under `teams.invitation_accept`. The token is typically extracted from the URL query parameter in the view:

```dart
final token = MagicRouter.instance.queryParameter('token') ?? '';
```

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

<a name="custom-sections"></a>
### Custom Sections

Host apps can inject custom sections into the team settings view without overriding the entire view. Sections render after the built-in General and Members cards, sorted by `order` (lower = higher):

```dart
// In AppServiceProvider.boot()
MagicStarter.teamSettings.registerSection(
  key: 'billing',
  order: 10,
  builder: (context, team) => BillingCard(team: team),
);

MagicStarter.teamSettings.registerSection(
  key: 'integrations',
  order: 20,
  builder: (context, team) => IntegrationsCard(team: team),
);
```

Remove a section when no longer needed:

```dart
MagicStarter.teamSettings.removeSection('billing');
```

> [!NOTE]
> Registering a section with an existing key replaces the previous one — no duplicates. The `team` parameter is nullable (`MagicStarterTeam?`) because the team resolver may not be configured.

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

<a name="widget-magicstarterteamselector"></a>
## Widget: MagicStarterTeamSelector

The `MagicStarterTeamSelector` is a dropdown widget built from the team resolver callbacks. It displays the user's teams and triggers a team switch on selection:

```dart
MagicStarterTeamSelector()
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
