// File: lib/features/home/announcement_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/group_announcement.dart';

class AnnouncementService {
  final supabase = Supabase.instance.client;

  /// Fetch announcements for groups the user is in
  Future<List<GroupAnnouncement>> fetchGroupAnnouncements() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Get the groups the user is in
    final memberships = await supabase
        .from('group_memberships')
        .select('group_id')
        .eq('user_id', userId)
        .eq('status', 'approved');

    final groupIds = (memberships as List)
        .map((e) => e['group_id'] as String)
        .toSet();

    if (groupIds.isEmpty) return [];

    // Get announcements for those groups
    final data = await supabase
        .from('group_announcements')
        .select()
        .inFilter('group_id', groupIds.toList())
        .order('published_at', ascending: false);

    return (data as List)
        .map((e) => GroupAnnouncement.fromMap(e))
        .toList();
  }
}
