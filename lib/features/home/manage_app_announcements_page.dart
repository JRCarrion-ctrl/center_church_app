import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/app_announcement_form_modal.dart';
import 'package:easy_localization/easy_localization.dart';

class ManageAppAnnouncementsPage extends StatefulWidget {
  const ManageAppAnnouncementsPage({super.key});

  @override
  State<ManageAppAnnouncementsPage> createState() => _ManageAppAnnouncementsPageState();
}

class _ManageAppAnnouncementsPageState extends State<ManageAppAnnouncementsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> announcements = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => loading = true);
    try {
      final result = await supabase
          .from('app_announcements')
          .select()
          .order('published_at', ascending: false);

      if (mounted) {
        setState(() {
          announcements = List<Map<String, dynamic>>.from(result);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading app announcements: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    try {
      await supabase.from('app_announcements').delete().eq('id', id);
      await _loadAnnouncements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_181".tr())),
        );
      }
    } catch (e) {
      debugPrint('Deletion error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_182".tr())),
        );
      }
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AppAnnouncementFormModal(existing: existing),
    );

    if (result != null) {
      _loadAnnouncements();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_183".tr())),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnnouncements,
              child: announcements.isEmpty
                  ? Center(child: Text("key_184".tr()))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: announcements.length,
                      itemBuilder: (context, i) {
                        final a = announcements[i];
                        final id = a['id'];
                        final title = a['title'] ?? '';
                        final body = a['body'] ?? '';
                        final published = DateTime.tryParse(a['published_at'] ?? '')?.toLocal();
                        final imageUrl = a['image_url'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () => _openForm(existing: a),
                            leading: imageUrl != null
                                ? Image.network(imageUrl, width: 60, fit: BoxFit.cover)
                                : const Icon(Icons.announcement, size: 40),
                            title: Text(title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (body.isNotEmpty)
                                  Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                                if (published != null)
                                  Text(
                                    'Published: ${DateFormat('MMM d, yyyy • h:mm a').format(published)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  await _openForm(existing: a);
                                } else if (action == 'delete' && id != null) {
                                  await _deleteAnnouncement(id);
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Text("key_185".tr())),
                                PopupMenuItem(value: 'delete', child: Text("key_186".tr())),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text("key_187".tr()),
      ),
    );
  }
}
