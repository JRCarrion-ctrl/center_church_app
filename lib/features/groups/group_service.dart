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

  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (photoUrl != null) updates['photo_url'] = photoUrl;

    if (updates.isEmpty) return; // Nothing to update

    await supabase
        .from('groups')
        .update(updates)
        .eq('id', groupId);
  }

  Future<Map<String, dynamic>?> getPinnedMessage(String groupId) async {
    final group = await supabase
        .from('groups')
        .select('pinned_message_id')
        .eq('id', groupId)
        .maybeSingle();

    final pinnedId = group?['pinned_message_id'];
    if (pinnedId == null) return null;

    final result = await supabase
        .from('group_messages')
        .select('content,sender_id,created_at')
        .eq('id', pinnedId)
        .maybeSingle();

    if (result == null) return null;

    // Get sender display name
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
    final events = await supabase
        .from('group_events')
        .select('id,title,event_date,location,image_url')
        .eq('group_id', groupId)
        .order('event_date', ascending: true)
        .limit(3); // Only show next 3 events

    return List<Map<String, dynamic>>.from(events);
  }

  Future<List<Map<String, dynamic>>> getGroupAnnouncements(String groupId) async {
    final announcements = await supabase
        .from('group_announcements')
        .select('id,title,body,image_url,published_at,created_at')
        .eq('group_id', groupId)
        .order('published_at', ascending: false)
        .limit(3); // Only show latest 3 announcements

    return List<Map<String, dynamic>>.from(announcements);
  }

  Future<List<Map<String, dynamic>>> getRecentGroupMedia(String groupId, {int limit = 6}) async {
    final mediaMessages = await supabase
        .from('group_messages')
        .select('id,file_url,created_at')
        .eq('group_id', groupId)
        .not('file_url', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);

    // Only return rows that are actual image files (e.g., jpg, png, webp, etc.)
    final imageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'];
    final images = mediaMessages.where((msg) {
      if (msg['file_url'] == null) return false;
      final ext = msg['file_url'].toString().split('.').last.toLowerCase();
      return imageExtensions.contains(ext);
    }).toList();

    return List<Map<String, dynamic>>.from(images);
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final data = await supabase
        .from('group_memberships')
        .select('user_id, role, profiles(display_name)')
        .eq('group_id', groupId)
        .eq('status', 'approved')
        .order('profiles.display_name', ascending: true);

    debugPrint('Fetching members for groupId: $groupId');    
    debugPrint('Fetched group members: $data');

    // The returned data will have profiles nested, so flatten:
    return List<Map<String, dynamic>>.from(data.map((e) => {
      'user_id': e['user_id'],
      'role': e['role'],
      'display_name': e['profiles']?['display_name'] ?? 'Unnamed User',
    }));
  }
}
