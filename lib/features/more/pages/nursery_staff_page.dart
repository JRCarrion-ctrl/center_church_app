// File: lib/features/nursery/pages/nursery_staff_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';
import 'package:ccf_app/shared/user_roles.dart';

typedef CheckinHandler = void Function(String checkinId);

class NurseryStaffPage extends StatefulWidget {
  const NurseryStaffPage({super.key});

  @override
  State<NurseryStaffPage> createState() => _NurseryStaffPageState();
}

class _NurseryStaffPageState extends State<NurseryStaffPage> {
  bool _checkingRole = true;
  bool _authorized = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    // Wait for Provider tree to be available
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRole());
  }

  Future<void> _checkRole() async {
    // 1. Get user data from AppState
    final appState = context.read<AppState>();
    final uid = appState.profile?.id;

    if (!mounted) return;

    if (uid == null) {
      // User is not logged in
      return setState(() {
        _authorized = false;
        _checkingRole = false;
        _userId = null;
      });
    }
    
    _userId = uid;
    
    // 2. Use the AppState's role check (assuming this is populated securely on login)
    final role = appState.userRole;
    const allowedRoles = {UserRole.nurseryStaff, UserRole.owner, UserRole.supervisor};
    
    final isAuthorized = allowedRoles.contains(role);

    // 3. Set state based on local role check
    if (!mounted) return;
    setState(() {
      _authorized = isAuthorized;
      _checkingRole = false;
    });
  }

  Future<void> _checkout(String checkinId) async {
    try {
      final client = GraphQLProvider.of(context).value;
      const m = r'''
        mutation Checkout($id: uuid!, $uid: String!, $now: timestamptz!) {
          update_child_checkins_by_pk(
            pk_columns: { id: $id },
            _set: { check_out_time: $now, checked_out_by: $uid }
          ) { id }
        }
      ''';
      final res = await client.mutate(
        MutationOptions(
          document: gql(m),
          variables: {
            'id': checkinId,
            'uid': _userId,
            'now': DateTime.now().toUtc().toIso8601String(),
          },
        ),
      );

      if (!mounted) return;
      if (res.hasException || res.data?['update_child_checkins_by_pk'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('key_293a'))), // “Could not check out”
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('key_293b'))), // “Checked out”
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('key_293c'))), // “Something went wrong”
      );
    }
  }

  Future<void> _openOrCreateChat(String checkinId) async {
    try {
      final client = GraphQLProvider.of(context).value;

      // 1) Look for existing temp group
      const q = r'''
        query TempGroup($cid: uuid!) {
          nursery_temp_groups(where: { checkin_id: { _eq: $cid } }, limit: 1) {
            group_id
          }
        }
      ''';
      final resQ = await client.query(
        QueryOptions(document: gql(q), variables: {'cid': checkinId}),
      );

      String? groupId;
      final rows = (resQ.data?['nursery_temp_groups'] as List<dynamic>? ?? []);
      if (rows.isNotEmpty) {
        groupId = rows.first['group_id'] as String?;
      }

      // 2) If none, call your Hasura Action to create it (adjust name/return as needed)
      if (groupId == null) {
        const m = r'''
          mutation CreateNurseryTempGroup($cid: uuid!) {
            create_nursery_temp_group(checkin_id: $cid) { group_id }
          }
        ''';
        final resM = await client.mutate(
          MutationOptions(document: gql(m), variables: {'cid': checkinId}),
        );
        groupId = resM.data?['create_nursery_temp_group']?['group_id'] as String?;
      }

      if (groupId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('key_293f'))), // “Unable to open chat”
        );
        return;
      }

      if (!mounted) return;
      context.push('/groups/$groupId');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('key_293e'))), // generic error
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('key_294'))), // "Check-Ins"
        body: Center(child: Text(tr('key_012'))),   // "Error" (no access)
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('key_294'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await context.push('/nursery/qr_checkin');
          if (!mounted) return;
          if (res != null) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('key_313'))), // “Check-In Successful”
            );
          }
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(tr('key_314')),
      ),
      body: _ActiveCheckinsList(
        onCheckout: _checkout,
        onOpenChat: _openOrCreateChat,
      ),
    );
  }
}

class _ActiveCheckinsList extends StatelessWidget {
  const _ActiveCheckinsList({
    required this.onCheckout,
    required this.onOpenChat,
  });

  final void Function(String checkinId) onCheckout;
  final void Function(String checkinId) onOpenChat;

  // Hasura subscription that joins child profiles for display data
  static const _sub = r'''
    subscription ActiveCheckins {
      child_checkins(
        where: { check_out_time: { _is_null: true } }
        order_by: { check_in_time: desc }
      ) {
        id
        child_id
        check_in_time
        child: child_profiles {
          id
          display_name
          photo_url
          allergies
        }
      }
    }
  ''';

  @override
  Widget build(BuildContext context) {
    return Subscription(
      options: SubscriptionOptions(document: gql(_sub)),
      builder: (result) {
        if (result.isLoading && result.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (result.hasException) {
          return Center(child: Text(tr('key_012'))); // “Error”
        }

        final rows = (result.data?['child_checkins'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        if (rows.isEmpty) {
          return Center(child: Text(tr('key_315a'), style: Theme.of(context).textTheme.titleMedium,),);
        } //No Check-Ins

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final row = rows[i];
            final checkinId = (row['id'] ?? '').toString();
            final child = row['child'] as Map<String, dynamic>?;
            final name = (child?['display_name'] ?? '—').toString();
            final photoUrl = child?['photo_url'] as String?;
            final allergies = (child?['allergies'] ?? '').toString();

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.child_care)
                    : null,
              ),
              title: Text(name),
              subtitle: allergies.isEmpty
                  ? null
                  : Text(tr('key_253', args: [allergies])), // “Allergies: {}”
              onTap: () => onOpenChat(checkinId),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => onOpenChat(checkinId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => onCheckout(checkinId),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
// TODO: Action to create chat