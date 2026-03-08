// File: lib/features/more/more.dart
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
    context.push('/more/family', extra: {'familyId': familyId});
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final role = appState.userRole.name; // Fixed to use userRole.name
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
          // 1. The Global Atmospheric Background
          Positioned.fill(
            child: Image.asset('assets/landing_v2_blurred_2.png', fit: BoxFit.cover),
          ),
          // 2. Tint Overlay
          Positioned.fill(
            child: Container(
              color: isDark ? Colors.black.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.75),
            ),
          ),
          // 3. Main Menu Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    children: [
                      // Header title to match the "sleek" spacing
                      Text(
                        "main_5".tr().toUpperCase(), // Or use a static "MORE"
                        style: textTheme.headlineSmall?.copyWith( // ✨ Increased from labelSmall
                          fontWeight: FontWeight.w900, // ✨ Extra bold for better definition
                          letterSpacing: 3.0,          // ✨ Increased spacing for a premium feel
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Unified Glass Menu Container
                      _SleekMenuWrapper(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: moreItems.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1, 
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          ),
                          itemBuilder: (context, index) {
                            final item = moreItems[index];
                            return ListTile(
                              leading: Icon(item['icon'] as IconData, color: colorScheme.primary),
                              title: Text(
                                item['title'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 20),
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // Ensures the list items don't bleed over rounded corners
      child: child,
    );
  }
}