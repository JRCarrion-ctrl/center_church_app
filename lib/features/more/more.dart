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
          {
            'title': 'Profile',
            'onTap': () => context.push('/more/profile'),
          },
          {
            'title': 'Family',
            'onTap': () async {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId == null) return;

              final result = await Supabase.instance.client
                  .from('family_members')
                  .select('family_id')
                  .eq('user_id', userId)
                  .eq('status', 'accepted')
                  .maybeSingle();

              final familyId = result?['family_id'] as String?;
              if (!context.mounted) return;
              context.push('/more/family', extra: {'familyId': familyId});
            }
          },
          {
            'title': 'Directory',
            'onTap': () => context.push('/more/directory'),
          },
          {
            'title': 'Nursery Staff',
            'onTap': () => context.push('/nursery'),
          },
          {
            'title': 'Bible Studies',
            'onTap': () => context.push('/more/study'),
          },
          {
            'title': 'Settings',
            'onTap': () => context.push('/more/settings'),
          },
          {
            'title': 'How To Use',
            'onTap': () => context.push('/more/how_to'),
          },
          {
            'title': 'FAQ',
            'onTap': () => context.push('/more/faq'),
          },
        ];

        if (isAdmin) {
          moreItems.insert(8, {
            'title': 'Permissions',
            'onTap': null,
          });
          moreItems.insert(9, {
            'title': 'Bible Study Requests',
            'onTap': () => context.push('/more/study/requests'),
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
                  final onTap = item['onTap'];
                  if (onTap != null) {
                    onTap();
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
