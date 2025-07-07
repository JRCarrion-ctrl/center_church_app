// File: lib/features/home/announcements_section.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:ccf_app/features/media/services/livestream_update_service.dart';

class AnnouncementsSection extends StatefulWidget {
  const AnnouncementsSection({super.key});

  @override
  State<AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends State<AnnouncementsSection> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> mainAnnouncements = [];
  List<Map<String, dynamic>> groupAnnouncements = [];
  bool loading = true;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkLivestreamUpdate();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = supabase.auth.currentUser?.id;
    final now = DateTime.now().toUtc().toIso8601String();
    if (userId == null) return;
    setState(() => loading = true);

    try {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      isAdmin = profile != null &&
          (profile['role'] == 'supervisor' || profile['role'] == 'owner');

      final global = await supabase
          .from('app_announcements')
          .select()
          .lte('published_at', now)
          .order('published_at', ascending: false);

      final memberships = await supabase
          .from('group_memberships')
          .select('group_id')
          .eq('user_id', userId)
          .eq('status', 'approved');

      final groupIds = (memberships as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((m) => m['group_id'] as String)
          .toList();

      final groups = await supabase
          .from('group_announcements')
          .select()
          .inFilter('group_id', groupIds)
          .lte('published_at', now)
          .order('published_at', ascending: false);

      if (mounted) {
        setState(() {
          mainAnnouncements = List<Map<String, dynamic>>.from(global);
          groupAnnouncements = List<Map<String, dynamic>>.from(groups);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _checkLivestreamUpdate() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (profile?['role'] == 'supervisor' || profile?['role'] == 'owner') {
      await LivestreamUpdateService.maybeTriggerUpdate();
    }
  }


  @override
  Widget build(BuildContext context) {
    if (loading) return const CircularProgressIndicator();
    final hasMain = mainAnnouncements.isNotEmpty;
    final hasGroup = groupAnnouncements.isNotEmpty;
    if (!hasMain && !hasGroup) {
      return const Center(child: Text('No announcements available.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        if (mainAnnouncements.isEmpty)
          const Text('No announcements')
        else
          ...mainAnnouncements.map(_buildAnnouncementCard),
        const SizedBox(height: 20),
        const Text(
          'Group Announcements',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildGroupList(),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Announcements',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (isAdmin)
          TextButton(
            onPressed: () {
              GoRouter.of(context).push('/manage-app-announcements');
            },
            child: const Text('Manage'),
          ),
      ],
    );
  }

  Widget _buildGroupList() {
    if (groupAnnouncements.isEmpty) {
      return const Center(child: Text('No group announcements'));
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groupAnnouncements.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _buildGroupCard(groupAnnouncements[index]),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> a) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (a['body'] != null) Text(a['body']),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> a) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue[50],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (a['body'] != null)
            Text(a['body'], maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
