// file: lib/features/groups/group_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'models/group.dart';
import 'models/group_model.dart';

class GroupService {
  final supabase = Supabase.instance.client;

  Future<Group?> getGroupById(String groupId) async {
    final data = await supabase
        .from('groups')
        .select()
        .eq('id', groupId)
        .maybeSingle();

    if (data == null) {
      debugPrint('Group not found for id: $groupId');
      return null;
    }

    return Group.fromMap(data);
  }

  Future<bool> isUserGroupAdmin(String groupId, String userId) async {
    final result = await supabase
        .from('group_memberships')
        .select('role')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .eq('status', 'approved')
        .maybeSingle();

    final role = result?['role'] as String?;
    return role == 'admin' || role == 'leader' || role == 'supervisor' || role == 'owner';
  }

  Future<List<GroupModel>> getUserGroups(String userId) async {
    final List<Map<String, dynamic>> memberships = await supabase
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId)
        .eq('status', 'approved');

    if (memberships.isEmpty) return [];

    final groupIds = memberships.map((e) => e['group_id']).toList();

    final List<Map<String, dynamic>> groups = await supabase
        .from('groups')
        .select()
        .inFilter('id', groupIds);

    return groups.map((e) => GroupModel.fromMap(e)).toList();
  }

  Future<List<GroupModel>> getJoinableGroups() async {
    final List<Map<String, dynamic>> groups = await supabase
        .from('groups')
        .select()
        .inFilter('visibility', ['public', 'request']);

    return groups.map((e) => GroupModel.fromMap(e)).toList();
  }

  Future<List<GroupModel>> getAdminGroups(String userId) async {
    final memberships = await supabase
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId)
        .eq('status', 'approved')
        .inFilter('role', ['admin', 'leader', 'supervisor', 'owner']);

    if (memberships.isEmpty) return [];

    final groupIds = memberships.map((e) => e['group_id']).toList();

    final groups = await supabase
        .from('groups')
        .select()
        .inFilter('id', groupIds);

    return groups.map((e) => GroupModel.fromMap(e)).toList();
  }

  Future<List<GroupModel>> getGroupInvitations(String userId) async {
    final invites = await supabase
        .from('group_invitations')
        .select('group_id')
        .eq('user_id', userId)
        .eq('status', 'pending');

    if (invites.isEmpty) return [];

    final groupIds = invites.map((e) => e['group_id']).toList();

    final groups = await supabase
        .from('groups')
        .select()
        .inFilter('id', groupIds);

    return groups.map((e) => GroupModel.fromMap(e)).toList();
  }

}
