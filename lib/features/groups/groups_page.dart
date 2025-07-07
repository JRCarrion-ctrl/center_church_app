import 'package:flutter/material.dart';
import 'your_groups_section.dart';
import 'joinable_groups_section.dart';
import 'invitations_section.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final _yourGroupsKey = GlobalKey<YourGroupsSectionState>();
  final _joinableGroupsKey = GlobalKey<JoinableGroupsSectionState>();
  final _invitationsKey = GlobalKey<InvitationsSectionState>();

  Future<void> _refreshAllSections() async {
    _yourGroupsKey.currentState?.refresh();
    _joinableGroupsKey.currentState?.refresh();
    _invitationsKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAllSections,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    YourGroupsSection(key: _yourGroupsKey),
                    const SizedBox(height: 24),
                    JoinableGroupsSection(key: _joinableGroupsKey),
                    const SizedBox(height: 24),
                    InvitationsSection(key: _invitationsKey),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
