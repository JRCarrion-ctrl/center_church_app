// File: lib/features/groups/pages/edit_group_info_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import '../../../shared/widgets/primary_button.dart';

class EditGroupInfoPage extends StatefulWidget {
  final Group group;

  const EditGroupInfoPage({super.key, required this.group});

  @override
  State<EditGroupInfoPage> createState() => _EditGroupInfoPageState();
}

class _EditGroupInfoPageState extends State<EditGroupInfoPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController = TextEditingController(text: widget.group.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await Supabase.instance.client.from('groups').update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
      }).eq('id', widget.group.id);

      // Fetch updated group before returning
      final updatedData = await Supabase.instance.client
          .from('groups')
          .select()
          .eq('id', widget.group.id)
          .single();

      final updatedGroup = Group.fromMap(updatedData);

      if (!mounted) return;
      Navigator.of(context).pop(updatedGroup); // return success flag
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Group Info')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
                validator: (value) => value == null || value.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
              ),
              const Spacer(),
              if (_saving) const CircularProgressIndicator(),
              if (!_saving)
                PrimaryButton(
                  title: 'Save Changes',
                  onTap: _saveChanges,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
