// File: lib/features/home/manage_app_announcements_page.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'models/app_announcement_form_modal.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ManageAppAnnouncementsPage extends StatefulWidget {
  const ManageAppAnnouncementsPage({super.key});

  @override
  State<ManageAppAnnouncementsPage> createState() => _ManageAppAnnouncementsPageState();
}

class _ManageAppAnnouncementsPageState extends State<ManageAppAnnouncementsPage> {
  GraphQLClient? _gql;
  List<Map<String, dynamic>> announcements = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    // actual load kicked off once GraphQLProvider is available
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gql ??= GraphQLProvider.of(context).value;
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    final client = _gql;
    if (client == null) return;

    setState(() => loading = true);

    const q = r'''
      query AllAppAnnouncements {
        app_announcements(order_by: { published_at: desc }) {
          id
          title
          body
          image_url
          published_at
        }
      }
    ''';

    try {
      final res = await client.query(
        QueryOptions(document: gql(q), fetchPolicy: FetchPolicy.networkOnly),
      );
      if (res.hasException) throw res.exception!;

      final rows = (res.data?['app_announcements'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          announcements = rows;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading app announcements: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    final client = _gql;
    if (client == null) return;

    const m = r'''
      mutation DeleteAppAnnouncement($id: uuid!) {
        delete_app_announcements_by_pk(id: $id) { id }
      }
    ''';

    try {
      final res = await client.mutate(
        MutationOptions(document: gql(m), variables: {'id': id}),
      );
      if (res.hasException) throw res.exception!;
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
                        final id = a['id'] as String?;
                        final title = (a['title'] ?? '') as String;
                        final body = (a['body'] ?? '') as String;
                        final publishedStr = a['published_at'] as String?;
                        final published = publishedStr != null
                            ? DateTime.tryParse(publishedStr)?.toLocal()
                            : null;
                        final imageUrl = a['image_url'] as String?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () => _openForm(existing: a),
                            leading: imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8), // Add rounded corners for a modern look
                                    child: SizedBox(
                                      height: 40,
                                      width: 40, // Constrain the size to fit well in the ListTile
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2), 
                                        ),
                                        errorWidget: (context, url, error) => const Center(
                                          child: Icon(Icons.broken_image, size: 24),
                                        ),
                                      ),
                                    ),
                                  )
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
