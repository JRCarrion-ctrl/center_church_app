// File: lib/features/groups/joinable_groups_section.dart
//
// "Groups you can join": same row shape as the chat list (photo, name,
// short description) with a Join button, so the Groups tab reads as one list.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
import 'package:ccf_app/features/groups/pages/group_join_page.dart';

class JoinableGroupsSection extends StatefulWidget {
  final VoidCallback? onGroupJoined;
  const JoinableGroupsSection({super.key, this.onGroupJoined});

  @override
  State<JoinableGroupsSection> createState() => JoinableGroupsSectionState();
}

class JoinableGroupsSectionState extends State<JoinableGroupsSection> {
  List<GroupModel> allGroups = [];
  List<GroupModel> filteredGroups = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFilteredGroups();
  }

  void refresh() => _loadFilteredGroups();

  Future<void> _loadFilteredGroups() async {
    if (!mounted) return;
    // Keep showing the old list while refreshing.
    setState(() => _loading = allGroups.isEmpty);

    final appState = context.read<AppState>();
    final userId = appState.profile?.id;
    if (userId == null || userId.isEmpty) {
      setState(() {
        allGroups = [];
        filteredGroups = [];
        _loading = false;
      });
      return;
    }

    try {
      final svc = appState.groupService;
      final joinable = await svc.getJoinableGroups(appState.databaseServiceFilter);
      final myGroups = await svc.getUserGroups(userId);
      final myRequests = await svc.getMyPendingGroupRequests(userId);
      if (!mounted) return;

      final joinedIds = myGroups.map((g) => g.id).toSet();
      final requestedIds = myRequests.toSet();

      // Hide groups I'm already in or have already asked to join.
      allGroups = joinable.where((g) => !joinedIds.contains(g.id) && !requestedIds.contains(g.id)).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      debugPrint('Error fetching joinable groups: $e');
    }
    if (!mounted) return;
    _applyFilter();
    setState(() => _loading = false);
  }

  void _applyFilter() {
    final q = _query.trim().toLowerCase();
    setState(() {
      filteredGroups = q.isEmpty
          ? List<GroupModel>.from(allGroups)
          : allGroups
              .where((g) => g.name.toLowerCase().contains(q) || (g.description ?? '').toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _open(GroupModel group) async {
    // true once they joined or asked to join.
    final joined = await showGroupJoinModal(context, group.id);
    if (joined == true) widget.onGroupJoined?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // Nothing to join and not searching: hide the whole section.
    if (allGroups.isEmpty && _query.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            children: [
              Icon(Icons.explore_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "key_059d".tr(), // Groups You Can Join
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                label: Text('${allGroups.length}'),
                backgroundColor: colorScheme.secondaryContainer,
                textColor: colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'groups_discover_subtitle'.tr(),
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        // Search only helps once the list gets long.
        if (allGroups.length > 6 || _query.isNotEmpty) ...[
          TextField(
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "key_063".tr(),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (val) {
              _query = val;
              _applyFilter();
            },
          ),
          const SizedBox(height: 12),
        ],
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: filteredGroups.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text("key_064".tr(), style: TextStyle(color: colorScheme.onSurfaceVariant)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < filteredGroups.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, indent: 84, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      _JoinableRow(group: filteredGroups[i], onTap: () => _open(filteredGroups[i])),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _JoinableRow extends StatelessWidget {
  const _JoinableRow({required this.group, required this.onTap});

  final GroupModel group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasPhoto = group.photoUrl?.isNotEmpty ?? false;
    final description = group.description?.trim() ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Hero(
              tag: 'group-${group.id}',
              child: CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: hasPhoto ? NetworkImage(group.photoUrl!) : null,
                child: hasPhoto ? null : Icon(Icons.groups_outlined, color: colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text('groups_join'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
