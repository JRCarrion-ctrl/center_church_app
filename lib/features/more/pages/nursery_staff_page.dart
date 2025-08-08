// File: lib/features/nursery/pages/nursery_staff_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class NurseryStaffPage extends StatefulWidget {
  const NurseryStaffPage({super.key});

  @override
  State<NurseryStaffPage> createState() => _NurseryStaffPageState();
}

class _NurseryStaffPageState extends State<NurseryStaffPage> {
  final supabase = Supabase.instance.client;
  bool _checkingRole = true;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _ensureAuthorized();
  }

  Future<void> _ensureAuthorized() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _authorized = false;
          _checkingRole = false;
        });
        return;
      }

      // Simple gate: allow global roles 'nursery_staff' or 'owner'.
      // If you store this elsewhere (permissions table), swap this query.
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();

      final role = (profile?['role'] as String?)?.toLowerCase();
      setState(() {
        _authorized = role == 'nursery_staff' || role == 'owner' || role == 'supervisor';
        _checkingRole = false;
      });
    } catch (_) {
      setState(() {
        _authorized = false;
        _checkingRole = false;
      });
    }
  }

  // ---- Helpers ----
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _checkOut(String checkinId) async {
    try {
      final updated = await supabase
          .from('child_checkins')
          .update({'check_out_time': DateTime.now().toUtc().toIso8601String()})
          .eq('id', checkinId)
          .select()
          .maybeSingle();

      if (updated == null) {
        _snack("key_293a".tr()); // not found
        return;
      }
      _snack("key_293b".tr()); // success
    } catch (e) {
      _snack("key_293c".tr()); // generic failure
    }
  }

  Future<void> _openOrCreateChat(Map<String, dynamic> row) async {
    final checkinId = row['id'];
    final childId = row['child']?['id'];
    if (checkinId == null || childId == null) {
      _snack("key_293d".tr()); // invalid data
      return;
    }

    try {
      // 1) see if we already mapped this check-in to a temp group
      final existing = await supabase
          .from('nursery_temp_groups')
          .select('group_id')
          .eq('checkin_id', checkinId)
          .maybeSingle();

      final existingGroupId = existing?['group_id'] as String?;
      if (existingGroupId != null && mounted) {
        context.push('/groups/$existingGroupId');
        return;
      }

      // 2) otherwise create via RPC
      final created = await supabase
          .rpc('create_nursery_temp_group', params: {
            'p_checkin_id': checkinId,
            'p_child_id': childId,
          })
          .select()
          .maybeSingle();

      final newGroupId = created?['create_nursery_temp_group'] as String?;
      if (newGroupId != null && mounted) {
        context.push('/groups/$newGroupId');
      } else {
        _snack("key_293e".tr()); // failed to create
      }
    } catch (e) {
      _snack("key_293f".tr()); // error creating/opening chat
    }
  }

  Widget _tile(Map<String, dynamic> row) {
    final child = row['child'] as Map<String, dynamic>? ?? const {};
    final photo = child['photo_url'] as String?;
    final name = child['display_name'] as String? ?? 'Unnamed';

    final checkInTime = _fmt(row['check_in_time'] as String?);

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
        child: (photo == null || photo.isEmpty) ? const Icon(Icons.child_care) : null,
      ),
      title: Text(name),
      subtitle: Text("key_293".tr(args: [checkInTime])),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: "key_293g_chat".tr(), // add this key if you want a tooltip
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => _openOrCreateChat(row),
          ),
          IconButton(
            tooltip: "key_293g_checkout".tr(), // add this key if you want a tooltip
            icon: const Icon(Icons.logout),
            color: Colors.red,
            onPressed: () => _checkOut(row['id'] as String),
          ),
        ],
      ),
      onTap: () => context.push('/nursery/child-profile', extra: child),
    );
  }

  // ---- Stream for active (not checked out) check-ins ----
  Stream<List<Map<String, dynamic>>> _activeCheckinsStream() {
    // Realtime filter: check_out_time IS NULL
    return supabase
        .from('child_checkins')
        .stream(primaryKey: ['id'])
        .eq('check_out_time', 'null')
        .order('check_in_time', ascending: false)
        // Fetch expanded child once per emission
        .map((rows) async {
          if (rows.isEmpty) return <Map<String, dynamic>>[];
          final ids = rows.map((r) => r['child_id']).where((e) => e != null).toList();
          if (ids.isEmpty) return rows.cast<Map<String, dynamic>>();

          // hydrate child relation in one shot
          final children = await supabase
              .from('child_profiles')
              .select('*')
              .inFilter('id', ids);

          final byId = {
            for (final c in children) c['id']: c,
          };

          return rows.map<Map<String, dynamic>>((r) {
            final m = Map<String, dynamic>.from(r);
            m['child'] = byId[m['child_id']];
            return m;
          }).toList();
        })
        .asyncMap((f) => f); // resolve the inner future
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.go('/more'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "key_forbidden_generic".tr(), // e.g. “You don’t have access to this page.”
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/more')),
        title: Text("key_294".tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/nursery/qr_checkin'),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _activeCheckinsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Failed to load check-ins"));
          }

          final data = snapshot.data ?? const [];
          if (data.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {}, // stream will push updates automatically
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 48),
                  Center(child: Text("key_no_active_checkins".tr())), // add this key
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {}, // stream keeps it fresh
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: data.length,
              itemBuilder: (_, i) => _tile(data[i]),
            ),
          );
        },
      ),
    );
  }
}
