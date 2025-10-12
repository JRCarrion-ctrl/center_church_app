// File: lib/features/more/data_and_delete_account_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app_state.dart';
import 'package:easy_localization/easy_localization.dart';

class DataAndDeleteAccountPage extends StatelessWidget {
  const DataAndDeleteAccountPage({super.key});

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("key_204".tr()),
        content: Text("key_204a".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("key_205".tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteAccount(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text("key_206".tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final client = GraphQLProvider.of(context).value;
    final appState = context.read<AppState>();

    // Hasura Action (or Remote Schema) that performs the deletion
    // Suggested response shape: { ok: Boolean!, message: String }
    const m = r'''
      mutation DeleteAccount {
        delete_account {
          ok
          message
        }
      }
    ''';

    try {
      final res = await client.mutate(
        MutationOptions(document: gql(m)),
      );

      final ok = res.data?['delete_account']?['ok'] == true;
      if (res.hasException || !ok) {
        final msg = res.data?['delete_account']?['message'] ?? res.exception.toString();
        throw Exception(msg);
      }

      await appState.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_207".tr())),
      );
    }
  }

  Future<void> _clearLocalData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("key_208".tr())),
    );
  }

  Future<void> _clearCache() async {
    final dir = await getTemporaryDirectory();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_209".tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("key_209a".tr(), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          ListTile(
            title: Text("key_210".tr()),
            subtitle: Text("key_211".tr()),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () => _showDeleteConfirmation(context),
          ),
          const Divider(),
          ListTile(
            title: Text("key_212".tr()),
            subtitle: Text("key_213".tr()),
            trailing: const Icon(Icons.cleaning_services),
            onTap: () => _clearLocalData(context),
          ),
          ListTile(
            title: Text("key_214".tr()),
            subtitle: Text("key_215".tr()),
            trailing: const Icon(Icons.cleaning_services),
            onTap: () async {
              await _clearCache();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("key_216".tr())),
              );
            },
          ),
        ],
      ),
    );
  }
}
// TODO: Backend work needed