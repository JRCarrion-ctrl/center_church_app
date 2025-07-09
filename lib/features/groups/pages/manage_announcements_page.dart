// File: manage_announcements_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  List<GroupAnnouncement> allAnnouncements = [];
  bool loading = true;
  String filter = 'all'; // 'all', 'published', 'scheduled'

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
          .select('*, profiles(display_name)')
          .eq('group_id', widget.groupId)
          .order('published_at', ascending: true);

      allAnnouncements = (response as List)
          .map((item) => GroupAnnouncement.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load announcements')),
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

  Future<void> _confirmAndDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: const Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await supabase.from('group_announcements').delete().eq('id', id);
      _loadAnnouncements();
    }
  }

  List<GroupAnnouncement> get filteredAnnouncements {
    final now = DateTime.now().toUtc();
    return allAnnouncements.where((a) {
      if (filter == 'published') {
        return a.publishedAt != null && a.publishedAt!.isBefore(now);
      } else if (filter == 'scheduled') {
        return a.publishedAt != null && a.publishedAt!.isAfter(now);
      }
      return true;
    }).toList();
  }

  Widget _buildFilterButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'all', label: Text('All')),
          ButtonSegment(value: 'published', label: Text('Published')),
          ButtonSegment(value: 'scheduled', label: Text('Scheduled')),
        ],
        selected: {filter},
        onSelectionChanged: (v) => setState(() => filter = v.first),
        showSelectedIcon: false,
      ),
    );
  }

  Widget _buildAnnouncementTile(GroupAnnouncement a) {
    final isPublished = a.publishedAt?.isBefore(DateTime.now().toUtc()) ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (a.body != null)
              Text(a.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (a.publishedAt != null)
              Text(
                '${isPublished ? 'Published' : 'Scheduled'}: ${DateFormat.yMMMd().format(a.publishedAt!.toLocal())}',
                style: TextStyle(
                  fontSize: 12,
                  color: isPublished ? Colors.green[700] : Colors.orange[700],
                ),
              ),
            if (a.createdByName != null)
              Text(
                'Posted by ${a.createdByName!}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        onTap: () => _openForm(existing: a),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmAndDelete(a.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Announcements')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnnouncements,
              child: Column(
                children: [
                  _buildFilterButtons(),
                  Expanded(
                    child: filteredAnnouncements.isEmpty
                        ? const Center(child: Text('No announcements found.'))
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: filteredAnnouncements.length,
                            itemBuilder: (context, i) =>
                                _buildAnnouncementTile(filteredAnnouncements[i]),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}
