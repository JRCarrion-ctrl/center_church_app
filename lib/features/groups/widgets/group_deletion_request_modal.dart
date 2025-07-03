import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../deletion_request_service.dart';

class GroupDeletionRequestModal extends StatefulWidget {
  final String groupId;

  const GroupDeletionRequestModal({super.key, required this.groupId});

  @override
  State<GroupDeletionRequestModal> createState() =>
      _GroupDeletionRequestModalState();
}

class _GroupDeletionRequestModalState
    extends State<GroupDeletionRequestModal> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final reason = _controller.text.trim();

    if (userId == null || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reason is required.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await DeletionRequestService().requestDeletion(
        groupId: widget.groupId,
        userId: userId,
        reason: reason,
      );

      if (!mounted) return;
      Navigator.pop(context); // close modal
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Request Group Deletion',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Why do you want to delete this group?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _saving
                ? const CircularProgressIndicator()
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Submit Request'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
