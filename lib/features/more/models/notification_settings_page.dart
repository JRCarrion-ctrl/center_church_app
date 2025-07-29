import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final profileRes = await supabase
        .from('profiles')
        .select('global_mute')
        .eq('id', userId)
        .single();

    globalMute = profileRes['global_mute'] ?? false;

    final List<dynamic> membershipRes = await supabase
        .from('group_memberships')
        .select('group_id, groups (id, name)')
        .eq('user_id', userId)
        .eq('status', 'approved');

    final List<dynamic> mutedRes = await supabase
        .from('notification_settings')
        .select('group_id')
        .eq('user_id', userId)
        .eq('muted', true);

    if (mounted) {
      setState(() {
        groups = membershipRes.map<Map<String, dynamic>>((m) => m['groups'] as Map<String, dynamic>).toList();
        mutedGroupIds = mutedRes.map((m) => m['group_id'] as String).toSet();
        loading = false;
      });
    }
  }

  Future<void> _toggleGlobalMute(bool mute) async {
    setState(() => savingGlobalMute = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;

    await Supabase.instance.client
        .from('profiles')
        .update({'global_mute': mute})
        .eq('id', userId);

    // OneSignal control (v5.3.4)
    if (mute) {
      await OneSignal.User.pushSubscription.optOut();
    } else {
      await OneSignal.User.pushSubscription.optIn();
    }

    setState(() {
      globalMute = mute;
      savingGlobalMute = false;
    });
  }

  Future<void> _toggleMute(String groupId, bool muted) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    await Supabase.instance.client
        .from('notification_settings')
        .upsert({
          'user_id': userId,
          'group_id': groupId,
          'muted': muted,
        });

    setState(() {
      if (muted) {
        mutedGroupIds.add(groupId);
      } else {
        mutedGroupIds.remove(groupId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SwitchListTile(
                title: const Text('Mute All Notifications'),
                value: globalMute,
                onChanged: savingGlobalMute ? null : _toggleGlobalMute,
                subtitle: const Text('Disables all in-app and push notifications'),
              ),
              const Divider(),
              ...groups.map((group) {
                final groupId = group['id'] as String;
                final groupName = group['name'] ?? 'Unnamed Group';

                return SwitchListTile(
                  title: Text(groupName),
                  value: !mutedGroupIds.contains(groupId),
                  onChanged: globalMute
                      ? null
                      : (val) => _toggleMute(groupId, !val),
                  subtitle: const Text('Enable notifications'),
                );
              }),
              const Divider(),
              ListTile(
                title: const Text('Re-enable Push Notifications'),
                subtitle: const Text('If you previously denied them'),
                trailing: const Icon(Icons.settings),
                onTap: () async {
                  final accepted = await OneSignal.Notifications.requestPermission(true);
                  if (!accepted && context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Notification Permission Denied"),
                        content: const Text(
                          "Please enable push notifications from your device's settings.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("OK"),
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
