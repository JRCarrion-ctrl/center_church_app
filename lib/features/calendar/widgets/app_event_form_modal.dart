// File: lib/features/calendar/widgets/app_event_form_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import '../models/app_event.dart';
import '../event_service.dart';
import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/media/image_picker_field.dart';
import '../event_photo_storage_service.dart';

// Helper class to track ID + UI state
class _SlotEditor {
  final String? id; // Null if new
  final TextEditingController controller;
  int maxSlots;

  _SlotEditor({this.id, required String title, required this.maxSlots})
      : controller = TextEditingController(text: title);

  void dispose() {
    controller.dispose();
  }
}

class AppEventFormModal extends StatefulWidget {
  final AppEvent? existing;

  const AppEventFormModal({super.key, this.existing});

  @override
  State<AppEventFormModal> createState() => _AppEventFormModalState();
}

class _AppEventFormModalState extends State<AppEventFormModal> {
  final _formKey = GlobalKey<FormState>();
  late EventService _service;
  late EventPhotoStorageService _photoService;
  bool _svcReady = false;

  File? _localImageFile;
  bool _imageRemoved = false;
  String? _imageUrl;

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  
  // Changed to list of _SlotEditor
  final List<_SlotEditor> _slots = [];

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.existing;
    _titleController = TextEditingController(text: ev?.title ?? '');
    _descController = TextEditingController(text: ev?.description ?? '');
    _locationController = TextEditingController(text: ev?.location ?? '');
    _imageUrl = widget.existing?.imageUrl;
    
    if (ev != null) {
      final local = ev.eventDate.toLocal();
      _selectedDate = DateTime(local.year, local.month, local.day);
      _selectedTime = TimeOfDay.fromDateTime(local);
      if (ev.eventEnd != null) {
        final localEnd = ev.eventEnd!.toLocal();
        _endDate = DateTime(localEnd.year, localEnd.month, localEnd.day);
        _endTime = TimeOfDay.fromDateTime(localEnd);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_svcReady) {
      final client = GraphQLProvider.of(context).value;
      final userId = context.read<AppState>().profile?.id;
      _service = EventService(client, currentUserId: userId);
      _photoService = EventPhotoStorageService(client);
      _svcReady = true;

      if (widget.existing != null) {
        _loadSlots(widget.existing!.id);
      }
    }
  }

  Future<void> _loadSlots(String eventId) async {
    try {
      final slots = await _service.fetchAppEventSlots(eventId);
      if (!mounted) return;
      setState(() {
        for (var s in slots) {
          _slots.add(_SlotEditor(id: s.id, title: s.title, maxSlots: s.maxSlots));
        }
      });
    } catch (e) {
      debugPrint("Error loading existing slots: $e");
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    for (var s in _slots) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSlot() {
    setState(() {
      _slots.add(_SlotEditor(title: '', maxSlots: 1));
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots[index].dispose();
      _slots.removeAt(index);
    });
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

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _selectedDate ?? now,
      firstDate: _selectedDate ?? now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );  
    if (date != null && mounted) setState(() => _endDate = date);
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (time != null && mounted) setState(() => _endTime = time);
  }

  Future<void> _save() async {
    if (!_svcReady || !_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_040".tr())));
      return;
    }

    setState(() => _saving = true);

    try {
      String? finalImageUrl = _imageUrl;
      if (_imageRemoved) finalImageUrl = null;
      if (_localImageFile != null) {
        finalImageUrl = await _photoService.uploadEventPhoto(
          file: _localImageFile!,
          keyPrefix: 'app_events',
          logicalId: widget.existing?.id ?? 'new',
        );
      }

      final dt = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
      DateTime? finalEndDt = (_endDate != null && _endTime != null) 
          ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime!.hour, _endTime!.minute)
          : null;

      // Map _SlotEditor back to AppEventSlot, preserving ID
      final slots = _slots.map((s) {
        return AppEventSlot(
          id: s.id, // Pass ID to service!
          title: s.controller.text.trim(),
          maxSlots: s.maxSlots,
        );
      }).where((s) => s.title.isNotEmpty).toList();

      final event = AppEvent(
        id: widget.existing?.id ?? '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        eventDate: dt.toUtc(),
        eventEnd: finalEndDt?.toUtc(),
        imageUrl: finalImageUrl,
        location: _locationController.text.trim(),
      );

      await _service.saveAppEventWithSlots(event, slots);
    
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_041".tr())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? "key_041a".tr() : "key_041b".tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: "key_041c".tr()),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(labelText: "key_041d".tr()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ImagePickerField(
                label: "key_041d2".tr(),
                initialUrl: _imageUrl,
                onChanged: (file, removed) {
                  setState(() {
                    _localImageFile = file;
                    _imageRemoved = removed;
                  });
                },
              ),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: "key_041e".tr()),
              ),
              const SizedBox(height: 24),
              const Text("Start Time", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickDate,
                      child: Text(_selectedDate == null ? "key_041f".tr() : DateFormat.yMMMd().format(_selectedDate!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickTime,
                      child: Text(_selectedTime == null ? "key_041g".tr() : _selectedTime!.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text("End Time (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickEndDate,
                      child: Text(_endDate == null ? "Select Date" : DateFormat.yMMMd().format(_endDate!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickEndTime,
                      child: Text(_endTime == null ? "Select Time" : _endTime!.format(context)),
                    ),
                  ),
                  if (_endDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() { _endDate = null; _endTime = null; }),
                    )
                ],
              ),
              
              const Divider(height: 48),
              Text("Sign-up Slots (Optional)", style: Theme.of(context).textTheme.titleMedium),
              const Text("Specify items or tasks needed for this event.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),

              ...List.generate(_slots.length, (index) {
                final slot = _slots[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: slot.controller,
                          decoration: const InputDecoration(labelText: "Item needed", isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<int>(
                          initialValue: slot.maxSlots,
                          decoration: const InputDecoration(labelText: "Qty", isDense: true),
                          items: List.generate(20, (i) => i + 1)
                              .map((i) => DropdownMenuItem(value: i, child: Text("$i")))
                              .toList(),
                          onChanged: (val) => setState(() => slot.maxSlots = val!),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeSlot(index),
                      ),
                    ],
                  ),
                );
              }),
              
              OutlinedButton.icon(
                onPressed: _addSlot,
                icon: const Icon(Icons.add),
                label: const Text("Add Item Slot"),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const CircularProgressIndicator() : Text(widget.existing == null ? "key_041h".tr() : "key_041i".tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}