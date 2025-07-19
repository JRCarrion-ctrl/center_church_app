import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app_state.dart';

class DataAndDeleteAccountPage extends StatelessWidget {
  const DataAndDeleteAccountPage({super.key});

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteAccount(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final client = Supabase.instance.client;
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not signed in');

      await Supabase.instance.client.functions.invoke('delete_account');
      await appState.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    }
  }

  Future<void> _clearLocalData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local app data cleared.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data & Delete Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Manage your account data and deletion preferences.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Delete My Account'),
            subtitle: const Text('Permanently remove your account and all associated data.'),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () => _showDeleteConfirmation(context),
          ),
          const Divider(),
          ListTile(
            title: const Text('Clear Local App Data'),
            subtitle: const Text('Reset app preferences and cached information.'),
            trailing: const Icon(Icons.cleaning_services),
            onTap: () => _clearLocalData(context),
          ),
        ],
      ),
    );
  }
}
