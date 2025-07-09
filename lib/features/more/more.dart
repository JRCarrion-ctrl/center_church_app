import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {

  Future<String?> _getCurrentUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    return res?['role'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getCurrentUserRole(),
      builder: (context, snapshot) {
        final role = snapshot.data ?? 'member';
        final isAdmin = ['admin', 'supervisor', 'leader', 'owner'].contains(role);

        final List<Map<String, dynamic>> moreItems = [
          {'title': 'Profile', 'route': '/more/profile'},
          {'title': 'Family', 'route': '/more/family'},
          {'title': 'Directory', 'route': '/more/directory'},
          {'title': 'Nursery Staff', 'route': null},
          {'title': 'Bible Studies', 'route': null},
          {'title': 'Settings', 'route': '/more/settings'},
          {'title': 'How To', 'route': null},
          {'title': 'FAQ', 'route': null},
        ];

        if (isAdmin) {
          moreItems.insert(8, {
            'title': 'Permissions',
            'route': null,
          });
        }

        return Scaffold(
          body: ListView.builder(
            itemCount: moreItems.length,
            itemBuilder: (context, index) {
              final item = moreItems[index];
              return ListTile(
                title: Text(item['title']),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  if (item['route'] != null) {
                    context.push(item['route']);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item['title']} page not available yet')),
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

}
