// file: lib/features/groups/group_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/group_invitation.dart';
import 'models/group.dart';

class GroupService {
  final supabase = Supabase.instance.client;

  /// Fetch groups the current user is a member of
  Future<List<Group>> fetchMyGroups(String userId) async {
    final data = await supabase
        .from('group_memberships')
        .select('groups(*)')
        .eq('user_id', userId)
        .eq('status', 'approved');

    return (data as List)
        .map((row) => Group.fromMap(row['groups']))
        .toList();
  }

  /// Fetch groups that the user is not yet a member of
  Future<List<Group>> fetchJoinableGroups(String userId) async {
    // Step 1: get group_ids already joined
    final joined = await supabase
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId);

    final joinedIds = (joined as List)
        .map((row) => row['group_id'] as String)
        .toSet();

    // Step 2: get all public or request groups
    final response = await supabase
        .from('groups')
        .select()
        .inFilter('visibility', ['public', 'request']);

    final allGroups = (response as List)
        .map((e) => Group.fromMap(e))
        .where((group) => !joinedIds.contains(group.id))
        .toList();

    return allGroups;
  }

  /// Join a public group immediately
  Future<void> joinGroup(String groupId, String userId) async {
    await supabase.from('group_memberships').insert({
      'group_id': groupId,
      'user_id': userId,
      'status': 'approved',
      'role': 'member',
    });
  }

  /// Request to join a group (status = pending)
  Future<void> requestToJoinGroup(String groupId, String userId) async {
    await supabase.from('group_memberships').insert({
      'group_id': groupId,
      'user_id': userId,
      'status': 'pending',
      'role': 'member',
    });
  }

  /// Fetch a single group by ID
  Future<Group?> getGroupById(String id) async {
    final data = await supabase
        .from('groups')
        .select()
        .eq('id', id)
        .single();

    return Group.fromMap(data);
  }

  /// Get user's membership status in a group
  Future<String?> getMembershipStatus(String groupId, String userId) async {
    final result = await supabase
        .from('group_memberships')
        .select('status')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    return result?['status'] as String?;
  }

  /// Fetch all invitations for the user, including group info
  Future<List<GroupInvitation>> fetchInvitations(String userId) async {
    final response = await supabase
        .from('group_invitations')
        .select('*, groups(*)')
        .eq('user_id', userId)
        .eq('status', 'pending');

      return (response as List)
        .map((e) => GroupInvitation.fromMap(e))
        .toList();
  }

  /// Accept invitation → join group, delete invite
  Future<void> acceptInvitation(GroupInvitation invite) async {
    final groupId = invite.groupId;
    final userId = invite.userId;
    final inviteId = invite.id;

    // 1. Add to group_memberships
    await supabase.from('group_memberships').insert({
      'group_id': groupId,
      'user_id': userId,
      'status': 'approved',
      'role': 'member',
    });

    // 2. Delete the invitation
    await supabase.from('group_invitations').delete().eq('id', inviteId);
  }

  /// Decline invitation → just delete
  Future<void> declineInvitation(String inviteId) async {
    await supabase.from('group_invitations').delete().eq('id', inviteId);
  }

  /// Check if a user has admin role in a group
  Future<bool> isUserGroupAdmin(String groupId, String userId) async {
    final result = await supabase
        .from('group_memberships')
        .select('role')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    final role = result?['role'] as String?;
    return role == 'admin' || role == 'leader' || role == 'supervisor' || role == 'owner';
  }
}
