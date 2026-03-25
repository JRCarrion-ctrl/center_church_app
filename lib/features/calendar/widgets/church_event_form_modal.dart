// File: lib/features/calendar/widgets/church_event_form_modal.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/church_event.dart';
import '../church_event_service.dart';
import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/media/image_picker_field.dart';
import '../event_photo_storage_service.dart';

class _SlotEditor {
  final String? id;
  final TextEditingController controller;
  int maxSlots;

  _SlotEditor({this.id, required String title, required this.maxSlots})
      : controller = TextEditingController(text: title);

  void dispose() => controller.dispose();
}

class ChurchEventFormModal extends StatefulWidget {
  final ChurchEvent? existing;
  /// If provided, this acts as a Group Event form. If null, it acts as a Main App Event form.
  final String? prefilledGroupId; 
  
  const ChurchEventFormModal({super.key, this.existing, this.prefilledGroupId});

  @override
  State<ChurchEventFormModal> createState() => _ChurchEventFormModalState();
}

class _ChurchEventFormModalState extends State<ChurchEventFormModal> {
  final _formKey = GlobalKey<FormState>();
  late ChurchEventService _service;
  late EventPhotoStorageService _photoService;
  bool _svcReady = false;

  Uint8List? _imageBytes;
  String?    _imageExtension;
  bool       _imageRemoved = false;
  String?    _imageUrl;

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  final List<_SlotEditor> _slots = [];

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime?  _endDate;
  TimeOfDay? _endTime;
  bool _saving = false;

  List<String> _selectedAudiences = ['english', 'spanish'];
  bool _isRecurring = false;
  DateTime? _recurUntil;

  // ✨ THE MAGIC TOGGLE: Request Public Feature
  bool _requestPublicFeature = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.existing;
    _titleController    = TextEditingController(text: ev?.title ?? '');
    _descController     = TextEditingController(text: ev?.description ?? '');
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
      
      if (ev.targetAudiences.isNotEmpty) {
        _selectedAudiences = List.from(ev.targetAudiences);
      }

      if (ev.rrule != null && ev.rrule!.startsWith('FREQ=DAILY')) {
        _isRecurring = true;
        final match = RegExp(r'UNTIL=(\d{8})').firstMatch(ev.rrule!);
        if (match != null) {
          final dateStr = match.group(1)!;
          _recurUntil = DateTime.parse('${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}').toLocal();
        }
      }

      // If they are editing an event that was already promoted (or requested to be), keep the toggle ON
      if (ev.groupId != null && ev.visibility == 'public_app') {
        _requestPublicFeature = true;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_svcReady) {
      final client = GraphQLProvider.of(context).value;
      final userId = context.read<AppState>().profile?.id;
      _service      = ChurchEventService(client, currentUserId: userId);
      _photoService = EventPhotoStorageService(client);
      _svcReady = true;
      if (widget.existing != null) _loadSlots(widget.existing!.id);
    }
  }

  Future<void> _loadSlots(String eventId) async {
    try {
      final slots = await _service.fetchEventSlots(eventId);
      if (!mounted) return;
      setState(() {
        for (var s in slots) {
          _slots.add(_SlotEditor(id: s.id, title: s.title, maxSlots: s.maxSlots));
        }
      });
    } catch (e) {
      debugPrint('Error loading existing slots: $e');
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

  void _addSlot()         => setState(() => _slots.add(_SlotEditor(title: '', maxSlots: 1)));
  void _removeSlot(int i) => setState(() { _slots[i].dispose(); _slots.removeAt(i); });

  // [Keep your existing _pickDate, _pickTime, _pickEndDate, _pickEndTime methods here exactly as they were in the previous files]
  Future<void> _pickDate() async {
    final now  = DateTime.now();
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
    final now  = DateTime.now();
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
    final effectiveGroupId = widget.existing?.groupId ?? widget.prefilledGroupId;
    final isGroupEvent = effectiveGroupId != null;

    if (isGroupEvent && _requestPublicFeature && _selectedAudiences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one target audience for public events.')));
      return;
    }

    if (!_svcReady || !_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_040".tr())));
      return;
    }

    if (_isRecurring && _recurUntil == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an End Date for the repeating event.')));
      return;
    }

    setState(() => _saving = true);

    try {
      String? finalImageUrl = _imageUrl;
      if (_imageRemoved) finalImageUrl = null;
      if (_imageBytes != null) {
        finalImageUrl = await _photoService.uploadEventPhoto(
          bytes: _imageBytes!,
          extension: _imageExtension,
          keyPrefix: 'unified_events',
          logicalId: widget.existing?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      final dt = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );
      final finalEndDt = (_endDate != null && _endTime != null)
          ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime!.hour, _endTime!.minute)
          : null;

      final slots = _slots
          .map((s) => ChurchEventSlot(id: s.id, title: s.controller.text.trim(), maxSlots: s.maxSlots))
          .where((s) => s.title.isNotEmpty)
          .toList();

      String? finalRrule;
      if (_isRecurring && _recurUntil != null) {
        final dateStr = DateFormat('yyyyMMdd').format(_recurUntil!);
        finalRrule = 'FREQ=DAILY;UNTIL=$dateStr';
      }

      // ✨ THE STATE MACHINE LOGIC ✨
      // If it has no group ID, it's an app event (public). 
      // If it has a group ID, check if they requested a public feature.
      final String finalVisibility = (isGroupEvent && !_requestPublicFeature) ? 'group_only' : 'public_app';

      final event = ChurchEvent(
        id: widget.existing?.id ?? '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        eventDate: dt.toUtc(),
        eventEnd: finalEndDt?.toUtc(),
        imageUrl: finalImageUrl,
        location: _locationController.text.trim(),
        targetAudiences: _selectedAudiences,
        rrule: finalRrule,
        groupId: effectiveGroupId,
        visibility: finalVisibility, 
        // Note: We omit 'status'. The Hasura Column Preset will force 'pending_approval' for leaders, 
        // and allow the 'owner' role to save it as 'approved'.
      );

      await _service.saveEvent(event, slots: slots);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Save Error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_041".tr())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _sleekInputDecoration(BuildContext context, String label, {IconData? icon}) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: colorScheme.primary) : null,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Determine the context of the form
    final effectiveGroupId = widget.existing?.groupId ?? widget.prefilledGroupId;
    final isGroupEvent = effectiveGroupId != null;
    final showAudiences = !isGroupEvent || _requestPublicFeature;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          widget.existing == null ? "New Event" : "Edit Event",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Event Details ---
              TextFormField(
                controller: _titleController,
                decoration: _sleekInputDecoration(context, "Event Title", icon: Icons.title),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descController,
                decoration: _sleekInputDecoration(context, "Description", icon: Icons.subject),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // ✨ NEW: The Promotion Toggle for Group Leaders
              if (isGroupEvent) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _requestPublicFeature ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _requestPublicFeature ? colorScheme.primary : Colors.transparent, 
                      width: 2
                    )
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'Feature on Main Calendar', 
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _requestPublicFeature ? colorScheme.onPrimaryContainer : colorScheme.onSurface
                      )
                    ),
                    subtitle: Text(
                      'Submit this event for admin approval to be shown to the entire church.',
                      style: TextStyle(color: _requestPublicFeature ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8) : colorScheme.outline)
                    ),
                    value: _requestPublicFeature,
                    activeThumbColor: colorScheme.primary,
                    onChanged: (val) => setState(() => _requestPublicFeature = val),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // --- Target Audience (Animated Visibility) ---
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: !showAudiences ? const SizedBox.shrink() : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people_alt_outlined, color: colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text("Target Audience".tr(), style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: ['english', 'spanish'].map((lang) {
                              final isSelected = _selectedAudiences.contains(lang);
                              return FilterChip(
                                label: Text(lang == 'english' ? 'TCCF' : 'Centro'),
                                selected: isSelected,
                                showCheckmark: false,
                                selectedColor: colorScheme.primaryContainer,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant),
                                onSelected: (bool selected) {
                                  setState(() {
                                    selected ? _selectedAudiences.add(lang) : _selectedAudiences.remove(lang);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // --- Location & Image ---
              TextFormField(
                controller: _locationController,
                decoration: _sleekInputDecoration(context, "Location", icon: Icons.location_on_outlined),
              ),
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ImagePickerField(
                    label: "Add Event Image",
                    initialUrl: _imageUrl,
                    onChanged: (bytes, ext, removed) {
                      setState(() {
                        _imageBytes = bytes;
                        _imageExtension = ext;
                        _imageRemoved = removed;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // --- Schedule ---
              Text('Schedule', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(_selectedDate == null ? "Select Date" : DateFormat.yMMMd().format(_selectedDate!), style: textTheme.bodyLarge),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _pickTime,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(_selectedTime == null ? "Select Time" : _selectedTime!.format(context), style: textTheme.bodyLarge, textAlign: TextAlign.right),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1)),
                    Row(
                      children: [
                        Icon(Icons.stop_circle_outlined, color: colorScheme.outline),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _pickEndDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(_endDate == null ? 'End Date' : DateFormat.yMMMd().format(_endDate!), style: textTheme.bodyLarge?.copyWith(color: _endDate == null ? colorScheme.outline : colorScheme.onSurface)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _pickEndTime,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(_endTime == null ? 'End Time' : _endTime!.format(context), style: textTheme.bodyLarge?.copyWith(color: _endTime == null ? colorScheme.outline : colorScheme.onSurface), textAlign: TextAlign.right),
                            ),
                          ),
                        ),
                        if (_endDate != null)
                          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.clear, size: 20), onPressed: () => setState(() { _endDate = null; _endTime = null; })),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Repeat Daily', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text('Create block events at the same time each day', style: textTheme.bodySmall),
                      value: _isRecurring,
                      activeThumbColor: colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          _isRecurring = val;
                          if (val && _recurUntil == null && _selectedDate != null) _recurUntil = _selectedDate!.add(const Duration(days: 1));
                        });
                      },
                    ),
                    if (_isRecurring)
                      Row(
                        children: [
                          Icon(Icons.event_repeat, color: colorScheme.outline),
                          const SizedBox(width: 12),
                          Text('Until: ', style: textTheme.bodyLarge),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _recurUntil ?? _selectedDate ?? DateTime.now(),
                                  firstDate: _selectedDate ?? DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (date != null && mounted) setState(() => _recurUntil = date);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(_recurUntil == null ? 'Select Date' : DateFormat.yMMMd().format(_recurUntil!), style: textTheme.bodyLarge?.copyWith(color: _recurUntil == null ? colorScheme.outline : colorScheme.primary, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- Sign-Up Slots ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sign-up Slots', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Items or tasks needed', style: textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                    ],
                  ),
                  IconButton.filledTonal(onPressed: _addSlot, icon: const Icon(Icons.add), tooltip: 'Add Slot'),
                ],
              ),
              const SizedBox(height: 16),
              if (_slots.isEmpty)
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: colorScheme.outlineVariant)),
                  child: Text('No sign-up slots added.', textAlign: TextAlign.center, style: TextStyle(color: colorScheme.outline)),
                ),
              ...List.generate(_slots.length, (index) {
                final slot = _slots[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: TextFormField(controller: slot.controller, decoration: _sleekInputDecoration(context, 'Item name').copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<int>(
                          initialValue: slot.maxSlots,
                          decoration: _sleekInputDecoration(context, 'Qty').copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                          items: List.generate(20, (i) => i + 1).map((i) => DropdownMenuItem(value: i, child: Text('$i'))).toList(),
                          onChanged: (val) => setState(() => slot.maxSlots = val!),
                        ),
                      ),
                      IconButton(icon: Icon(Icons.remove_circle, color: colorScheme.error), onPressed: () => _removeSlot(index)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 48),

              // --- Save Button ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Save Event", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Add this to the bottom of church_event_form_modal.dart
class ChurchEventFormWrapper extends StatefulWidget {
  final String? eventId;
  final String? prefilledGroupId;

  const ChurchEventFormWrapper({super.key, this.eventId, this.prefilledGroupId});

  @override
  State<ChurchEventFormWrapper> createState() => _ChurchEventFormWrapperState();
}

class _ChurchEventFormWrapperState extends State<ChurchEventFormWrapper> {
  Future<ChurchEvent?>? _eventFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.eventId != null && _eventFuture == null) {
      final client = GraphQLProvider.of(context).value;
      final userId = context.read<AppState>().profile?.id;
      final service = ChurchEventService(client, currentUserId: userId);
      _eventFuture = service.getEventById(widget.eventId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.eventId == null) {
      // It's a new event, skip fetching
      return ChurchEventFormModal(prefilledGroupId: widget.prefilledGroupId);
    }

    return FutureBuilder<ChurchEvent?>(
      future: _eventFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: const Center(child: Text("Event not found or deleted.")),
          );
        }
        // Data fetched! Build the form securely.
        return ChurchEventFormModal(
          prefilledGroupId: widget.prefilledGroupId,
          existing: snapshot.data,
        );
      },
    );
  }
}