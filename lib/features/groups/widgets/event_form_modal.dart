// File: lib/features/groups/widgets/event_form_modal.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ccf_app/core/graph_provider.dart';

import '../../calendar/models/group_event.dart';
import '../../calendar/event_service.dart';

/// Modal bottom sheet for creating or editing a GroupEvent
class EventFormModal extends StatefulWidget {
  final String groupId;
  final GroupEvent? existing;

  const EventFormModal({super.key, required this.groupId, this.existing});
  @override
  State<EventFormModal> createState() => _EventFormModalState();
}

class _EventFormModalState extends State<EventFormModal> {
  final _formKey = GlobalKey<FormState>();

  late EventService _service;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;

  DateTime? _selectedDateTime;
  String? _dateTimeError;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.existing;
    _titleController = TextEditingController(text: ev?.title ?? '');
    _descController = TextEditingController(text: ev?.description ?? '');
    _locationController = TextEditingController(text: ev?.location ?? '');
    if (ev != null) {
      _selectedDateTime = ev.eventDate.toLocal();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      final client = GraphProvider.of(context);
      _service = EventService(client);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          _selectedDateTime?.hour ?? TimeOfDay.now().hour,
          _selectedDateTime?.minute ?? TimeOfDay.now().minute,
        );
        _dateTimeError = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedDateTime != null
          ? TimeOfDay.fromDateTime(_selectedDateTime!)
          : TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime?.year ?? DateTime.now().year,
          _selectedDateTime?.month ?? DateTime.now().month,
          _selectedDateTime?.day ?? DateTime.now().day,
          time.hour,
          time.minute,
        );
        _dateTimeError = null;
      });
    }
  }

  void _validateAndSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateTime == null) {
      setState(() => _dateTimeError = 'key_160'.tr());
      return;
    }

    _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final event = GroupEvent(
      id: widget.existing?.id ?? '',
      groupId: widget.groupId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      location: _locationController.text.trim(),
      imageUrl: widget.existing?.imageUrl,
      eventDate: _selectedDateTime!.toUtc(),
    );
    
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _service.saveEvent(event);
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error saving event: $e')));
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
                  widget.existing == null ? "key_161".tr() : "key_161a".tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: "key_156".tr()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _descController,
                  decoration: InputDecoration(labelText: "key_068c".tr()),
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
                          _selectedDateTime == null
                              ? "key_041f".tr()
                              : DateFormat.yMMMd().format(_selectedDateTime!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickTime,
                        child: Text(
                          _selectedDateTime == null
                              ? "key_041g".tr()
                              : TimeOfDay.fromDateTime(_selectedDateTime!).format(context),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_dateTimeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _dateTimeError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _validateAndSave,
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