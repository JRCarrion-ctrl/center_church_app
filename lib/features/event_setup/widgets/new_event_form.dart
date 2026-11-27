// File: lib/features/event_setup/widgets/new_event_form.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';
import '../../../core/media/image_picker_field.dart';
import '../../../shared/user_roles.dart';
import '../event_setup_service.dart';
import '../models/event_setup_models.dart';
import 'extras_fields.dart';
import 'form_fields.dart';
import 'setup_card.dart';

/// Full-screen form to submit an event for the 3-department sign-off, or,
/// with [existing], to edit one already submitted. Edits keep the sign-offs
/// (no re-approval) and notify Cleaning, Security and owners.
/// Pops with `true` once saved.
class NewEventPage extends StatefulWidget {
  const NewEventPage({super.key, required this.service, this.existing});

  final EventSetupService service;
  final EventSetupRequest? existing;

  @override
  State<NewEventPage> createState() => _NewEventPageState();
}

class _NewEventPageState extends State<NewEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _attendanceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageExt;
  String? _imageUrl;
  bool _rsvp = true;
  final List<SlotDraft> _slots = [];
  List<SetupAttachment> _files = [];
  bool _filesUploading = false;

  MinistryChoices? _choices;
  String? _groupId;
  SetupRoom? _room;
  TargetAudience _audience = TargetAudience.both;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _addToCalendar = true;
  bool _announce = true;
  AnnounceLead _lead = AnnounceLead.oneWeek;
  String? _scheduleError;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  /// Once approved, sign-ups and files are managed on the calendar event.
  bool get _extrasLocked => _isEdit && widget.existing!.isApproved;

  bool get _hasCalendarEntry => _isEdit ? widget.existing!.addToCalendar : _addToCalendar;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _descriptionCtrl.text = e.description ?? '';
      _attendanceCtrl.text = e.estimatedAttendance?.toString() ?? '';
      _notesCtrl.text = e.notes ?? '';
      _groupId = e.groupId;
      _room = e.room;
      final langs = e.targetAudiences.toSet();
      _audience = langs.length == 1
          ? (langs.contains('spanish') ? TargetAudience.spanish : TargetAudience.english)
          : TargetAudience.both;
      _date = DateTime(e.start.year, e.start.month, e.start.day);
      _start = TimeOfDay.fromDateTime(e.start);
      _end = TimeOfDay.fromDateTime(e.end);
      _addToCalendar = e.addToCalendar;
      _locationCtrl.text = e.locationOther ?? '';
      _imageUrl = e.imageUrl;
      _rsvp = e.rsvpEnabled;
      _slots.addAll(e.signupSlots.map((x) => SlotDraft(title: x.title, maxSlots: x.maxSlots)));
      _files = List.of(e.attachments);
      _announce = e.announceLead != null;
      _lead = e.announceLead ?? AnnounceLead.oneWeek;
    } else {
      _loadMinistries();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _attendanceCtrl.dispose();
    _notesCtrl.dispose();
    _locationCtrl.dispose();
    for (final d in _slots) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMinistries() async {
    try {
      final choices = await MinistryChoices.load(context.read<AppState>(), widget.service, forAnnouncement: false);
      if (!mounted) return;
      setState(() {
        _choices = choices;
        // A leader of a single ministry has nothing to choose.
        if (!choices.allowChurchWide && choices.options.length == 1) _groupId = choices.options.first.id;
      });
    } catch (e) {
      debugPrint('EventSetup: failed to load ministries: $e');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_start ?? const TimeOfDay(hour: 18, minute: 0))
        : (_end ?? _start ?? const TimeOfDay(hour: 20, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  DateTime _combine(DateTime d, TimeOfDay t) => DateTime(d.year, d.month, d.day, t.hour, t.minute);

  /// Church-wide announcements are owner-only (also enforced server-side).
  bool get _canAnnounce => _groupId != null || context.read<AppState>().userRole == UserRole.owner;

  bool get _willAnnounce => _isEdit ? widget.existing!.announceLead != null : (_announce && _canAnnounce);

  DateTime? get _startDateTime => (_date == null || _start == null) ? null : _combine(_date!, _start!);

  String? _validateSchedule() {
    if (_date == null || _start == null || _end == null) return 'event_setup_error_schedule_required'.tr();
    final start = _combine(_date!, _start!);
    final end = _combine(_date!, _end!);
    if (!end.isAfter(start)) return 'event_setup_error_end_before_start'.tr();
    // When editing, only a changed start has to be in the future.
    final unchanged = _isEdit && start == widget.existing!.start;
    if (!unchanged && start.isBefore(DateTime.now())) return 'event_setup_error_in_past'.tr();
    return null;
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    final scheduleError = _validateSchedule();
    setState(() => _scheduleError = scheduleError);
    if (!formOk || scheduleError != null || _saving) return;

    if (_filesUploading) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('event_setup_wait_for_uploads'.tr())));
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      var imageUrl = _imageUrl;
      if (_imageBytes != null) {
        imageUrl = await widget.service.uploadImage(_imageBytes!, _imageExt);
      }
      final slots = _slots.map((d) => d.toSlot()).whereType<SetupSlot>().toList();
      final withCalendar = _hasCalendarEntry;

      if (_isEdit) {
        await widget.service.updateRequest(
          id: widget.existing!.id,
          title: _titleCtrl.text.trim(),
          room: _room!,
          start: _combine(_date!, _start!),
          end: _combine(_date!, _end!),
          estimatedAttendance: int.tryParse(_attendanceCtrl.text.trim()),
          notes: _notesCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          targetAudiences: _audience.dbValues,
          imageUrl: imageUrl,
          locationOther: _locationCtrl.text,
          rsvpEnabled: withCalendar && _rsvp,
          signupSlots: _extrasLocked ? null : (withCalendar ? slots : const []),
          attachments: _extrasLocked ? null : (withCalendar ? _files : const []),
        );
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('event_setup_edit_saved'.tr())));
        Navigator.of(context).pop(true);
        return;
      }
      await widget.service.submitRequest(
        title: _titleCtrl.text.trim(),
        groupId: _groupId,
        room: _room!,
        start: _combine(_date!, _start!),
        end: _combine(_date!, _end!),
        estimatedAttendance: int.tryParse(_attendanceCtrl.text.trim()),
        notes: _notesCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        addToCalendar: _addToCalendar,
        announceLead: _willAnnounce ? _lead : null,
        targetAudiences: _audience.dbValues,
        imageUrl: imageUrl,
        locationOther: _locationCtrl.text,
        rsvpEnabled: withCalendar && _rsvp,
        signupSlots: withCalendar ? slots : const [],
        attachments: withCalendar ? _files : const [],
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('event_setup_submitted'.tr())));
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('EventSetup: ${_isEdit ? 'edit' : 'submit'} failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text((_isEdit ? 'event_setup_edit_error' : 'event_setup_submit_error').tr())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = context.locale.toLanguageTag();

    return Scaffold(
      appBar: AppBar(title: Text((_isEdit ? 'event_setup_edit_event' : 'event_setup_new_event').tr())),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (_isEdit) ...[_EditNotice(request: widget.existing!), const SizedBox(height: 20)],
                  // --- DETAILS -------------------------------------------------
                  SetupCard(
                    label: 'event_setup_section_details'.tr(),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: setupInputDecoration(
                            context,
                            'event_setup_field_title'.tr(),
                            icon: Icons.event_note_outlined,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'event_setup_error_required'.tr() : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionCtrl,
                          minLines: 2,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: setupInputDecoration(
                            context,
                            'event_setup_field_description'.tr(),
                          ).copyWith(hintText: 'event_setup_field_description_hint'.tr(), alignLabelWithHint: true),
                          validator: (v) => (_willAnnounce && (v == null || v.trim().isEmpty))
                              ? 'event_setup_error_description_for_announcement'.tr()
                              : null,
                        ),
                        const SizedBox(height: 16),
                        ImagePickerField(
                          label: 'event_setup_field_image'.tr(),
                          initialUrl: _imageUrl,
                          onChanged: (bytes, ext, removed) => setState(() {
                            _imageBytes = bytes;
                            _imageExt = ext;
                            if (removed) _imageUrl = null;
                          }),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            'event_setup_field_image_hint'.tr(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isEdit)
                          // The ministry decides who sees it, so it's fixed once submitted.
                          TextFormField(
                            initialValue: widget.existing!.groupName ?? 'event_setup_ministry_none'.tr(),
                            enabled: false,
                            decoration: setupInputDecoration(
                              context,
                              'event_setup_field_ministry'.tr(),
                              icon: Icons.groups_outlined,
                            ),
                          )
                        else
                          MinistryField(
                            choices: _choices,
                            value: _groupId,
                            onChanged: (v) => setState(() => _groupId = v),
                          ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<SetupRoom>(
                          initialValue: _room,
                          isExpanded: true,
                          decoration: setupInputDecoration(
                            context,
                            'event_setup_field_room'.tr(),
                            icon: Icons.meeting_room_outlined,
                          ),
                          items: SetupRoom.values
                              .map((r) => DropdownMenuItem(value: r, child: Text(r.labelKey.tr())))
                              .toList(),
                          onChanged: (v) => setState(() => _room = v),
                          validator: (v) => v == null ? 'event_setup_error_required'.tr() : null,
                        ),
                        if (_room == SetupRoom.other) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _locationCtrl,
                            autofocus: !_isEdit,
                            textCapitalization: TextCapitalization.words,
                            decoration: setupInputDecoration(
                              context,
                              'event_setup_field_location_other'.tr(),
                              icon: Icons.place_outlined,
                            ).copyWith(hintText: 'event_setup_field_location_other_hint'.tr()),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'event_setup_error_required'.tr() : null,
                          ),
                        ],
                        const SizedBox(height: 16),
                        AudienceSelector(value: _audience, onChanged: (a) => setState(() => _audience = a)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- SCHEDULE ------------------------------------------------
                  SetupCard(
                    label: 'event_setup_section_schedule'.tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PickerRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'event_setup_field_date'.tr(),
                          value: _date == null ? null : DateFormat.yMMMEd(locale).format(_date!),
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: PickerRow(
                                icon: Icons.schedule_outlined,
                                label: 'event_setup_field_start'.tr(),
                                value: _start?.format(context),
                                onTap: () => _pickTime(isStart: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PickerRow(
                                icon: Icons.schedule_outlined,
                                label: 'event_setup_field_end'.tr(),
                                value: _end?.format(context),
                                onTap: () => _pickTime(isStart: false),
                              ),
                            ),
                          ],
                        ),
                        if (_scheduleError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10, left: 4),
                            child: Text(_scheduleError!, style: TextStyle(color: colorScheme.error, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- ANNOUNCE & CALENDAR (set when submitting) ---------------
                  if (!_isEdit) ...[
                    SetupCard(
                      label: 'event_setup_section_sharing'.tr(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(Icons.campaign_outlined, color: colorScheme.primary),
                            title: Text('event_setup_announce_toggle'.tr()),
                            subtitle: _canAnnounce ? null : Text('event_setup_announce_owner_only'.tr()),
                            value: _willAnnounce,
                            onChanged: _canAnnounce ? (v) => setState(() => _announce = v) : null,
                          ),
                          if (_willAnnounce) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final l in AnnounceLead.values)
                                  ChoiceChip(
                                    label: Text(l.labelKey.tr()),
                                    selected: _lead == l,
                                    onSelected: (_) => setState(() => _lead = l),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _AnnounceHint(lead: _lead, eventStart: _startDateTime),
                            const SizedBox(height: 8),
                          ],
                          Divider(height: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(Icons.event_outlined, color: colorScheme.primary),
                            title: Text('event_setup_calendar_toggle'.tr()),
                            subtitle: Text('event_setup_calendar_toggle_hint'.tr()),
                            value: _addToCalendar,
                            onChanged: (v) => setState(() => _addToCalendar = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- EVENT PAGE: RSVP, sign-ups, files -------------------------
                  if (_hasCalendarEntry) ...[
                    SetupCard(
                      label: 'event_setup_section_event_page'.tr(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(Icons.how_to_reg_outlined, color: colorScheme.primary),
                            title: Text('event_setup_rsvp_toggle'.tr()),
                            subtitle: Text('event_setup_rsvp_toggle_hint'.tr()),
                            value: _rsvp,
                            onChanged: (v) => setState(() => _rsvp = v),
                          ),
                          Divider(height: 24, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          if (_extrasLocked)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'event_setup_extras_on_event_page'.tr(),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            Text('event_setup_slots_title'.tr(), style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            SlotsEditor(
                              slots: _slots,
                              onAdd: () => setState(() => _slots.add(SlotDraft())),
                              onRemove: (i) {
                                final removed = _slots[i];
                                setState(() => _slots.removeAt(i));
                                // Its text fields are still mounted until this frame ends.
                                WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                              },
                            ),
                            Divider(height: 24, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                            Text('event_setup_files_title'.tr(), style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            AttachmentsEditor(
                              service: widget.service,
                              files: _files,
                              onChanged: (f) => setState(() => _files = f),
                              onBusyChanged: (b) => setState(() => _filesUploading = b),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- SETUP NEEDS ---------------------------------------------
                  SetupCard(
                    label: 'event_setup_section_setup'.tr(),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _attendanceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: setupInputDecoration(
                            context,
                            'event_setup_field_attendance'.tr(),
                            icon: Icons.people_outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesCtrl,
                          minLines: 4,
                          maxLines: 8,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: setupInputDecoration(
                            context,
                            'event_setup_field_notes'.tr(),
                          ).copyWith(hintText: 'event_setup_field_notes_hint'.tr(), alignLabelWithHint: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  SubmitButton(
                    label: (_isEdit ? 'event_setup_save_changes' : 'event_setup_submit').tr(),
                    icon: _isEdit ? Icons.check_rounded : Icons.send_outlined,
                    busy: _saving || _filesUploading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Top of the edit screen: what happens when you save.
class _EditNotice extends StatelessWidget {
  const _EditNotice({required this.request});

  final EventSetupRequest request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note_rounded, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              (request.isApproved ? 'event_setup_edit_notice_approved' : 'event_setup_edit_notice_pending').tr(),
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Posts Fri, Dec 5 · 7:00 PM, once all 3 departments approve."
class _AnnounceHint extends StatelessWidget {
  const _AnnounceHint({required this.lead, required this.eventStart});

  final AnnounceLead lead;
  final DateTime? eventStart;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = context.locale.toLanguageTag();
    final start = eventStart;

    final String text;
    if (lead == AnnounceLead.asap || start == null) {
      text = 'event_setup_announce_hint_on_approval'.tr();
    } else {
      final target = start.subtract(lead.lead);
      text = target.isAfter(DateTime.now())
          ? 'event_setup_announce_hint_scheduled'.tr(
              namedArgs: {'date': DateFormat.MMMEd(locale).add_jm().format(target)},
            )
          : 'event_setup_announce_hint_on_approval'.tr();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
