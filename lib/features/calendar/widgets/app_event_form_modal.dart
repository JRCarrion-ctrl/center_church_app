// File: lib/features/calendar/widgets/app_event_form_modal.dart

import 'package:flutter/material.dart';
import '../models/app_event.dart';
import '../event_service.dart';
import 'package:easy_localization/easy_localization.dart';

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
  late TextEditingController _locationController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.existing;
    _titleController = TextEditingController(text: ev?.title ?? '');
    _descController = TextEditingController(text: ev?.description ?? '');
    _locationController = TextEditingController(text: ev?.location ?? '');
    if (ev != null) {
      final local = ev.eventDate.toLocal();
      _selectedDate = DateTime(local.year, local.month, local.day);
      _selectedTime = TimeOfDay.fromDateTime(local);
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
          .showSnackBar(SnackBar(content: Text("key_040".tr())));}
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
      eventDate: dt.toUtc(),
      imageUrl: widget.existing?.imageUrl,
      location: _locationController.text.trim(),
    );

    try {
      await _service.saveAppEvent(appEvent);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted){ ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("key_041".tr())));}
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
                  widget.existing == null ? "key_041a".tr() : "key_041b".tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: "key_041c".tr()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _descController,
                  decoration: InputDecoration(labelText: "key_041d".tr()),
                  maxLines: 2,
                ),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(labelText: "key_041e".tr()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        child: Text(
                          _selectedDate == null
                              ? "key_041f".tr()
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
                              ? "key_041g".tr()
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
                      : Text(widget.existing == null ? "key_041h".tr() : "key_041i".tr()),
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
