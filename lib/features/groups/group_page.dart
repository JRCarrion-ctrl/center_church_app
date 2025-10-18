// File: lib/features/groups/group_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../app_state.dart';
import 'models/group.dart';
import 'widgets/group_chat_tab.dart';
import 'package:go_router/go_router.dart';

class GroupPage extends StatefulWidget {
  final String groupId;

  const GroupPage({super.key, required this.groupId});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  bool _isLoading = true;
  Group? _group;
  
  bool _isGroupAdmin = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_group == null && _isLoading) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final appState = context.read<AppState>();
    final service = appState.groupService;

    final userId = appState.profile?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final group = await service.getGroupById(widget.groupId);
      final userGroupRole = await service.getMyGroupRole(
        groupId: widget.groupId, 
        userId: userId,
      );

      if (!mounted) return;

      const adminRoles = {'admin', 'leader', 'supervisor', 'owner'};
      final isGroupAdmin = adminRoles.contains(userGroupRole);
      final isOwner = userGroupRole == 'owner';
      
      setState(() {
        _group = group;
        _isGroupAdmin = isGroupAdmin;
        _isOwner = isOwner;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Failed to initialize GroupPage: $e");
      if (mounted) {
        setState(() {
          _group = null;
          _isLoading = false;
        });
      }
    }
  }
  
  Widget _buildTopBar(BuildContext context, Group group) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(40),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const BackButton(),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push(
                    '/groups/${widget.groupId}/info',
                    extra: {
                        'isAdmin': _isGroupAdmin,
                        'isOwner': _isOwner,
                    },
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: group.photoUrl ?? '',
                          placeholder: (context, url) => const SizedBox.shrink(),
                          errorWidget: (context, url, error) => const Icon(Icons.group, size: 22),
                          fit: BoxFit.cover,
                          width: 44,
                          height: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.name,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48), // Spacer to balance the BackButton
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final group = _group;
    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text("key_051".tr())),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(context, group),
          Expanded(
            child: GroupChatTab(groupId: widget.groupId, isAdmin: _isGroupAdmin),
          ),
        ],
      ),
    );
  }
}