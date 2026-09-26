import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../group_service.dart';
import '../models/group_model.dart';

class AssignSubgroupModal extends StatelessWidget {
  final String parentGroupId;
  final String targetUserId;
  final String targetUserName;

  const AssignSubgroupModal({
    super.key,
    required this.parentGroupId,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  Widget build(BuildContext context) {
    final groups = context.read<GroupService>();

    return AlertDialog(
      title: Text('Assign $targetUserName'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<GroupModel>>(
          future: groups.getSubGroups(parentGroupId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            
            final subgroups = snapshot.data ?? [];
            if (subgroups.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No subgroups exist yet.'),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: subgroups.length,
              itemBuilder: (ctx, i) {
                final sg = subgroups[i];
                return ListTile(
                  title: Text(sg.name),
                  trailing: const Icon(Icons.person_add_alt_1),
                  onTap: () async {
                    try {
                      await groups.addMemberDirectly(sg.id, targetUserId);
                      if (context.mounted) {
                        Navigator.pop(context, sg.name);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      }
                    }
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
      ],
    );
  }
}