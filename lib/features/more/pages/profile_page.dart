// file: lib/features/more/pages/profile_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  String displayName = '';
  bool? visible;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final data = await supabase
        .from('profiles')
        .select('display_name, visible_in_directory')
        .eq('id', userId)
        .single();

    setState(() {
      displayName = data['display_name'] ?? 'Unnamed';
      visible = data['visible_in_directory'] ?? true;
    });
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: displayName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new display name'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              final userId = supabase.auth.currentUser?.id;
              final navigator = Navigator.of(context);
              if (userId != null && newName.isNotEmpty) {
                await supabase.from('profiles').update({
                  'display_name': newName,
                }).eq('id', userId);
                setState(() => displayName = newName);
              }
              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleVisibility(bool value) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('profiles').update({
      'visible_in_directory': value,
    }).eq('id', userId);

    setState(() => visible = value);
  }

  Future<void> _logout() async {
    final appState = Provider.of<AppState>(context, listen: false);

    await supabase.auth.signOut();
    await appState.signOut();
    await appState.resetLandingSeen();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );
      context.go('/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: visible == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: $displayName', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _editDisplayName,
                    child: const Text('Edit Display Name'),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: const Text('Visible in Directory?'),
                    value: visible!,
                    onChanged: _toggleVisibility,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Logout'),
                  ),
                ],
              ),
      ),
    );
  }
}
