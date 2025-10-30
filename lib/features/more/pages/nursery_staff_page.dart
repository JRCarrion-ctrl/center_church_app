// File: lib/features/nursery/pages/nursery_staff_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:logger/logger.dart'; 

import '../../../app_state.dart';
import 'package:ccf_app/shared/user_roles.dart';
// import '../../../core/app_keys.dart'; // <--- Import your AppKeys file

final logger = Logger(); // <--- Initialize your logger

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRole());
  }

  Future<void> _checkRole() async {
    // Synchronous context access is fine, but check 'mounted' before 'setState'
    final appState = context.read<AppState>();
    String? uid;
    
    try {
      uid = appState.profile?.id;
      
      if (!mounted) {
        logger.w('NurseryStaffPage disposed before role check completed.');
        return;
      }
      
      // 1. Handle not logged in case
      if (uid == null) {
        setState(() {
          _authorized = false;
          _checkingRole = false;
          _userId = null;
        });
        logger.i('User not logged in. Access denied.');
        return;
      }
      
      _userId = uid;
      
      // 2. Use the AppState's role check
      final role = appState.userRole;
      const allowedRoles = {UserRole.nurseryStaff, UserRole.owner, UserRole.supervisor};
      
      final isAuthorized = allowedRoles.contains(role);

      // 3. Set state based on local role check
      setState(() {
        _authorized = isAuthorized;
        _checkingRole = false;
      });
      
      if (!isAuthorized) {
        logger.w('User $_userId access denied. Role: $role');
      } else {
        logger.i('User $_userId authorized as $role.');
      }

    } catch (e, stack) {
      logger.e('Error during role check:', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _authorized = false;
          _checkingRole = false;
        });
      }
      // You could show a generic error SnackBar here if needed
    }
  }

  Future<void> _checkout(String checkinId) async {
    const checkoutMutation = r'''
      mutation Checkout($id: uuid!, $uid: String!, $now: timestamptz!) {
        update_child_checkins_by_pk(
          pk_columns: { id: $id },
          _set: { check_out_time: $now, checked_out_by: $uid }
        ) { id }
      }
    ''';
    
    try {
      final client = GraphQLProvider.of(context).value;
      
      final variables = {
        'id': checkinId,
        'uid': _userId,
        'now': DateTime.now().toUtc().toIso8601String(), 
      };

      final res = await client.mutate(
        MutationOptions(
          document: gql(checkoutMutation),
          variables: variables,
        ),
      );

      if (!mounted) return;

      if (res.hasException) {
        // Log the full exception for debugging
        logger.e('GraphQL Exception during checkout for $checkinId:', error: res.exception);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('key_293a'))), // “Could not check out”
        );
        return;
      } 
      
      if (res.data?['update_child_checkins_by_pk'] == null) {
        // Handle successful GraphQL query but no rows affected
        logger.w('Checkout failed for $checkinId: Checkin not found or not updated.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('key_293a'))), // “Could not check out”
        );
      } else {
        logger.i('Successfully checked out child for checkin $checkinId.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('key_293b'))), // “Checked out”
        );
      }
    } catch (e, stack) {
      // Log generic network or parsing error
      logger.e('Fatal error during checkout for $checkinId:', error: e, stackTrace: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('key_293c'))), // “Something went wrong”
      );
    }
  }

  Future<void> _openOrCreateChat(String checkinId) async {
    const tempGroupQuery = r'''
      query TempGroup($cid: uuid!) {
        nursery_temp_groups(where: { checkin_id: { _eq: $cid } }, limit: 1) {
          group_id
        }
      }
    ''';

    const createGroupMutation = r'''
      mutation CreateNurseryTempGroup($cid: uuid!) {
        create_nursery_temp_group(args: {checkin_id: $cid}) {
          group_id
        }
      }
    ''';

    try {
      final client = GraphQLProvider.of(context).value;
      String? groupId;

      // 1) Look for existing temp group
      final resQ = await client.query(
        QueryOptions(document: gql(tempGroupQuery), variables: {'cid': checkinId}),
      );

      if (resQ.hasException) {
        logger.e('GraphQL Exception on TempGroup query:', error: resQ.exception);
      } else {
        final rows = (resQ.data?['nursery_temp_groups'] as List<dynamic>? ?? []);
        if (rows.isNotEmpty) {
          groupId = rows.first['group_id'] as String?;
          logger.d('Existing group found for $checkinId: $groupId');
        }
      }

      // 2) If none, create it
      if (groupId == null) {
        logger.i('No existing group found. Creating new group for $checkinId.');
        final resM = await client.mutate(
          MutationOptions(document: gql(createGroupMutation), variables: {'cid': checkinId}),
        );
        
        if (resM.hasException) {
          logger.e('GraphQL Exception on CreateNurseryTempGroup mutation:', error: resM.exception);
        } else {
          groupId = resM.data?['create_nursery_temp_group']?['group_id'] as String?;
        }
      }

      if (!mounted) return;

      if (groupId == null) {
        logger.w('Failed to get or create group ID for $checkinId.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('key_293f'))), // “Unable to open chat”
        );
        return;
      }

      logger.i('Opening chat group $groupId for checkin $checkinId.');
      context.push('/groups/$groupId');
    } catch (e, stack) {
      logger.e('Fatal error in _openOrCreateChat for $checkinId:', error: e, stackTrace: stack);
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
          
          // Removed redundant context.mounted check
          if (res != null) { 
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
  // ... constructor and types ...
  const _ActiveCheckinsList({
    required this.onCheckout,
    required this.onOpenChat,
  });

  final void Function(String checkinId) onCheckout;
  final void Function(String checkinId) onOpenChat;

  static const _activeCheckinsSubscription = r'''
    subscription ActiveCheckins {
      child_checkins(
        where: { check_out_time: { _is_null: true } }
        order_by: { check_in_time: desc }
      ) {
        id
        child_id
        check_in_time
        child: child_profile {
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
      options: SubscriptionOptions(document: gql(_activeCheckinsSubscription)),
      builder: (result) {
        if (result.isLoading && result.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (result.hasException) {
          logger.e('GraphQL Subscription Exception:', error: result.exception); // Added logging
          return Center(child: Text(tr('key_012'))); // “Error”
        }

        final rows = (result.data?['child_checkins'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        if (rows.isEmpty) {
          return Center(
            child: Text(
              tr('key_315a'), 
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        } //No Check-Ins
        
        // ... ListView.separated implementation remains the same ...

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
                  : Text(tr('key_253', args: [allergies])), 
              // onTap handles chat
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