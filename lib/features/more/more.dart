import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

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
        final isNurseryStaff = ['nursery_staff', 'owner'].contains(role);

        final List<Map<String, dynamic>> moreItems = [
          {
            'title': "key_196a".tr(),
            'onTap': () => context.push('/more/profile'),
          },
          {
            'title': "key_196b".tr(),
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
            'title': "key_196c".tr(),
            'onTap': () => context.push('/more/directory'),
          },
          if (isNurseryStaff)
            {
              'title': "key_196d".tr(),
              'onTap': () => context.push('/nursery'),
            },
          {
            'title': "key_196e".tr(),
            'onTap': () => context.push('/more/study'),
          },
          if (isAdmin)
            {
              'title': "key_196f".tr(),
              'onTap': () => context.push('/more/study/requests'),
            },
          {
            'title': "key_196g".tr(),
            'onTap': () => context.push('/more/settings'),
          },
          {
            'title': "key_196h".tr(),
            'onTap': () => context.push('/more/how_to'),
          },
          {
            'title': "key_196i".tr(),
            'onTap': () => context.push('/more/faq'),
          },
          if (isAdmin)
            {
              'title': "key_196j".tr(),
              'onTap': null,
            },
        ];

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
