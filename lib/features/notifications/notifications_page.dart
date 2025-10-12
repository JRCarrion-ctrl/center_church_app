// File: lib/features/notifications/notifications_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:gql/ast.dart' show DocumentNode; // ⬅️ add this

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:ccf_app/routes/router_observer.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text("key_324".tr()),
          actions: [
            Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.done_all),
                  tooltip: "key_324a".tr(),
                  onPressed: () async {
                    final tabIndex = DefaultTabController.of(context).index;
                    final isApp = tabIndex == 0;
                    await _NotificationsTab.markAllAsRead(
                      context,
                      typeFilter: isApp ? 'app' : 'group',
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("key_325".tr())),
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

  /// Marks all unread as read for the current user, filtered by type.
  static Future<void> markAllAsRead(BuildContext context, {required String typeFilter}) async {
    final gql = GraphQLProvider.of(context).value;
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) return;

    // Two variants: group_* vs not group_*
    const mGroup = r'''
      mutation MarkAllGroupAsRead($uid: String!, $now: timestamptz!) {
        update_outgoing_notifications(
          where: {
            user_id: { _eq: $uid },
            status: { _eq: "sent" },
            read_at: { _is_null: true },
            type: { _like: "group_%" }
          },
          _set: { read_at: $now }
        ) { affected_rows }
      }
    ''';

    const mApp = r'''
      mutation MarkAllAppAsRead($uid: String!, $now: timestamptz!) {
        update_outgoing_notifications(
          where: {
            user_id: { _eq: $uid },
            status: { _eq: "sent" },
            read_at: { _is_null: true },
            _not: { type: { _like: "group_%" } }
          },
          _set: { read_at: $now }
        ) { affected_rows }
      }
    ''';

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final doc = gqlClientDoc(typeFilter == 'group' ? mGroup : mApp);

    final res = await gql.mutate(
      MutationOptions(
        document: doc,
        variables: {'uid': userId, 'now': nowIso},
      ),
    );
    if (res.hasException) {
      // Soft-fail to mirror original behavior; optionally show a toast.
      debugPrint('markAllAsRead error: ${res.exception}');
    }
  }

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> with RouteAware {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final gql = GraphQLProvider.of(context).value;
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    // Fetch only the tab’s slice to avoid client-side filtering
    const qGroup = r'''
      query MyGroupNotifications($uid: String!) {
        outgoing_notifications(
          where: {
            user_id: { _eq: $uid },
            status: { _eq: "sent" },
            type: { _like: "group_%" }
          },
          order_by: { scheduled_at: desc }
        ) {
          id
          title
          body
          scheduled_at
          read_at
          data
          type
        }
      }
    ''';

    const qApp = r'''
      query MyAppNotifications($uid: String!) {
        outgoing_notifications(
          where: {
            user_id: { _eq: $uid },
            status: { _eq: "sent" },
            _not: { type: { _like: "group_%" } }
          },
          order_by: { scheduled_at: desc }
        ) {
          id
          title
          body
          scheduled_at
          read_at
          data
          type
        }
      }
    ''';

    final doc = gqlClientDoc(widget.typeFilter == 'group' ? qGroup : qApp);

    try {
      final res = await gql.query(
        QueryOptions(
          document: doc,
          variables: {'uid': userId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (res.hasException) {
        debugPrint('fetchNotifications error: ${res.exception}');
        if (mounted) setState(() => loading = false);
        return;
      }

      final rows = (res.data?['outgoing_notifications'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          notifications = rows;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('fetchNotifications error: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deleteNotification(String id) async {
    final gql = GraphQLProvider.of(context).value;

    const m = r'''
      mutation DeleteNotification($id: uuid!) {
        delete_outgoing_notifications_by_pk(id: $id) { id }
      }
    ''';

    try {
      final res = await gql.mutate(
        MutationOptions(document: gqlClientDoc(m), variables: {'id': id}),
      );
      if (res.hasException) {
        debugPrint('delete error: ${res.exception}');
        return;
      }
      await fetchNotifications();
    } catch (e) {
      debugPrint('delete error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notifications.isEmpty) {
      return Center(child: Text("key_326".tr()));
    }

    return RefreshIndicator(
      onRefresh: fetchNotifications,
      child: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final item = notifications[index];
          return Dismissible(
            key: Key(item['id'] as String),
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
                  title: Text("key_327".tr()),
                  content: Text("key_328".tr()),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("key_329".tr())),
                    TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("key_330".tr())),
                  ],
                ),
              );
            },
            onDismissed: (_) async {
              await _deleteNotification(item['id'] as String);
            },
            child: _NotificationTile(
              id: item['id'] as String,
              title: (item['title'] ?? 'Untitled') as String,
              subtitle: (item['body'] ?? '') as String,
              data: item['data'] as Map<String, dynamic>?, // jsonb
              readAt: item['read_at'] as String?,
              scheduledAt: item['scheduled_at'] as String?,
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

// Small helper to ensure the doc is created via gql()
DocumentNode gqlClientDoc(String s) => gql(s);
