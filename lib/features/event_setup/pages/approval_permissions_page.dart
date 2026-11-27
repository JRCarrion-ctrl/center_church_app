// File: lib/features/event_setup/pages/approval_permissions_page.dart
//
// Owner-only: control who may sign off each department, and for which
// ministries. Writes are also restricted to `owner` in Hasura.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';
import '../../../shared/user_roles.dart';
import '../event_setup_access.dart';
import '../event_setup_service.dart';
import '../models/event_setup_models.dart';
import '../widgets/setup_card.dart';

class ApprovalPermissionsPage extends StatefulWidget {
  const ApprovalPermissionsPage({super.key});

  @override
  State<ApprovalPermissionsPage> createState() => _ApprovalPermissionsPageState();
}

class _ApprovalPermissionsPageState extends State<ApprovalPermissionsPage> {
  EventSetupService? _service;

  List<ApprovalPermission> _rules = const [];
  List<MinistryOption> _ministries = const [];
  List<MemberOption> _members = const [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;

  // --- New rule draft ---
  MemberOption? _member;
  String? _groupId; // null = All Ministries
  final Set<SetupDepartment> _departments = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service == null) {
      _service = EventSetupService(GraphQLProvider.of(context).value);
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    if (!EventSetupAccess.canManagePermissions(context.read<AppState>().userRole)) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final results = await Future.wait([
        _service!.fetchAllPermissions(),
        _service!.fetchMinistries(),
        _service!.fetchMembers(),
      ]);
      if (!mounted) return;
      setState(() {
        _rules = results[0] as List<ApprovalPermission>;
        _ministries = results[1] as List<MinistryOption>;
        _members = results[2] as List<MemberOption>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('EventSetup: permissions load failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _reloadRules() async {
    try {
      final rules = await _service!.fetchAllPermissions();
      if (mounted) setState(() => _rules = rules);
    } catch (e) {
      debugPrint('EventSetup: rules reload failed: $e');
    }
  }

  bool _ruleExists(String userId, SetupDepartment dept, String? groupId) =>
      _rules.any((r) => r.userId == userId && r.department == dept && r.groupId == groupId);

  Future<void> _addRule() async {
    final member = _member;
    if (member == null || _departments.isEmpty || _saving) return;

    final toAdd = _departments.where((d) => !_ruleExists(member.id, d, _groupId)).toList();
    final messenger = ScaffoldMessenger.of(context);
    if (toAdd.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('event_setup_perm_duplicate'.tr())));
      return;
    }

    setState(() => _saving = true);
    try {
      await _service!.addPermissions(userId: member.id, groupId: _groupId, departments: toAdd);
      await _reloadRules();
      if (!mounted) return;
      setState(() {
        _member = null;
        _groupId = null;
        _departments.clear();
      });
      messenger.showSnackBar(SnackBar(content: Text('event_setup_perm_added'.tr())));
    } catch (e) {
      debugPrint('EventSetup: add permission failed: $e');
      messenger.showSnackBar(SnackBar(content: Text('event_setup_perm_error'.tr())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke(ApprovalPermission rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('event_setup_perm_revoke_title'.tr()),
        content: Text(
          'event_setup_perm_revoke_body'.tr(
            namedArgs: {
              'name': rule.userName ?? rule.userId,
              'department': rule.department.labelKey.tr(),
              'scope': _scopeLabel(rule),
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('event_setup_cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('event_setup_perm_revoke'.tr())),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service!.deletePermission(rule.id);
      await _reloadRules();
    } catch (e) {
      debugPrint('EventSetup: revoke failed: $e');
      messenger.showSnackBar(SnackBar(content: Text('event_setup_perm_error'.tr())));
    }
  }

  String _scopeLabel(ApprovalPermission rule) =>
      rule.isAllMinistries ? 'event_setup_all_ministries'.tr() : (rule.groupName ?? '—');

  Future<void> _pickMember() async {
    final picked = await showModalBottomSheet<MemberOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _MemberPickerSheet(members: _members),
    );
    if (picked != null) setState(() => _member = picked);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select<AppState, UserRole>((s) => s.userRole);

    if (!EventSetupAccess.canManagePermissions(role)) {
      return Scaffold(
        appBar: AppBar(title: Text('event_setup_permissions_title'.tr())),
        body: SetupMessage(icon: Icons.lock_outline, text: 'event_setup_no_access'.tr()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('event_setup_permissions_title'.tr())),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadFailed
                ? SetupMessage(icon: Icons.cloud_off_outlined, text: 'event_setup_load_error'.tr())
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
                          child: Text(
                            'event_setup_permissions_intro'.tr(),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                        _buildAddRuleCard(),
                        const SizedBox(height: 28),
                        ..._buildRuleGroups(),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddRuleCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final canSave = _member != null && _departments.isNotEmpty && !_saving;

    return SetupCard(
      label: 'event_setup_perm_add_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickMember,
            child: InputDecorator(
              decoration: setupInputDecoration(
                context,
                'event_setup_perm_member'.tr(),
                icon: Icons.person_search_outlined,
              ),
              isEmpty: _member == null,
              child: Text(
                _member == null ? '' : _member!.displayName,
                style: TextStyle(color: colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            key: ValueKey('scope-${_groupId ?? 'all'}-${_member?.id}'),
            initialValue: _groupId,
            isExpanded: true,
            decoration: setupInputDecoration(context, 'event_setup_perm_scope'.tr(), icon: Icons.groups_outlined),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text('event_setup_all_ministries'.tr())),
              ..._ministries.map(
                (m) => DropdownMenuItem<String?>(
                  value: m.id,
                  child: Text(m.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _groupId = v),
          ),
          const SizedBox(height: 16),
          Text(
            'event_setup_perm_departments'.tr(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SetupDepartment.values.map((d) {
              final selected = _departments.contains(d);
              return FilterChip(
                label: Text(d.labelKey.tr()),
                selected: selected,
                onSelected: (v) => setState(() => v ? _departments.add(d) : _departments.remove(d)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              onPressed: canSave ? _addRule : null,
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                    )
                  : const Icon(Icons.add),
              label: Text('event_setup_perm_add'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRuleGroups() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_rules.isEmpty) {
      return [SetupMessage(icon: Icons.rule_outlined, text: 'event_setup_perm_empty'.tr())];
    }

    // Group by person, keeping a stable alphabetical order.
    final byUser = <String, List<ApprovalPermission>>{};
    for (final r in _rules) {
      byUser.putIfAbsent(r.userId, () => []).add(r);
    }
    final userIds = byUser.keys.toList()
      ..sort(
        (a, b) =>
            (byUser[a]!.first.userName ?? '').toLowerCase().compareTo((byUser[b]!.first.userName ?? '').toLowerCase()),
      );

    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.only(left: 20, bottom: 8),
        child: Text(
          'event_setup_perm_existing'.tr().toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];

    for (final uid in userIds) {
      final rules = byUser[uid]!
        ..sort((a, b) {
          final byScope = (a.isAllMinistries ? 0 : 1).compareTo(b.isAllMinistries ? 0 : 1);
          if (byScope != 0) return byScope;
          final byGroup = (a.groupName ?? '').compareTo(b.groupName ?? '');
          return byGroup != 0 ? byGroup : a.department.index.compareTo(b.department.index);
        });
      final first = rules.first;

      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(first.userName ?? uid, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (first.userEmail != null)
                  Text(first.userEmail!, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                for (final rule in rules)
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: rule.department.labelKey.tr(),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(
                                text: '  ·  ${_scopeLabel(rule)}',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'event_setup_perm_revoke'.tr(),
                        icon: Icon(Icons.remove_circle_outline, color: colorScheme.error),
                        onPressed: () => _revoke(rule),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

class _MemberPickerSheet extends StatefulWidget {
  const _MemberPickerSheet({required this.members});

  final List<MemberOption> members;

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final results = q.isEmpty
        ? widget.members
        : widget.members
              .where((m) => m.displayName.toLowerCase().contains(q) || (m.email?.toLowerCase().contains(q) ?? false))
              .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: setupInputDecoration(context, 'event_setup_perm_search'.tr(), icon: Icons.search),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? SetupMessage(icon: Icons.person_off_outlined, text: 'event_setup_perm_no_members'.tr())
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final m = results[i];
                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(m.displayName),
                          subtitle: m.email == null ? null : Text(m.email!),
                          onTap: () => Navigator.pop(context, m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
