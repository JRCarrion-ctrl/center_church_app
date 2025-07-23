// File: lib/features/home/announcements_section.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ccf_app/app_state.dart';

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
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    setState(() => loading = true);

    try {
      // Check admin role
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      isAdmin = profile != null &&
          (profile['role'] == 'supervisor' || profile['role'] == 'owner');

      // Fetch main/global announcements
      final global = await supabase
          .from('app_announcements')
          .select()
          .lte('published_at', nowUtc)
          .order('published_at', ascending: false);

      // Get group IDs the user is approved in
      final memberships = await supabase
          .from('group_memberships')
          .select('group_id')
          .eq('user_id', userId)
          .eq('status', 'approved');

      final groupIds = (memberships as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => m['group_id'] as String)
          .toList();

      List<dynamic> groups = [];
      if (groupIds.isNotEmpty) {
        groups = await supabase
            .from('group_announcements')
            .select()
            .inFilter('group_id', groupIds)
            .lte('published_at', nowUtc)
            .order('published_at', ascending: false);
      }

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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final showGroupAnnouncements = appState.showGroupAnnouncements;

    final hasMain = mainAnnouncements.isNotEmpty;
    final hasGroup = groupAnnouncements.isNotEmpty;

    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            if (!hasMain && !hasGroup)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No announcements available.'),
              ),
            if (hasMain)
              ...mainAnnouncements.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildAnnouncementCard(a),
                  )),
            if (showGroupAnnouncements && hasGroup) ...[
              const SizedBox(height: 20),
              const Text(
                'Group Announcements',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildGroupList(),
            ],
          ],
        ),
      ),
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
            onPressed: () => GoRouter.of(context).push('/manage-app-announcements'),
            child: const Text('Manage'),
          ),
      ],
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> a) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(
          a['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          if (a['body'] != null) Text(a['body']),
        ],
      ),
    );
  }

  Widget _buildGroupList() {
    return Center(
      child: SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: groupAnnouncements.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final a = groupAnnouncements[index];
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final backgroundColor =
                isDark ? Colors.blueGrey[900] : Colors.blue[50];

            return Material(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (!mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showDialog(
                      context: context,
                      useRootNavigator: false,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(a['title'] ?? ''),
                        content: Text(a['body'] ?? ''),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  });
                },
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      if (a['body'] != null)
                        Text(
                          a['body'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
