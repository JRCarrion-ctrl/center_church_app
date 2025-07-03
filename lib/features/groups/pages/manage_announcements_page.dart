// File: manage_announcements_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_announcement.dart';
import '../widgets/announcement_form_modal.dart';

class ManageAnnouncementsPage extends StatefulWidget {
  final String groupId;

  const ManageAnnouncementsPage({super.key, required this.groupId});

  @override
  State<ManageAnnouncementsPage> createState() => _ManageAnnouncementsPageState();
}

class _ManageAnnouncementsPageState extends State<ManageAnnouncementsPage> {
  final supabase = Supabase.instance.client;
  List<GroupAnnouncement> announcements = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => loading = true);

    try {
      final response = await supabase
          .from('group_announcements')
          .select()
          .eq('group_id', widget.groupId)
          .order('published_at', ascending: true);

      announcements = (response as List)
          .map((item) => GroupAnnouncement.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load announcements: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _openForm({GroupAnnouncement? existing}) async {
    final result = await showModalBottomSheet<GroupAnnouncement>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AnnouncementFormModal(
        groupId: widget.groupId,
        existing: existing,
      ),
    );

    if (result != null) {
      await _loadAnnouncements();
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    await supabase.from('group_announcements').delete().eq('id', id);
    _loadAnnouncements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Announcements')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : announcements.isEmpty
              ? const Center(child: Text('No announcements found.'))
              : ListView.builder(
                  itemCount: announcements.length,
                  itemBuilder: (context, index) {
                    final a = announcements[index];
                    return ListTile(
                      title: Text(a.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (a.body != null) Text(a.body!),
                          if (a.publishedAt != null)
                            Text(
                              'Scheduled: ${a.publishedAt!.toLocal()}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                      onTap: () => _openForm(existing: a),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteAnnouncement(a.id),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
