import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:easy_localization/easy_localization.dart';

class GroupAnnouncementsPage extends StatefulWidget {
  const GroupAnnouncementsPage({super.key});

  @override
  State<GroupAnnouncementsPage> createState() => _GroupAnnouncementsPageState();
}

class _GroupAnnouncementsPageState extends State<GroupAnnouncementsPage> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final memberships = await supabase
          .from('group_memberships')
          .select('group_id')
          .eq('user_id', userId)
          .eq('status', 'approved');

      final groupIds = (memberships as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => m['group_id'] as String)
          .toList();

      if (groupIds.isEmpty) {
        setState(() {
          _announcements = [];
          _loading = false;
        });
        return;
      }

      final results = await supabase
          .from('group_announcements')
          .select()
          .inFilter('group_id', groupIds)
          .lte('published_at', now)
          .order('published_at', ascending: false);

      setState(() {
        _announcements = List<Map<String, dynamic>>.from(results);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading group announcements: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_194".tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? Center(child: Text("key_195".tr()))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _announcements.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final a = _announcements[index];
                    return Card(
                      child: ExpansionTile(
                        title: Text(
                          a['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: a['published_at'] != null
                            ? Text(TimeService.formatUtcToLocal(
                                DateTime.parse(a['published_at']),
                                pattern: 'MMM d, yyyy • h:mm a'))
                            : null,
                        childrenPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        children: [
                          if (a['body'] != null) Text(a['body']),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
