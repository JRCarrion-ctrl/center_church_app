import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class AppAnnouncementFormModal extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const AppAnnouncementFormModal({super.key, this.existing});

  @override
  State<AppAnnouncementFormModal> createState() => _AppAnnouncementFormModalState();
}

class _AppAnnouncementFormModalState extends State<AppAnnouncementFormModal> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  DateTime? _scheduled;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a != null) {
      _title.text = a['title'] ?? '';
      _body.text = a['body'] ?? '';
      _scheduled = DateTime.tryParse(a['published_at'] ?? '')?.toLocal();
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduled ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduled ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_190".tr())),
        );
      }
      setState(() => saving = false);
      return;
    }

    final data = {
      'title': _title.text.trim(),
      'body': _body.text.trim().isEmpty ? null : _body.text.trim(),
      'published_at': (_scheduled ?? DateTime.now()).toUtc().toIso8601String(),
    };

    try {
      if (widget.existing != null) {
        await supabase
            .from('app_announcements')
            .update(data)
            .eq('id', widget.existing!['id']);
      } else {
        await supabase.from('app_announcements').insert({
          ...data,
          'created_by': userId,
        });
      }

      if (mounted) Navigator.pop(context, data);
    } catch (e) {
      debugPrint('Error saving announcement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save announcement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? "key_154".tr() : "key_155".tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _title,
                decoration: InputDecoration(labelText: "key_156".tr()),
                validator: (value) =>
                    value == null || value.isEmpty ? "key_156a".tr() : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _body,
                decoration: InputDecoration(labelText: "key_157".tr()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(
                  _scheduled == null
                      ? "key_190a".tr()
                      : 'Scheduled: ${_scheduled!.toLocal()}',
                ),
                trailing: TextButton(
                  onPressed: _pickDateTime,
                  child: Text("key_192".tr()),
                ),
              ),
              const SizedBox(height: 20),

              saving
                  ? const CircularProgressIndicator()
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: saving ? null : _submit,
                            child: Text(isEditing ? "key_041i".tr() : "key_041h".tr()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text("key_193".tr()),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
