import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/core/time_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Notifications'),
          actions: [
            Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.done_all),
                  tooltip: 'Mark all as read',
                  onPressed: () async {
                    final tabIndex = DefaultTabController.of(context).index;
                    final isApp = tabIndex == 0;
                    await _NotificationsTab.markAllAsRead(
                      typeFilter: isApp ? 'app' : 'group',
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Marked all as read')),
                      );
                    }
                  },
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'App'),
              Tab(text: 'Groups'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _NotificationsTab(typeFilter: 'app'),
            _NotificationsTab(typeFilter: 'group'),
          ],
        ),
      ),
    );
  }
}

class _NotificationsTab extends StatefulWidget {
  final String typeFilter; // 'app' or 'group'
  const _NotificationsTab({required this.typeFilter});

  static Future<void> markAllAsRead({required String typeFilter}) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final result = await supabase
      .from('outgoing_notifications')
      .select('id, type')
      .eq('user_id', userId)
      .eq('status', 'sent');

    final filtered = result.where((n) => n['read_at'] == null).toList();

    final idsToUpdate = filtered
      .where((n) {
        final type = n['type'] as String?;
        return typeFilter == 'app'
            ? !(type?.startsWith('group_') ?? false)
            : (type?.startsWith('group_') ?? false);
      })
      .map((n) => n['id'] as String)
      .toList();

    if (idsToUpdate.isEmpty) return;

    // Perform update per ID if `.in_()` isn't available
    for (final id in idsToUpdate) {
      await supabase
          .from('outgoing_notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    }
  }

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;

  Future<void> fetchNotifications() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final result = await supabase
        .from('outgoing_notifications')
        .select('id, title, body, scheduled_at, read_at, data, type')
        .match({
          'user_id': userId,
          'status': 'sent',
        })
        .order('scheduled_at', ascending: false);

    final filtered = result.where((n) {
      final type = n['type'] as String?;
      if (widget.typeFilter == 'app') {
        return !(type?.startsWith('group_') ?? false);
      } else {
        return type?.startsWith('group_') ?? false;
      }
    }).toList();

    if (mounted) {
      setState(() {
        notifications = filtered;
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notifications.isEmpty) {
      return const Center(child: Text('No notifications yet.'));
    }

    return RefreshIndicator(
      onRefresh: fetchNotifications,
      child: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final item = notifications[index];
          return Dismissible(
            key: Key(item['id']),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Notification?'),
                  content: const Text('This will remove the notification from your feed.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                  ],
                ),
              );
            },
            onDismissed: (_) async {
              await Supabase.instance.client
                  .from('outgoing_notifications')
                  .delete()
                  .eq('id', item['id']);
              await fetchNotifications();
            },
            child: _NotificationTile(
              id: item['id'],
              title: item['title'] ?? 'Untitled',
              subtitle: item['body'] ?? '',
              data: item['data'] as Map<String, dynamic>?,
              readAt: item['read_at'],
              scheduledAt: item['scheduled_at'],
              onRead: fetchNotifications,
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String id;
  final String title;
  final String subtitle;
  final Map<String, dynamic>? data;
  final String? readAt;
  final String? scheduledAt;
  final VoidCallback onRead;

  const _NotificationTile({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.data,
    required this.readAt,
    required this.scheduledAt,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = readAt == null;
    final titleStyle = isUnread
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.titleMedium;

    final timestamp = TimeService.formatRelativeTime(
      DateTime.tryParse(scheduledAt ?? '') ?? DateTime.now(),
    );

    return ListTile(
      leading: Icon(
        isUnread ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
        color: isUnread ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      title: Text(title, style: titleStyle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          if (timestamp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(timestamp, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
