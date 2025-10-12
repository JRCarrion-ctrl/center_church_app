// File: lib/features/groups/pages/group_join_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../../core/graph_provider.dart';             // <-- Hasura GraphQLClient
import '../../../app_state.dart';               // <-- AppState for current user id
import '../group_service.dart';
import '../models/group.dart';

Future<void> showGroupJoinModal(BuildContext context, String groupId) async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _GroupJoinModalContent(groupId: groupId),
  );
}

class _GroupJoinModalContent extends StatefulWidget {
  final String groupId;
  const _GroupJoinModalContent({required this.groupId});

  @override
  State<_GroupJoinModalContent> createState() => _GroupJoinModalContentState();
}

class _GroupJoinModalContentState extends State<_GroupJoinModalContent> {
  Group? group;
  bool isLoading = true;
  bool isJoining = false;

  late GroupService _groups;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    _groups = GroupService(GraphProvider.of(context));
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    final fetched = await _groups.getGroupById(widget.groupId);
    if (!mounted) return;
    setState(() {
      group = fetched;
      isLoading = false;
    });
  }

  Future<void> _joinGroup() async {
    final uid = context.read<AppState>().profile?.id;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in')),
      );
      return;
    }

    setState(() => isJoining = true);
    try {
      await _groups.joinGroup(
        groupId: widget.groupId,
        userId: uid, // <-- required now
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (group?.visibility == 'public')
                ? 'Joined group!'
                : 'Request sent!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join group: $e')),
      );
    } finally {
      if (mounted) setState(() => isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (group == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text("key_114".tr())),
      );
    }

    final isRequestGroup = group!.visibility == 'request';
    final isPublicGroup = group!.visibility == 'public';

    return Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (group!.photoUrl != null && group!.photoUrl!.isNotEmpty)
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(group!.photoUrl!),
            ),
          const SizedBox(height: 16),
          Text(group!.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(group!.description ?? '', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (isPublicGroup || isRequestGroup)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isJoining ? null : _joinGroup,
                child: isJoining
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isPublicGroup ? "key_114a".tr() : "key_114b".tr()),
              ),
            )
          else
            Text("key_115".tr()),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("key_116".tr()),
          ),
        ],
      ),
    );
  }
}
