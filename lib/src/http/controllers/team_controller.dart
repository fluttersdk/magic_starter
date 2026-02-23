import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../facades/magic_starter.dart';

/// Team controller for Magic Starter plugin.
class TeamController extends MagicController
    with MagicStateMixin<bool>, ValidatesRequests {
  static TeamController get instance => Magic.findOrPut(TeamController.new);

  bool _isSubmitting = false;

  /// Team context used by team-scoped endpoints.
  final ValueNotifier<dynamic> currentTeamId = ValueNotifier(null);

  /// Current team members.
  final ValueNotifier<List<Map<String, dynamic>>> members = ValueNotifier([]);

  /// Pending invitations.
  final ValueNotifier<List<Map<String, dynamic>>> invitations =
      ValueNotifier([]);

  /// Get the active team ID — from explicit value or team resolver.
  dynamic get activeTeamId =>
      currentTeamId.value ?? MagicStarter.teamResolver?.currentTeam()?.id;

  /// Get the active team name from the resolver.
  String? get activeTeamName => MagicStarter.teamResolver?.currentTeam()?.name;

  /// Render create team view via registry key.
  Widget create() => MagicStarter.view.make('teams.create');

  /// Render team settings view via registry key.
  Widget edit() => MagicStarter.view.make('teams.settings');

  /// Render invitation accept view via registry key.
  Widget acceptInvitation() =>
      MagicStarter.view.make('teams.invitation_accept');

  /// Load members and invitations for the active team.
  bool _isLoadingMembers = false;
  Future<void> loadMembersAndInvitations() async {
    if (_isLoadingMembers) return;
    final teamId = activeTeamId;
    if (teamId == null) return;
    _isLoadingMembers = true;
    setLoading();
    try {
      final results = await Future.wait([
        Http.get('/teams/$teamId/members'),
        Http.get('/teams/$teamId/invitations'),
      ]);
      final membersResponse = results[0];
      final invitationsResponse = results[1];
      var hasFailure = false;
      if (membersResponse.successful) {
        final data = membersResponse['data'];
        if (data is List) {
          members.value =
              data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } else {
        hasFailure = true;
      }
      if (invitationsResponse.successful) {
        final data = invitationsResponse['data'];
        if (data is List) {
          invitations.value =
              data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } else {
        hasFailure = true;
      }
      if (hasFailure) {
        setError(trans('errors.unexpected'));
      } else {
        setSuccess(true);
      }
    } catch (e, stackTrace) {
      Log.error('[TeamController.loadMembersAndInvitations] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
    } finally {
      _isLoadingMembers = false;
    }
  }

  /// Cancel a pending invitation.
  Future<bool> cancelInvitation(dynamic invitationId) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;

    final teamId = activeTeamId;
    if (teamId == null) {
      _isSubmitting = false;
      setError(trans('teams.no_team_selected'));
      return false;
    }

    setLoading();
    clearErrors();

    try {
      final response =
          await Http.delete('/teams/$teamId/invitations/$invitationId');

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('teams.cancel_invite_failed'),
        );
        return false;
      }

      invitations.value =
          invitations.value.where((inv) => inv['id'] != invitationId).toList();
      Magic.toast(trans('teams.invite_canceled'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error('[TeamController.cancelInvitation] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Create new team.
  Future<bool> doCreate({required String name}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post('/teams', data: {'name': name});

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('teams.create_failed'),
        );
        return false;
      }

      final data = response['data'] as Map<String, dynamic>?;
      final createdTeamId = data?['id'];

      if (createdTeamId != null) {
        currentTeamId.value = createdTeamId;
      }

      await Auth.restore();
      Magic.toast(trans('teams.created'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error('[TeamController.doCreate] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Update current team settings.
  Future<bool> doUpdate({required String name}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;

    final teamId = activeTeamId;
    if (teamId == null) {
      _isSubmitting = false;
      setError(trans('teams.no_team_selected'));
      return false;
    }

    setLoading();
    clearErrors();

    try {
      final response = await Http.put('/teams/$teamId', data: {'name': name});

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('teams.update_failed'),
        );
        return false;
      }

      await Auth.restore();
      Magic.toast(trans('teams.updated'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error('[TeamController.doUpdate] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Invite member to current team.
  Future<bool> doInvite({required String email, required String role}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;

    final teamId = activeTeamId;
    if (teamId == null) {
      _isSubmitting = false;
      setError(trans('teams.no_team_selected'));
      return false;
    }

    setLoading();
    clearErrors();

    try {
      final response = await Http.post(
        '/teams/$teamId/invitations',
        data: {'email': email, 'role': role},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('teams.invite_failed'),
        );
        return false;
      }

      Magic.toast(trans('teams.invite_sent'));
      setSuccess(true);

      // Refresh invitations list
      await loadMembersAndInvitations();
      return true;
    } catch (e, stackTrace) {
      Log.error('[TeamController.doInvite] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Remove a member from current team.
  Future<bool> removeMember(dynamic memberId) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;

    final teamId = activeTeamId;
    if (teamId == null) {
      _isSubmitting = false;
      setError(trans('teams.no_team_selected'));
      return false;
    }

    setLoading();
    clearErrors();

    try {
      final response = await Http.delete('/teams/$teamId/members/$memberId');

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('teams.member_remove_failed'),
        );
        return false;
      }

      Magic.toast(trans('teams.member_removed'));
      setSuccess(true);

      // Refresh members list
      members.value = members.value.where((m) => m['id'] != memberId).toList();
      return true;
    } catch (e, stackTrace) {
      Log.error('[TeamController.removeMember] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Switch active team.
  Future<bool> switchTeam(dynamic teamId) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.put(
        '/user/current-team',
        data: {'team_id': teamId},
      );

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('teams.switch_failed'),
        );
        return false;
      }

      currentTeamId.value = teamId;
      await Auth.restore();
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error('[TeamController.switchTeam] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  /// Accept a team invitation by token.
  Future<bool> doAcceptInvitation({required String token}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    setLoading();
    clearErrors();

    try {
      final response = await Http.post('/invitations/$token/accept');

      if (!response.successful) {
        handleApiError(
          response,
          fallback: trans('teams.accept_invite_failed'),
        );
        return false;
      }

      await Auth.restore();
      Magic.toast(trans('teams.invite_accepted'));
      setSuccess(true);
      return true;
    } catch (e, stackTrace) {
      Log.error('[TeamController.doAcceptInvitation] $e\n$stackTrace');
      setError(trans('errors.unexpected'));
      return false;
    } finally {
      _isSubmitting = false;
    }
  }

  @override
  void dispose() {
    currentTeamId.dispose();
    members.dispose();
    invitations.dispose();
    super.dispose();
  }
}
