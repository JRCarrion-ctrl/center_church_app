// File: lib/features/nursery/pages/nursery_staff_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:logger/logger.dart'; 

import '../../../app_state.dart';
import 'package:ccf_app/shared/user_roles.dart';

final logger = Logger();

// REMOVED: typedef CheckinHandler = void Function(String checkinId);

class NurseryStaffPage extends StatefulWidget {
  const NurseryStaffPage({super.key});

  @override
  State<NurseryStaffPage> createState() => _NurseryStaffPageState();
}

class _NurseryStaffPageState extends State<NurseryStaffPage> {
  bool _checkingRole = true;
  bool _authorized = false;
  // REMOVED: String? _userId; - Relying on context.read<AppState>().profile?.id directly

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRole());
  }

  Future<void> _checkRole() async {
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
        });
        logger.i('User not logged in. Access denied.');
        return;
      }
      
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
        logger.w('User $uid access denied. Role: $role');
      } else {
        logger.i('User $uid authorized as $role.');
      }

    } catch (e, stack) {
      logger.e('Error during role check:', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _authorized = false;
          _checkingRole = false;
        });
      }
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
      
      // Get userId from context since it's no longer state
      final userId = context.read<AppState>().profile?.id; 
      if (userId == null) {
         logger.e('Cannot checkout: User ID is null.');
         if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('key_012'))), // "Error"
            );
         }
         return;
      }

      final variables = {
        'id': checkinId,
        'uid': userId, 
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
        logger.e('GraphQL Exception during checkout for $checkinId:', error: res.exception);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('key_293a'))),
        );
        return;
      } 
      
      if (res.data?['update_child_checkins_by_pk'] == null) {
        logger.w('Checkout failed for $checkinId: Checkin not found or not updated.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('key_293a'))),
        );
      } else {
        logger.i('Successfully checked out child for checkin $checkinId.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('key_293b'))),
        );
      }
    } catch (e, stack) {
      logger.e('Fatal error during checkout for $checkinId:', error: e, stackTrace: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('key_293c'))),
      );
    }
  }

  // REFACTORED: The function now takes the childId (which is the groupId) directly
  Future<void> _openChat(String groupId) async {
    if (groupId.isEmpty) {
      logger.w('Cannot open chat: Group ID (Child ID) is empty.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('key_293f'))), // “Unable to open chat”
      );
      return;
    }
    
    logger.i('Opening chat group $groupId.');
    if (!mounted) return;
    context.push('/groups/$groupId');
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('key_294'))),
        body: Center(child: Text(tr('key_012'))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('key_294'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await context.push('/nursery/qr_checkin');
          if (!context.mounted) return;

          if (res != null) { 
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('key_313'))),
            );
          }
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(tr('key_314')),
      ),
      body: _ActiveCheckinsList(
        onCheckout: _checkout,
        onOpenChat: _openChat,
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
  // REFACTORED: Changed signature to accept the groupId (which is the childId)
  final void Function(String groupId) onOpenChat;

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
          logger.e('GraphQL Subscription Exception:', error: result.exception);
          return Center(child: Text(tr('key_012')));
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
        }
        
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final row = rows[i];
            final checkinId = (row['id'] ?? '').toString();
            final groupId = (row['child_id'] ?? '').toString(); 
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
              
              // NEW BEHAVIOR: Navigate to child-staff route on card tap
              onTap: () {
                final childProfileId = (child?['id'] ?? '').toString();
                if (childProfileId.isNotEmpty) {
                  // Correctly call the route using the path parameter map
                  context.pushNamed(
                    'child-staff', 
                    pathParameters: {'childId': childProfileId}
                  );
                }
              },

              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => onOpenChat(groupId),
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