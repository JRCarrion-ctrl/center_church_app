// File: lib/features/groups/widgets/announcement_form_modal.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/core/time_service.dart';
import '../models/group_announcement.dart';
import 'package:easy_localization/easy_localization.dart';

class AnnouncementFormModal extends StatefulWidget {
  final String groupId;
  final GroupAnnouncement? existing;

  const AnnouncementFormModal({
    super.key,
    required this.groupId,
    this.existing,
  });

  @override
  State<AnnouncementFormModal> createState() => _AnnouncementFormModalState();
}

class _AnnouncementFormModalState extends State<AnnouncementFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  DateTime? _scheduledUtc;

  final supabase = Supabase.instance.client;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _title.text = widget.existing!.title;
      _body.text = widget.existing!.body ?? '';
      _scheduledUtc = widget.existing!.publishedAt;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);

    final announcement = {
      'group_id': widget.groupId,
      'title': _title.text.trim(),
      'body': _body.text.trim().isEmpty ? null : _body.text.trim(),
      'published_at': (_scheduledUtc ?? DateTime.now().toUtc()).toIso8601String(),
    };

    try {
      final navigator = Navigator.of(context);
      if (widget.existing != null) {
        await supabase
            .from('group_announcements')
            .update(announcement)
            .eq('id', widget.existing!.id);
      } else {
        await supabase.from('group_announcements').insert({
          ...announcement,
          'created_by': supabase.auth.currentUser?.id,
        });
      }

      navigator.pop(); // triggers refresh on parent page
    } catch (e) {
      debugPrint('Error saving announcement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledUtc?.toLocal() ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledUtc?.toLocal() ?? now),
    );
    if (time == null) return;

    final utc = TimeService.combineLocalDateAndTimeToUtc(date, time);
    setState(() => _scheduledUtc = utc);
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
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(
                  _scheduledUtc == null
                      ? 'No schedule set'
                      : 'Scheduled: ${TimeService.formatUtcToLocal(_scheduledUtc!)}',
                ),
                trailing: TextButton(
                  onPressed: _pickDateTime,
                  child: Text("key_158".tr()),
                ),
              ),
              const SizedBox(height: 20),

              if (saving)
                const CircularProgressIndicator()
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(isEditing ? "key_041i".tr() : "key_141h".tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text("key_159".tr()),
                    ),
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }
}
