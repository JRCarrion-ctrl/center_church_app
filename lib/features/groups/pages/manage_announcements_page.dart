// File: manage_announcements_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/core/time_service.dart';
import '../models/group_announcement.dart';
import '../widgets/announcement_form_modal.dart';
import 'package:easy_localization/easy_localization.dart';

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

  DateTime get _nowUtc => DateTime.now().toUtc();

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
        title: Text("key_126".tr()),
        content: Text("key_127".tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("key_128".tr())),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("key_129".tr())),
        ],
      ),
    );

    if (confirmed == true) {
      await supabase.from('group_announcements').delete().eq('id', id);
      _loadAnnouncements();
    }
  }

  List<GroupAnnouncement> get filteredAnnouncements {
    return allAnnouncements.where((a) {
      if (filter == 'published') {
        return a.publishedAt != null && a.publishedAt!.isBefore(_nowUtc);
      } else if (filter == 'scheduled') {
        return a.publishedAt != null && a.publishedAt!.isAfter(_nowUtc);
      }
      return true;
    }).toList();
  }

  Widget _buildFilterButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'all', label: Text("key_130".tr())),
          ButtonSegment(value: 'published', label: Text("key_131".tr())),
          ButtonSegment(value: 'scheduled', label: Text("key_132".tr())),
        ],
        selected: {filter},
        onSelectionChanged: (v) => setState(() => filter = v.first),
        showSelectedIcon: false,
      ),
    );
  }

  Widget _buildAnnouncementTile(GroupAnnouncement a) {
    final isPublished = a.publishedAt?.isBefore(_nowUtc) ?? false;

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
                '${isPublished ? "key_131".tr() : "key_132".tr()}: ${TimeService.formatUtcToLocal(a.publishedAt!, pattern: 'MMM d, y')}',
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
      appBar: AppBar(title: Text("key_133".tr())),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnnouncements,
              child: Column(
                children: [
                  _buildFilterButtons(),
                  Expanded(
                    child: filteredAnnouncements.isEmpty
                        ? Center(child: Text("key_134".tr()))
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
        label: Text("key_135".tr()),
      ),
    );
  }
}
