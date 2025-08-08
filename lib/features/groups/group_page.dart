// File: lib/features/groups/group_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/group.dart';
import 'group_service.dart';
import 'widgets/group_chat_tab.dart';
import 'pages/group_info_page.dart';
import 'package:easy_localization/easy_localization.dart';

class GroupPage extends StatefulWidget {
  final String groupId;

  const GroupPage({super.key, required this.groupId});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  late final Future<void> _initFuture = _initialize();

  Group? _group;
  bool _isAdmin = false;
  bool _isOwner = false;

  Future<void> _initialize() async {
    final group = await GroupService().getGroupById(widget.groupId);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final isAdmin = await GroupService().isUserGroupAdmin(widget.groupId, userId);
    final isOwner = await GroupService().isUserGroupOwner(widget.groupId, userId);

    if (!mounted) return;
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
          return Scaffold(
            body: Center(child: Text("key_051".tr())),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              // Top bar with SafeArea and consistent background
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(220),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(220),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: (group.photoUrl?.isNotEmpty ?? false)
                                    ? NetworkImage(group.photoUrl!)
                                    : null,
                                child: (group.photoUrl?.isEmpty ?? true)
                                    ? const Icon(Icons.group, size: 22)
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                group.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
