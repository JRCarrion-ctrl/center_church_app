// File: lib/features/groups/your_groups_page.dart
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:ccf_app/features/groups/models/group_model.dart'; 

class YourGroupsSection extends StatefulWidget {
  const YourGroupsSection({super.key, this.excludeArchived = true});

  /// Hide archived groups defensively at the UI layer
  final bool excludeArchived;

  @override
  State<YourGroupsSection> createState() => YourGroupsSectionState();
}

class YourGroupsSectionState extends State<YourGroupsSection> {
  late Future<List<GroupModel>> _futureGroups;

  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  List<GroupModel> _allGroups = [];
  List<GroupModel> _filteredGroups = [];

  @override
  void initState() {
    super.initState();
    _futureGroups = _loadGroups();
    _searchCtl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  // 🚀 FIXED: Read directly from the provider tree synchronously
  GroupService _service() {
    return context.read<GroupService>();
  }

  Future<List<GroupModel>> _loadGroups() async {
    final appState = context.read<AppState>();
    final userId = appState.profile?.id;
    if (userId == null || userId.isEmpty) {
      _allGroups = [];
      _filteredGroups = [];
      return [];
    }

    // 🚀 FIXED: Removed the double await since _service() is synchronous now
    final groups = await _service().getUserGroups(userId);
    
    // Defensive filter: hide archived if requested. Sub-groups are always excluded
    // here — they're only discoverable via their parent group's own Home tab.
    final visible = groups
        .where((g) => g.parentGroupId == null)
        .where((g) => !widget.excludeArchived || g.archived == false)
        .toList();

    // Like a messaging app: most recent conversation first, then groups with
    // no messages yet by name.
    visible.sort((a, b) {
      final at = a.lastMessageAt, bt = b.lastMessageAt;
      if (at != null && bt != null) return bt.compareTo(at);
      if (at != null) return -1;
      if (bt != null) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    _allGroups = visible;
    _filteredGroups = _applySearch(_allGroups, _searchCtl.text);
    return _allGroups;
  }

  /// Public method to allow refresh from parent
  Future<void> refresh() async {
    setState(() {
      _futureGroups = _loadGroups();
    });
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _filteredGroups = _applySearch(_allGroups, _searchCtl.text);
      });
    });
  }

  List<GroupModel> _applySearch(List<GroupModel> source, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return List<GroupModel>.from(source);
    return source.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _openGroup(GroupModel group) async {
    if (group.archived) return;

    // 🚀 CLEANED: We deleted all the redundant role-fetching logic. 
    // GroupPortalPage is self-sufficient now, so we just pass the ID!
    if (mounted) {
      await context.push('/groups/${group.id}');
    }

    if (mounted) {
      await refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final myId = context.select<AppState, String?>((s) => s.profile?.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: "key_063".tr(), // Search groups...
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<GroupModel>>(
          future: _futureGroups,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return _EmptyCard(icon: Icons.cloud_off_outlined, text: 'groups_load_error'.tr());
            }
            if (_filteredGroups.isEmpty) {
              return _EmptyCard(icon: Icons.forum_outlined, text: "key_066".tr()); // not in any groups
            }
            return Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _filteredGroups.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 84, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    _ChatRow(group: _filteredGroups[i], myId: myId, onTap: () => _openGroup(_filteredGroups[i])),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// One conversation: photo, name, last message preview, time, unread count.
class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.group, required this.myId, required this.onTap});

  final GroupModel group;
  final String? myId;
  final VoidCallback onTap;

  String _preview() {
    final text = group.lastMessageText;
    if (text == null) return 'groups_no_messages'.tr();
    final String body;
    if (group.lastMessageType == 'gif' || text == '[GIF]') {
      body = 'groups_preview_gif'.tr();
    } else if (text == '[Image]') {
      body = 'groups_preview_photo'.tr();
    } else if (text == '[File]') {
      body = 'groups_preview_file'.tr();
    } else {
      body = text.replaceAll('\n', ' ');
    }
    if (group.lastMessageSenderId != null && group.lastMessageSenderId == myId) {
      return 'groups_preview_you'.tr(namedArgs: {'message': body});
    }
    final sender = group.lastMessageSender?.trim().split(RegExp(r'\s+')).first;
    return (sender == null || sender.isEmpty) ? body : '$sender: $body';
  }

  String _time(BuildContext context) {
    final at = group.lastMessageAt;
    if (at == null) return '';
    final locale = context.locale.toLanguageTag();
    final now = DateTime.now();
    if (DateUtils.isSameDay(at, now)) return DateFormat.jm(locale).format(at);
    if (DateUtils.isSameDay(at, now.subtract(const Duration(days: 1)))) return 'groups_yesterday'.tr();
    if (now.difference(at).inDays < 7) return DateFormat.E(locale).format(at);
    return DateFormat.MMMd(locale).format(at);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final unread = group.unreadCount;
    final hasUnread = unread > 0 && !group.isMuted;
    final hasPhoto = group.photoUrl?.isNotEmpty ?? false;

    return InkWell(
      onTap: group.archived ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: colorScheme.surfaceContainerHighest,
              backgroundImage: hasPhoto ? NetworkImage(group.photoUrl!) : null,
              child: hasPhoto ? null : Icon(Icons.groups_outlined, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _time(context),
                        style: textTheme.labelSmall?.copyWith(
                          color: hasUnread ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (group.isMuted) ...[
                        Icon(Icons.notifications_off_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                      ],
                      if (group.archived) ...[
                        Icon(Icons.archive_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          _preview(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: hasUnread ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: group.isMuted ? colorScheme.surfaceContainerHighest : colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            textAlign: TextAlign.center,
                            style: textTheme.labelSmall?.copyWith(
                              color: group.isMuted ? colorScheme.onSurfaceVariant : colorScheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: colorScheme.onSurfaceVariant))),
          ],
        ),
      ),
    );
  }
}
