// File: lib/features/home/manage_app_announcements_page.dart
import 'dart:ui'; // ✨ Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'models/app_announcement_form_modal.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class ManageAppAnnouncementsPage extends StatefulWidget {
  const ManageAppAnnouncementsPage({super.key});

  @override
  State<ManageAppAnnouncementsPage> createState() => _ManageAppAnnouncementsPageState();
}

class _ManageAppAnnouncementsPageState extends State<ManageAppAnnouncementsPage> {
  GraphQLClient? _gql;
  List<Map<String, dynamic>> announcements = [];
  bool loading = true;
  String? _expandedId;
  String _filter = 'all';

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
          target_audiences
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
      _loadAnnouncements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_181".tr())));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_182".tr())));
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // ✨ Transparent background for the blur
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AppAnnouncementFormModal(existing: existing),
      ),
    );

    if (result != null) _loadAnnouncements();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Filtering logic
    final filtered = announcements.where((a) {
      final pubDate = DateTime.tryParse(a['published_at'] ?? '')?.toLocal();
      if (_filter == 'published') return pubDate != null && pubDate.isBefore(now);
      if (_filter == 'scheduled') return pubDate != null && pubDate.isAfter(now);
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("key_183".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'all', label: Text("key_130".tr())),
                ButtonSegment(value: 'published', label: Text("key_131".tr())),
                ButtonSegment(value: 'scheduled', label: Text("key_132".tr())),
              ],
              selected: {_filter},
              onSelectionChanged: (val) => setState(() => _filter = val.first),
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: loading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : RefreshIndicator(
                    onRefresh: _loadAnnouncements,
                    child: filtered.isEmpty
                        ? ListView(
                            children: [
                              // ✨ FIX: Wrap Center in Padding to use the padding parameter
                              Padding(
                                padding: const EdgeInsets.only(top: 100),
                                child: Center(
                                  child: Text("key_184".tr()),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) => _buildGlassCard(filtered[i], colorScheme, isDark, now),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text("key_187".tr()),
      ),
    );
  }

  Widget _buildGlassCard(Map<String, dynamic> a, ColorScheme colors, bool isDark, DateTime now) {
    final id = a['id'] as String;
    final isExpanded = _expandedId == id;
    final pubDate = DateTime.tryParse(a['published_at'] ?? '')?.toLocal();
    final isPublished = pubDate != null && pubDate.isBefore(now);
    final targetAudience = (a['target_audiences'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
            child: InkWell(
              onTap: () => setState(() => _expandedId = isExpanded ? null : id),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (a['image_url'] != null && !isExpanded)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: a['image_url'],
                                width: 50, height: 50, fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (pubDate != null)
                                    Text(
                                      isPublished ? "key_131".tr() : "key_132".tr(),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPublished ? Colors.green : Colors.orange),
                                    ),
                                  if (targetAudience.isNotEmpty)
                                    Text(
                                      targetAudience.map((l) => l == 'english' ? 'EN' : 'ES').join(' & '),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.tertiary),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: colors.outline),
                      ],
                    ),
                    if (isExpanded) ...[
                      const SizedBox(height: 16),
                      if (a['image_url'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(imageUrl: a['image_url'], fit: BoxFit.cover),
                        ),
                      const SizedBox(height: 12),
                      SelectableLinkify(
                        text: a['body'] ?? '',
                        style: TextStyle(color: colors.onSurface),
                        onOpen: (link) => launchUrl(Uri.parse(link.url)),
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton.filledTonal(onPressed: () => _openForm(existing: a), icon: const Icon(Icons.edit, size: 20)),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () => _deleteAnnouncement(id),
                            icon: Icon(Icons.delete_outline, size: 20, color: colors.error),
                          ),
                        ],
                      )
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}