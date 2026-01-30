// File: lib/features/groups/widgets/reaction_details_modal.dart 
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../group_chat_service.dart';

class ReactionDetailsModal extends StatefulWidget {
  final String messageId;
  final GroupChatService service;

  const ReactionDetailsModal({
    super.key,
    required this.messageId,
    required this.service,
  });

  static void show(BuildContext context, String messageId, GroupChatService service) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ReactionDetailsModal(messageId: messageId, service: service),
    );
  }

  @override
  State<ReactionDetailsModal> createState() => _ReactionDetailsModalState();
}

class _ReactionDetailsModalState extends State<ReactionDetailsModal> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.getReactionDetails(widget.messageId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Reactions", // "key_reactions".tr()
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading reactions"));
                }

                final reactions = snapshot.data ?? [];
                if (reactions.isEmpty) {
                  return Center(child: Text("No reactions yet"));
                }

                return ListView.separated(
                  itemCount: reactions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = reactions[index];
                    final profile = item['profile'] ?? {};
                    final emoji = item['emoji'] ?? '';
                    final name = profile['display_name'] ?? 'Unknown';
                    final photo = profile['photo_url'];

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: (photo != null && photo.isNotEmpty)
                            ? CachedNetworkImageProvider(photo)
                            : null,
                        child: (photo == null || photo.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(name),
                      trailing: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}