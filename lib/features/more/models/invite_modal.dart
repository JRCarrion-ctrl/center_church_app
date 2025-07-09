// File: lib/features/more/models/invite_modal.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteExistingUserModal extends StatefulWidget {
  final String familyId;
  final String invitedBy;

  const InviteExistingUserModal({super.key, required this.familyId, required this.invitedBy});

  @override
  State<InviteExistingUserModal> createState() => _InviteExistingUserModalState();
}

class _InviteExistingUserModalState extends State<InviteExistingUserModal> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final supabase = Supabase.instance.client;

  bool isLoading = false;
  String? error;
  String relationship = 'Sibling';
  final relationships = ['Parent', 'Child', 'Spouse', 'Sibling', 'Other'];
  List<Map<String, dynamic>> suggestions = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchProfiles(String query) async {
    if (query.trim().isEmpty) {
      setState(() => suggestions = []);
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await supabase
          .from('profiles')
          .select('id, display_name, email, phone, photo_url')
          .or('email.ilike.%$query%,phone.ilike.%$query%')
          .limit(5);

      setState(() => suggestions = List<Map<String, dynamic>>.from(result));
    } catch (e) {
      setState(() => error = 'Error searching profiles');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _sendInvite(Map<String, dynamic> profile) async {
    final userId = profile['id'];

    try {
      await supabase.from('family_members').insert({
        'family_id': widget.familyId,
        'user_id': userId,
        'relationship': relationship,
        'status': 'pending',
        'invited_by': widget.invitedBy,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending invite: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Invite a Family Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Email or Phone'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter an email or phone number'
                    : null,
                onChanged: _searchProfiles,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: relationship,
                items: relationships.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => relationship = val!),
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),
              const SizedBox(height: 12),
              if (isLoading) const LinearProgressIndicator(),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              if (suggestions.isNotEmpty)
                ...suggestions.map((profile) {
                  final displayName = profile['display_name'] ?? 'Unnamed';
                  final contact = profile['email'] ?? profile['phone'] ?? '';
                  final photoUrl = profile['photo_url'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person) : null,
                    ),
                    title: Text(displayName),
                    subtitle: Text(contact),
                    onTap: () => _sendInvite(profile),
                  );
                }),
              if (!isLoading && suggestions.isEmpty && _controller.text.trim().isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No users found', style: TextStyle(color: Colors.grey)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
