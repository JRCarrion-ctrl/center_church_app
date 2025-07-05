// File: lib/features/groups/pages/group_join_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../group_service.dart';
import '../models/group.dart';

class GroupJoinPage extends StatefulWidget {
  final String groupId;

  const GroupJoinPage({super.key, required this.groupId});

  @override
  State<GroupJoinPage> createState() => _GroupJoinPageState();
}

class _GroupJoinPageState extends State<GroupJoinPage> {
  Group? group;
  bool isLoading = true;
  bool isJoining = false;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    group = await GroupService().getGroupById(widget.groupId);
    setState(() => isLoading = false);
  }

  Future<void> _joinGroup() async {
    setState(() => isJoining = true);
    try {
      await GroupService().joinGroup(widget.groupId); // Implement this method in GroupService
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (group == null) return Scaffold(body: Center(child: Text('Group not found')));

    final isRequestGroup = group!.visibility == 'request';
    final isPublicGroup = group!.visibility == 'public';

    return Scaffold(
      appBar: AppBar(title: Text(group!.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group!.photoUrl != null && group!.photoUrl!.isNotEmpty)
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(group!.photoUrl!),
                ),
              ),
            const SizedBox(height: 16),
            Text(group!.description ?? '', style: const TextStyle(fontSize: 16)),
            const Spacer(),
            if (isPublicGroup || isRequestGroup)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isJoining ? null : _joinGroup,
                  child: isJoining
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isPublicGroup ? 'Join Group' : 'Request to Join'),
                ),
              )
            else
              const Text('This group is invite only.'),
          ],
        ),
      ),
    );
  }
}
