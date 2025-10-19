// File: lib/features/more/notification_settings_page.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  List<Map<String, dynamic>> groups = [];
  Set<String> mutedGroupIds = {};
  bool loading = true;
  bool globalMute = false;
  bool savingGlobalMute = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This is the correct place to access InheritedWidgets for initialization
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final client = GraphQLProvider.of(context).value;
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    const q = r'''
      query LoadNotificationSettings($uid: String!) {
        profiles_by_pk(id: $uid) { global_mute }
        
        approved_memberships: group_memberships( 
          where: { user_id: { _eq: $uid }, status: { _eq: "approved" } }
        ) {
          group { id name }
        }

        muted_settings: group_memberships(
          where: { user_id: { _eq: $uid }, is_muted: { _eq: true } }
        ) {
          group { id }
        }
      }
    ''';

    try {
      final res = await client.query(
        QueryOptions(
          document: gql(q),
          variables: {'uid': userId},
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (res.hasException) {
        debugPrint('Load settings error: ${res.exception}');
        if (mounted) setState(() => loading = false);
        return;
      }

      final gm = (res.data?['profiles_by_pk']?['global_mute'] as bool?) ?? false;

      final memberships = (res.data?['approved_memberships'] as List<dynamic>? ?? []);
      final grp = memberships
          .map((m) => (m as Map<String, dynamic>)['group'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .toList();

      final mutedRows = (res.data?['muted_settings'] as List<dynamic>? ?? []);
      final muted = mutedRows
          .map((m) => (m as Map<String, dynamic>)['group']?['id'] as String?)
          .whereType<String>()
          .toSet();

      if (!mounted) return;
      setState(() {
        globalMute = gm;
        groups = grp;
        mutedGroupIds = muted;
        loading = false;
      });
    } catch (e) {
      debugPrint('Load settings exception: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _toggleGlobalMute(bool mute) async {
    final client = GraphQLProvider.of(context).value;
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) return;

    setState(() => savingGlobalMute = true);

    const m = r'''
      mutation SetGlobalMute($uid: String!, $mute: Boolean!) {
        update_profiles_by_pk(pk_columns: {id: $uid}, _set: {global_mute: $mute}) { id }
      }
    ''';

    try {
      final res = await client.mutate(
        MutationOptions(document: gql(m), variables: {'uid': userId, 'mute': mute}),
      );
      if (res.hasException) {
        debugPrint('Set global mute error: ${res.exception}');
        // fall through to UI update to keep parity with old behavior
      }

      // OneSignal control (v5+)
      if (mute) {
        await OneSignal.User.pushSubscription.optOut();
      } else {
        await OneSignal.User.pushSubscription.optIn();
      }

      if (!mounted) return;
      setState(() {
        globalMute = mute;
        savingGlobalMute = false;
      });
    } catch (e) {
      debugPrint('Set global mute exception: $e');
      if (!mounted) return;
      setState(() => savingGlobalMute = false);
    }
  }

  Future<void> _toggleMute(String groupId, bool muted) async {
    final client = GraphQLProvider.of(context).value;
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) return;

    await OneSignal.User.addTags({
        groupId: muted ? 'muted' : 'active',
    });

    // Upsert the (user_id, group_id) row and set muted
    const m = r'''
      mutation UpsertNotificationSetting($user_id: String!, $group_id: uuid!, $muted: Boolean!) {
        update_group_memberships(where: {group_id: {_eq: $group_id}, user_id: {_eq: $user_id}}, _set: {is_muted: $muted}) {
          affected_rows
          returning {
            group_id
            user_id
            is_muted
          }
        }
      }
    ''';

    try {
      final res = await client.mutate(
        MutationOptions(
          document: gql(m),
          variables: {'user_id': userId, 'group_id': groupId, 'muted': muted},
        ),
      );
      if (res.hasException) {
        debugPrint('Upsert setting error: ${res.exception}');
      }

      if (muted) {
        await OneSignal.User.addTags({groupId: 'muted'});
      } else {
        await OneSignal.User.addTags({groupId: 'active'});
      }

      if (!mounted) return;
      setState(() {
        if (muted) {
          mutedGroupIds.add(groupId);
        } else {
          mutedGroupIds.remove(groupId);
        }
      });
    } catch (e) {
      debugPrint('Upsert setting exception: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_229".tr())),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SwitchListTile(
                  title: Text("key_230".tr()),
                  value: globalMute,
                  onChanged: savingGlobalMute ? null : _toggleGlobalMute,
                  subtitle: Text("key_231".tr()),
                ),
                const Divider(),
                ...groups.map((group) {
                  final groupId = group['id'] as String;
                  final groupName = (group['name'] as String?) ?? 'Unnamed Group';
                  final isEnabled = !mutedGroupIds.contains(groupId);
                  return SwitchListTile(
                    title: Text(groupName),
                    value: isEnabled,
                    onChanged: globalMute ? null : (val) => _toggleMute(groupId, !val),
                    subtitle: Text("key_232".tr()),
                  );
                }),
                const Divider(),
                ListTile(
                  title: Text("key_233".tr()),
                  subtitle: Text("key_234".tr()),
                  trailing: const Icon(Icons.settings),
                  onTap: () async {
                    final accepted = await OneSignal.Notifications.requestPermission(true);
                    if (!accepted && context.mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text("key_235".tr()),
                          content: Text("key_235a".tr()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("key_236".tr()),
                            )
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
    );
  }
}
