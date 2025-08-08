// file: lib/features/groups/group_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'models/group.dart';
import 'models/group_model.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final log = Logger();

class GroupArchivedException implements Exception {
  final String groupId;
  const GroupArchivedException(this.groupId);
  @override
  String toString() => 'Group $groupId is archived';
}

class GroupService {
  final supabase = Supabase.instance.client;

  // ---------- Helpers ----------

  Future<void> _assertGroupActive(String groupId) async {
    final row = await supabase
        .from('groups')
        .select('archived')
        .eq('id', groupId)
        .maybeSingle();
    if (row == null) throw Exception('Group not found');
    if (row['archived'] == true) throw GroupArchivedException(groupId);
  }

  // ---------- Reads ----------

  Future<Group?> getGroupById(String groupId) async {
    final data = await supabase
        .from('groups')
        .select(
            'id,name,description,photo_url,visibility,temporary,archived,pinned_message_id,created_at')
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
    return role == 'admin' ||
        role == 'leader' ||
        role == 'supervisor' ||
        role == 'owner';
  }

  Future<bool> isUserGroupOwner(String groupId, String userId) async {
    final result = await supabase
        .from('group_memberships')
        .select('role')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .eq('status', 'approved')
        .maybeSingle();

    final role = result?['role'] as String?;
    return role == 'owner';
  }

  Future<List<GroupModel>> getUserGroups(String userId) async {
    final memberships = await supabase
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId)
        .eq('status', 'approved');

    if (memberships.isEmpty) return [];

    final groupIds = memberships.map((e) => e['group_id']).toList();

    final groups = await supabase
        .from('groups')
        .select()
        .inFilter('id', groupIds)
        .eq('archived', false);

    return groups.map((e) => GroupModel.fromMap(e)).toList();
  }

  Future<List<GroupModel>> getJoinableGroups() async {
    final groups = await supabase
        .from('groups')
        .select()
        .inFilter('visibility', ['public', 'request'])
        .eq('archived', false);

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
        .inFilter('id', groupIds)
        .eq('archived', false);

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
        .inFilter('id', groupIds)
        .eq('archived', false);

    return groups.map((e) => GroupModel.fromMap(e)).toList();
  }

  Future<Map<String, dynamic>?> getPinnedMessage(String groupId) async {
    final group = await supabase
        .from('groups')
        .select('pinned_message_id, archived')
        .eq('id', groupId)
        .maybeSingle();

    if (group == null) return null;

    final pinnedId = group['pinned_message_id'];
    if (pinnedId == null) return null;

    final result = await supabase
        .from('group_messages')
        .select('content,sender_id,created_at')
        .eq('id', pinnedId)
        .maybeSingle();

    if (result == null) return null;

    final profile = await supabase
        .from('profiles')
        .select('display_name')
        .eq('id', result['sender_id'])
        .maybeSingle();

    return {
      'content': result['content'],
      'sender': profile?['display_name'] ?? 'Someone',
      'created_at': result['created_at'],
    };
  }

  Future<List<Map<String, dynamic>>> getGroupEvents(String groupId) async {
    await _assertGroupActive(groupId);
    final events = await supabase
        .from('group_events')
        .select('id,title,event_date,location,image_url')
        .eq('group_id', groupId)
        .gte('event_date', DateTime.now().toUtc().toIso8601String()) // upcoming only
        .order('event_date', ascending: true)
        .limit(3);

    return List<Map<String, dynamic>>.from(events);
  }

  Future<List<Map<String, dynamic>>> getGroupAnnouncements(String groupId) async {
    await _assertGroupActive(groupId);
    final announcements = await supabase
        .from('group_announcements')
        .select('id,title,body,image_url,published_at,created_at')
        .eq('group_id', groupId)
        .lte('published_at', DateTime.now().toUtc().toIso8601String()) // published only
        .order('published_at', ascending: false)
        .limit(3);

    return List<Map<String, dynamic>>.from(announcements);
  }

  Future<List<Map<String, dynamic>>> getRecentGroupMedia(String groupId,
      {int limit = 6}) async {
    await _assertGroupActive(groupId);
    final mediaMessages = await supabase
        .from('group_messages')
        .select('id,file_url,created_at')
        .eq('group_id', groupId)
        .not('file_url', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);

    // Handle signed URLs with query params
    const imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'};
    final images = mediaMessages.where((msg) {
      final url = (msg['file_url'] as String?)?.toLowerCase();
      if (url == null) return false;
      final path = url.split('?').first; // strip query
      final ext = path.split('.').last;
      return imageExtensions.contains(ext);
    }).toList();

    return List<Map<String, dynamic>>.from(images);
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final data = await supabase
        .from('group_memberships_summary')
        .select('user_id, role, display_name, photo_url')
        .eq('group_id', groupId)
        .order('display_name', ascending: true);

    return List<Map<String, dynamic>>.from(data);
  }

  // ---------- Mutations ----------

  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? photoUrl,
  }) async {
    await _assertGroupActive(groupId);

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (photoUrl != null) updates['photo_url'] = photoUrl;

    if (updates.isEmpty) return;

    await supabase.from('groups').update(updates).eq('id', groupId);
  }

  Future<void> joinGroup(String groupId) async {
    await _assertGroupActive(groupId);

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final group = await getGroupById(groupId);
    if (group == null) throw Exception('Group not found');

    if (group.visibility == 'public') {
      await supabase.from('group_memberships').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': 'member',
        'status': 'approved',
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });
    } else if (group.visibility == 'request') {
      final existing = await supabase
          .from('group_requests')
          .select('id')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('You already requested to join this group.');
      }

      await supabase.from('group_requests').insert({
        'group_id': groupId,
        'user_id': userId,
      });
    } else {
      throw Exception('This group is invite only.');
    }
  }

  Future<void> leaveGroup(String groupId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await supabase
        .from('group_memberships')
        .delete()
        .eq('user_id', userId)
        .eq('group_id', groupId);
  }

  Future<void> deleteGroup(String groupId) async {
    // (Server enforces permission / archive status via RLS/Edge)
    final url = Uri.parse(
      'https://vhzcbqgehlpemdkvmzvy.supabase.co/functions/v1/clever-responder',
    );

    final accessToken = supabase.auth.currentSession?.accessToken;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'groupId': groupId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Group deletion failed: ${response.body}');
    }
  }

  Future<String> getMyGroupRole(String groupId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return 'none';
    final res = await supabase
        .from('group_memberships')
        .select('role')
        .eq('user_id', userId)
        .eq('group_id', groupId)
        .maybeSingle();
    return res?['role'] ?? 'none';
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _assertGroupActive(groupId);
    await supabase.rpc('remove_group_member', params: {
      'p_group_id': groupId,
      'p_user_id': userId,
    });
  }

  Future<void> setMemberRole(
      String groupId, String userId, String newRole) async {
    await _assertGroupActive(groupId);

    final actingUserId = supabase.auth.currentUser?.id;
    if (actingUserId == null) {
      log.e('Role update failed: not authenticated');
      throw Exception('Not authenticated');
    }

    try {
      await supabase.rpc(
        'promote_user_to_role',
        params: {
          'p_group_id': groupId,
          'p_user_id': userId,
          'p_new_role': newRole,
        },
      );
      log.i('Role updated to "$newRole" for $userId in $groupId by $actingUserId');
    } on PostgrestException catch (e) {
      log.e('RPC failed: ${e.message}');
      throw Exception('Failed to update role: ${e.message}');
    } catch (e) {
      log.e('Unexpected error: $e');
      throw Exception('Unexpected error updating role: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingMembers(String groupId) async {
    final res = await supabase
        .from('group_memberships')
        .select('user_id, role, status, profiles(display_name, email)')
        .eq('group_id', groupId)
        .eq('status', 'pending')
        .order('joined_at');

    return (res as List)
        .map((e) => {
              'user_id': e['user_id'],
              'role': e['role'],
              'status': e['status'],
              'display_name': e['profiles']['display_name'],
              'email': e['profiles']['email'],
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getGroupJoinRequests(
      String groupId) async {
    final res = await supabase
        .from('group_requests')
        .select('user_id, created_at, profiles(display_name, email, photo_url)')
        .eq('group_id', groupId)
        .order('created_at');

    return (res as List)
        .map((e) => {
              'user_id': e['user_id'],
              'display_name': e['profiles']['display_name'],
              'photo_url': e['profiles']['photo_url'],
              'email': e['profiles']['email'],
              'created_at': e['created_at'],
            })
        .toList();
  }

  Future<void> approveMemberRequest(String groupId, String userId) async {
    await _assertGroupActive(groupId);
    await supabase.rpc('approve_group_member_request', params: {
      'p_group_id': groupId,
      'p_user_id': userId,
    });
  }

  Future<void> denyMemberRequest(String groupId, String userId) async {
    await _assertGroupActive(groupId);
    await supabase.rpc('deny_group_member_request', params: {
      'p_group_id': groupId,
      'p_user_id': userId,
    });
  }
}
