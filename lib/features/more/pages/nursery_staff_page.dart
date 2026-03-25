// File: lib/features/nursery/pages/nursery_staff_page.dart
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../app_state.dart';
import 'package:ccf_app/shared/user_roles.dart';

class NurseryStaffPage extends StatefulWidget {
  const NurseryStaffPage({super.key});

  @override
  State<NurseryStaffPage> createState() => _NurseryStaffPageState();
}

class _NurseryStaffPageState extends State<NurseryStaffPage> {
  bool _checkingRole = true;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final appState = context.read<AppState>();
    final role = appState.userRole;
    const allowedRoles = {UserRole.nurseryStaff, UserRole.owner, UserRole.supervisor};
    
    setState(() {
      _authorized = allowedRoles.contains(role);
      _checkingRole = false;
    });
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
    
    final userId = context.read<AppState>().profile?.id; 
    if (userId == null) return;

    final client = GraphQLProvider.of(context).value;
    final res = await client.mutate(MutationOptions(
      document: gql(checkoutMutation),
      variables: {
        'id': checkinId,
        'uid': userId, 
        'now': DateTime.now().toUtc().toIso8601String(), 
      },
    ));

    if (mounted && !res.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('key_293b')), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _openChat(String groupId, String childName) async {
    if (groupId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('key_293f')), 
          backgroundColor: Theme.of(context).colorScheme.error
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = GraphQLProvider.of(context).value;
      final groupService = GroupService(client);
      final userId = context.read<AppState>().profile?.id;
      
      if (userId != null) {
        await groupService.ensureChildChatGroup(
          childId: groupId, 
          childName: childName, 
          staffUserId: userId,
        );
      }
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading
      
      context.push('/groups/$groupId');
      
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading
      debugPrint("Chat open error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open chat. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingRole) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('key_294'))),
        body: Center(child: Text(tr('key_012'))),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('key_294'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/more/nursery/qr_checkin'),
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(tr('key_314')),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: _ActiveCheckinsList(
        onCheckout: _checkout,
        onOpenChat: _openChat, 
      ),
    );
  }
}

class _ActiveCheckinsList extends StatelessWidget {
  final void Function(String id) onCheckout;
  final void Function(String groupId, String childName) onOpenChat;

  const _ActiveCheckinsList({
    required this.onCheckout,
    required this.onOpenChat, 
  });

  @override
  Widget build(BuildContext context) {
    const subscription = r'''
      subscription ActiveCheckins {
        child_checkins(where: { check_out_time: { _is_null: true } }, order_by: { check_in_time: desc }) {
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

    return Subscription(
      options: SubscriptionOptions(document: gql(subscription)),
      builder: (result) {
        if (result.isLoading && result.data == null) return const Center(child: CircularProgressIndicator());
        
        final rows = (result.data?['child_checkins'] as List? ?? []).cast<Map<String, dynamic>>();

        if (rows.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.done_all_rounded, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(tr('key_315a'), style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, i) => _CheckinCard(
            row: rows[i], 
            onCheckout: onCheckout,
            onOpenChat: onOpenChat, 
          ),
        );
      },
    );
  }
}

class _CheckinCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final void Function(String) onCheckout;
  final void Function(String, String) onOpenChat;

  const _CheckinCard({
    required this.row, 
    required this.onCheckout,
    required this.onOpenChat, 
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final child = row['child'] as Map<String, dynamic>?;
    final String name = child?['display_name'] ?? '—';
    final String? photoUrl = child?['photo_url'];
    final String allergies = child?['allergies'] ?? '';
    final DateTime checkInTime = DateTime.parse(row['check_in_time']).toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => context.pushNamed('child-staff', pathParameters: {'childId': child?['id'] ?? ''}),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatar(photoUrl, theme),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        "In: ${DateFormat.jm().format(checkInTime)} (${_getTimeSince(checkInTime)})",
                        style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                      ),
                      if (allergies.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _AllergyBadge(text: allergies),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                      onPressed: () => onOpenChat(
                        row['child_id']?.toString() ?? '', 
                        name, 
                      ),
                    ),
                    const SizedBox(height: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.logout, size: 20),
                      onPressed: () => onCheckout(row['id'].toString()),
                      style: IconButton.styleFrom(backgroundColor: theme.colorScheme.errorContainer, foregroundColor: theme.colorScheme.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, ThemeData theme) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 2)),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : Container(color: theme.colorScheme.primaryContainer, child: Icon(Icons.child_care, color: theme.colorScheme.primary)),
      ),
    );
  }

  String _getTimeSince(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    return "${diff.inHours}h ago";
  }
}

class _AllergyBadge extends StatelessWidget {
  final String text;
  const _AllergyBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: TextStyle(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}