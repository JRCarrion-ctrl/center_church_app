// File: lib/features/groups/group_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    final group = await GroupService().getGroupById(widget.groupId);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final isAdmin = await GroupService().isUserGroupAdmin(widget.groupId, userId);
    final isOwner = await GroupService().isUserGroupOwner(widget.groupId, userId);

    setState(() {
      _group = group;
      _isAdmin = isAdmin;
      _isOwner = isOwner;
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
              // Top bar with SafeArea and consistent background
              Container(
                color: theme.colorScheme.surface,
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GroupInfoPage(
                                    groupId: widget.groupId,
                                    isAdmin: _isAdmin,
                                    isOwner: _isOwner,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 4),
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundImage: (group.photoUrl?.isNotEmpty ?? false)
                                        ? NetworkImage(group.photoUrl!)
                                        : null,
                                    child: (group.photoUrl?.isEmpty ?? true)
                                        ? const Icon(Icons.group, size: 28)
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    group.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider or shadow below the top bar
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      )

                    ],
                  ),
                ),
              ),
              // Chat body
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
