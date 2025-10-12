// File: lib/features/home/group_announcements_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/core/time_service.dart';
import '../../../app_state.dart';

class GroupAnnouncementsPage extends StatefulWidget {
  const GroupAnnouncementsPage({super.key});

  @override
  State<GroupAnnouncementsPage> createState() => _GroupAnnouncementsPageState();
}

class _GroupAnnouncementsPageState extends State<GroupAnnouncementsPage> {
  GraphQLClient? _gql;
  String? _userId;

  bool _loading = true;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gql ??= GraphQLProvider.of(context).value;
    _userId ??= context.read<AppState>().profile?.id;
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    if (_gql == null) return;

    final userId = _userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // 1) memberships -> group_ids
      const qMemberships = r'''
        query MyApprovedMemberships($uid: String!) {
          group_memberships(where: {user_id: {_eq: $uid}, status: {_eq: "approved"}}) {
            group_id
          }
        }
      ''';
      final res1 = await _gql!.query(
        QueryOptions(
          document: gql(qMemberships),
          variables: {'uid': userId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (res1.hasException) throw res1.exception!;
      final groupIds = (res1.data?['group_memberships'] as List<dynamic>? ?? [])
          .map((m) => (m as Map<String, dynamic>)['group_id'] as String)
          .toList();

      if (groupIds.isEmpty) {
        if (mounted) {
          setState(() {
            _announcements = [];
            _loading = false;
          });
        }
        return;
      }

      // 2) announcements for those groups, published_at <= now
      const qAnnouncements = r'''
        query GroupAnnouncements($groupIds: [uuid!]!, $now: timestamptz!) {
          announcements(
            where: { group_id: { _in: $groupIds }, published_at: { _lte: $now } }
            order_by: { published_at: desc }
          ) {
            id
            group_id
            title
            body
            published_at
          }
        }
      ''';

      final res2 = await _gql!.query(
        QueryOptions(
          document: gql(qAnnouncements),
          variables: {
            'groupIds': groupIds,
            'now': DateTime.now().toUtc().toIso8601String(),
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (res2.hasException) throw res2.exception!;

      final rows = (res2.data?['announcements'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _announcements = rows;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading group announcements: $e');
      if (mounted) setState(() => _loading = false);
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
                          (a['title'] ?? '') as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: a['published_at'] != null
                            ? Text(
                                TimeService.formatUtcToLocal(
                                  DateTime.parse(a['published_at'] as String),
                                  pattern: 'MMM d, yyyy • h:mm a',
                                ),
                              )
                            : null,
                        childrenPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        children: [
                          if ((a['body'] ?? '') is String && (a['body'] as String).isNotEmpty)
                            Text(a['body'] as String),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
