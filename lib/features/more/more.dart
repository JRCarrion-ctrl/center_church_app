// File: lib/features/more/more.dart
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../app_state.dart';
import '../../shared/widgets/app_surface.dart';
import '../../shared/widgets/glass.dart';

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  // (Keep your existing _openFamily logic here)
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
    if (familyId != null && familyId.isNotEmpty) {
      context.push('/more/family?familyId=$familyId');
    } else {
      context.push('/more/family');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final role = appState.userRole.name; // Fixed to use userRole.name
    final colorScheme = Theme.of(context).colorScheme;

    final isAdmin = ['supervisor', 'owner'].contains(role);
    final isNurseryStaff = ['nursery_staff', 'owner', 'supervisor'].contains(role);
    final isOwner = role == 'owner';

    final List<Map<String, dynamic>> moreItems = [
      {'title': "key_196a".tr(), 'icon': Icons.person_outline, 'onTap': () => context.push('/more/profile')},
      {'title': "key_196b".tr(), 'icon': Icons.family_restroom_outlined, 'onTap': _openFamily},
      {'title': "key_196c".tr(), 'icon': Icons.contacts_outlined, 'onTap': () => context.push('/more/directory')},
      if (isNurseryStaff)
        {'title': "key_196d".tr(), 'icon': Icons.child_care_outlined, 'onTap': () => context.push('/more/nursery')},
      {'title': "key_196e".tr(), 'icon': Icons.auto_stories_outlined, 'onTap': () => context.push('/more/study')},
      if (isAdmin)
        {'title': "key_196f".tr(), 'icon': Icons.assignment_late_outlined, 'onTap': () => context.push('/more/study/requests')},
      {'title': "key_196g".tr(), 'icon': Icons.settings_outlined, 'onTap': () => context.push('/more/settings')},
      {'title': "key_196h".tr(), 'icon': Icons.help_outline, 'onTap': () => context.push('/more/how_to')},
      {'title': "key_196i".tr(), 'icon': Icons.quiz_outlined, 'onTap': () => context.push('/more/faq')},
      if (isOwner)
        {'title': "key_admin_role_management_title".tr(), 'icon': Icons.admin_panel_settings_outlined, 'onTap': () => context.push('/more/role-management')},
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Same softly tinted page as the group chat.
          Positioned.fill(child: ColoredBox(color: appBackgroundColor(context))),
          // 3. Main Menu Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Same photo header as the Groups and Calendar tabs.
                      PhotoHeader(
                        title: "main_5".tr(),
                        subtitle: 'more_subtitle'.tr(),
                        height: 120,
                      ),
                      const SizedBox(height: 16),
                      
                      // Unified Glass Menu Container
                      _SleekMenuWrapper(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: moreItems.length,
                          separatorBuilder: (_, _) => const Divider(indent: 64),
                          itemBuilder: (context, index) {
                            final item = moreItems[index];
                            return ListTile(
                              shape: const RoundedRectangleBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colorScheme.onSurface.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(item['icon'] as IconData, size: 20, color: colorScheme.onSurface),
                              ),
                              title: Text(item['title'] as String),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onTap: item['onTap'] as VoidCallback,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✨ Universal Menu Housing for a Sleek Hub
class _SleekMenuWrapper extends StatelessWidget {
  final Widget child;
  const _SleekMenuWrapper({required this.child});

  @override
  Widget build(BuildContext context) => AppCard(child: child);
}
