// File: lib/features/groups/group_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'models/group.dart';
import 'group_service.dart';
import 'widgets/group_chat_tab.dart';
import 'pages/group_info_page.dart';

class GroupPage extends StatefulWidget {
  final String groupId;

  const GroupPage({super.key, required this.groupId});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  late Future<void> _initFuture;
  Group? _group;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    final group = await GroupService().getGroupById(widget.groupId);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final isAdmin = await GroupService().isUserGroupAdmin(widget.groupId, userId);

    setState(() {
      _group = group;
      _isAdmin = isAdmin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final group = _group;

        if (group == null || snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Failed to load group.')),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              Material(
                color: theme.colorScheme.surface,
                elevation: 1,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 32, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GroupInfoPage(
                                  groupId: widget.groupId,
                                  isAdmin: _isAdmin,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: (group.photoUrl?.isNotEmpty ?? false)
                                      ? NetworkImage(group.photoUrl!)
                                      : null,
                                  child: (group.photoUrl?.isEmpty ?? true)
                                      ? const Icon(Icons.group)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  group.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GroupInfoPage(
                                  groupId: widget.groupId,
                                  isAdmin: _isAdmin,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 64,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          GroupInfoButton(
                            title: 'Pinned Messages',
                            icon: Icons.push_pin_outlined,
                            onTap: () => GroupChatTab.scrollToPinnedMessage(context),
                          ),
                          GroupInfoButton(
                            title: 'Events',
                            icon: Icons.calendar_today_outlined,
                            onTap: () => context.push('/groups/${widget.groupId}/events'),
                          ),
                          GroupInfoButton(
                            title: 'Media',
                            icon: Icons.perm_media_outlined,
                            onTap: () => context.push('/groups/${widget.groupId}/media'),
                          ),
                          if (_isAdmin)
                            GroupInfoButton(
                              title: 'Admin Tools',
                              icon: Icons.admin_panel_settings_outlined,
                              onTap: () => context.push('/groups/${widget.groupId}/admin'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GroupChatTab(groupId: widget.groupId, isAdmin: _isAdmin),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GroupInfoButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const GroupInfoButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
