import 'package:flutter/material.dart';
import 'package:ccf_app/features/groups/models/group_model.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvitationsSection extends StatefulWidget {
  const InvitationsSection({super.key});

  @override
  State<InvitationsSection> createState() => _InvitationsSectionState();
}

class _InvitationsSectionState extends State<InvitationsSection> {
  late Future<List<GroupModel>> _futureInvites;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _futureInvites = GroupService().getGroupInvitations(userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GroupModel>>(
      future: _futureInvites,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }

        if (snapshot.hasError) {
          return Text('Error loading invitations');
        }

        final invites = snapshot.data ?? [];

        if (invites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invitations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...invites.map((group) => Card(
                  child: ListTile(
                    title: Text(group.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () {
                            // Accept logic
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            // Decline logic
                          },
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}
