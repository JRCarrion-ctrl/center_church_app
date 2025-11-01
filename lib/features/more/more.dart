import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../app_state.dart';

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {

  Future<void> _openFamily() async {
    // This function remains largely the same as it's called by an onTap event.
    final client = GraphQLProvider.of(context).value;
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) return;

    const q = r'''
      query MyFamilyId($uid: String!) {
        family_members(
          where: { user_id: { _eq: $uid }, status: { _eq: "accepted" } }
          limit: 1
        ) { family_id }
      }
    ''';

    String? familyId;
    try {
      final res = await client.query(
        QueryOptions(
          document: gql(q),
          variables: {'uid': userId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (!res.hasException) {
        final rows = (res.data?['family_members'] as List<dynamic>? ?? []);
        if (rows.isNotEmpty) {
          familyId = (rows.first as Map<String, dynamic>)['family_id'] as String?;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    context.push('/more/family', extra: {'familyId': familyId});
  }

  @override
  Widget build(BuildContext context) {
    // 💡 THE FIX: Safely get the role using Provider.of/context.watch
    final appState = context.watch<AppState>();
    final role = appState.role ?? 'member'; // Fallback to 'member' if null

    final isAdmin = ['admin', 'supervisor', 'leader', 'owner'].contains(role);
    final isNurseryStaff = ['nursery_staff', 'owner'].contains(role);
    // NEW: Check if the user is an owner
    final isOwner = role == 'owner';

    final List<Map<String, dynamic>> moreItems = [
      {
        'title': "key_196a".tr(),
        'onTap': () => context.push('/more/profile'),
      },
      {
        'title': "key_196b".tr(),
        'onTap': _openFamily,
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
      if (isOwner)
        {
          'title': "key_admin_role_management_title".tr(),
          'onTap': () => context.push('/more/role-management'),
        },
    ];

    return Scaffold(
      body: ListView.builder(
        itemCount: moreItems.length,
        itemBuilder: (context, index) {
          final item = moreItems[index];
          return ListTile(
            title: Text(item['title'] as String),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              final onTap = item['onTap'] as VoidCallback?;
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
  }
}
