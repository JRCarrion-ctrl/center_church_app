// File: lib/features/calendar/widgets/app_event_form_modal.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_event.dart';
import '../event_service.dart';

/// Modal bottom sheet for creating or editing an AppEvent
class AppEventFormModal extends StatefulWidget {
  final AppEvent? existing;

  const AppEventFormModal({super.key, this.existing});

  @override
  State<AppEventFormModal> createState() => _AppEventFormModalState();
}

class _AppEventFormModalState extends State<AppEventFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _service = EventService();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.existing;
    _titleController = TextEditingController(text: ev?.title ?? '');
    _descController = TextEditingController(text: ev?.description ?? '');
    if (ev != null) {
      _selectedDate = ev.eventDate;
      _selectedTime = TimeOfDay.fromDateTime(ev.eventDate);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null && mounted) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null && mounted) setState(() => _selectedTime = time);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      if (mounted){ ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick date & time')));}
      return;
    }

    setState(() => _saving = true);
    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final appEvent = AppEvent(
      id: widget.existing?.id ?? '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      eventDate: dt,
      imageUrl: widget.existing?.imageUrl,
    );

    try {
      await _service.saveAppEvent(appEvent);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted){ ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving app event: $e')));}
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.existing == null ? 'Add App Event' : 'Edit App Event',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        child: Text(
                          _selectedDate == null
                              ? 'Pick Date'
                              : DateFormat.yMMMd().format(_selectedDate!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickTime,
                        child: Text(
                          _selectedTime == null
                              ? 'Pick Time'
                              : _selectedTime!.format(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : Text(widget.existing == null ? 'Create' : 'Update'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
