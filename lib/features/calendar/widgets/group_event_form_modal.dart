// File: lib/features/calendar/widgets/group_event_form_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import '../models/group_event.dart';
import '../event_service.dart';
import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/media/image_picker_field.dart';
import '../event_photo_storage_service.dart';

class GroupEventFormModal extends StatefulWidget {
  final GroupEvent? existing;
  final String? groupId;

  const GroupEventFormModal({super.key, this.existing, this.groupId});

  @override
  State<GroupEventFormModal> createState() => _GroupEventFormModalState();
}

class _GroupEventFormModalState extends State<GroupEventFormModal> {
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

  DateTime? _selectedDateTime;
  
  // --- ADDED: End Time State ---
  DateTime? _endDateTime; 
  // -----------------------------

  String? _dateTimeError;
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
      _selectedDateTime = ev.eventDate.toLocal();
      // --- ADDED: Initialize End Time ---
      if (ev.eventEnd != null) {
        _endDateTime = ev.eventEnd!.toLocal();
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
    if (date != null && mounted) {
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
    if (time != null && mounted) {
      setState(() {
        final now = DateTime.now();
        final date = _selectedDateTime ?? now;
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        _dateTimeError = null;
      });
    }
  }

  // --- ADDED: End Date Picker ---
  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    // Default to start date if end date is null
    final initial = _endDateTime ?? _selectedDateTime ?? now;
    
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _selectedDateTime ?? now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      setState(() {
        final time = _endDateTime != null ? TimeOfDay.fromDateTime(_endDateTime!) : const TimeOfDay(hour: 12, minute: 0);
        _endDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      });
    }
  }

  // --- ADDED: End Time Picker ---
  Future<void> _pickEndTime() async {
    final initial = _endDateTime != null 
        ? TimeOfDay.fromDateTime(_endDateTime!) 
        : const TimeOfDay(hour: 12, minute: 0);
        
    final time = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    
    if (time != null && mounted) {
      setState(() {
        final baseDate = _endDateTime ?? _selectedDateTime ?? DateTime.now();
        _endDateTime = DateTime(baseDate.year, baseDate.month, baseDate.day, time.hour, time.minute);
      });
    }
  }

  Future<String?> _handleImageUpload() async {
    if (_imageRemoved && _localImageFile == null) {
      return null;
    } else if (_localImageFile != null) {
      final logicalId = widget.existing?.id ?? 'new';
      
      return await _photoService.uploadEventPhoto(
        file: _localImageFile!,
        keyPrefix: 'group_events',
        logicalId: logicalId,
      );
    }
    return _imageUrl;
  }

  Future<void> _validateAndSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedDateTime == null) {
      setState(() => _dateTimeError = "key_042".tr());
      return;
    }

    // --- ADDED: Validation ---
    if (_endDateTime != null && _endDateTime!.isBefore(_selectedDateTime!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("End time cannot be before start time")),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final finalImageUrl = await _handleImageUpload();
      final groupId = widget.existing?.groupId ?? widget.groupId ?? '';
      
      final groupEvent = GroupEvent(
        id: widget.existing?.id ?? '',
        groupId: groupId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        eventDate: _selectedDateTime!.toUtc(),
        // --- ADDED: Save End Time ---
        eventEnd: _endDateTime?.toUtc(),
        location: _locationController.text.trim(),
        imageUrl: finalImageUrl,
      );
      
      await _service.saveEvent(groupEvent);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_043".tr())),
        );
      }
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
                const SizedBox(height: 12),
                
                // START TIME ROW
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

                // --- ADDED: END TIME ROW ---
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft, 
                  child: Text("End Time (Optional)", style: Theme.of(context).textTheme.bodyMedium)
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickEndDate,
                        child: Text(
                          _endDateTime == null
                              ? "Select Date"
                              : DateFormat.yMMMd().format(_endDateTime!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickEndTime,
                        child: Text(
                          _endDateTime == null
                              ? "Select Time"
                              : TimeOfDay.fromDateTime(_endDateTime!).format(context),
                        ),
                      ),
                    ),
                     if (_endDateTime != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _endDateTime = null),
                      )
                  ],
                ),
                // ---------------------------
                
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