// File: lib/features/event_setup/widgets/new_announcement_form.dart
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';
import '../../../core/media/image_picker_field.dart';
import '../event_setup_service.dart';
import 'form_fields.dart';
import 'setup_card.dart';

/// Full-screen form for a standalone announcement (no event, no sign-off).
/// It goes to the chosen ministry's members, or church-wide, at the chosen
/// time. Pops with `true` once saved.
class NewAnnouncementPage extends StatefulWidget {
  const NewAnnouncementPage({super.key, required this.service});

  final EventSetupService service;

  @override
  State<NewAnnouncementPage> createState() => _NewAnnouncementPageState();
}

class _NewAnnouncementPageState extends State<NewAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  MinistryChoices? _choices;
  String? _groupId;
  TargetAudience _audience = TargetAudience.both;
  bool _postNow = true;
  DateTime? _date;
  TimeOfDay? _time;
  String? _scheduleError;
  bool _saving = false;
  Uint8List? _imageBytes;
  String? _imageExt;

  @override
  void initState() {
    super.initState();
    _loadMinistries();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMinistries() async {
    try {
      final choices = await MinistryChoices.load(context.read<AppState>(), widget.service, forAnnouncement: true);
      if (!mounted) return;
      setState(() {
        _choices = choices;
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0));
    if (picked != null) setState(() => _time = picked);
  }

  DateTime? get _scheduledAt =>
      (_date == null || _time == null) ? null : DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);

  String? _validateSchedule() {
    if (_postNow) return null;
    final at = _scheduledAt;
    if (at == null) return 'event_setup_error_post_time_required'.tr();
    if (at.isBefore(DateTime.now())) return 'event_setup_error_post_time_past'.tr();
    return null;
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    final scheduleError = _validateSchedule();
    setState(() => _scheduleError = scheduleError);
    if (!formOk || scheduleError != null || _saving) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final imageUrl = _imageBytes == null ? null : await widget.service.uploadImage(_imageBytes!, _imageExt);
      await widget.service.createAnnouncement(
        imageUrl: imageUrl,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        groupId: _groupId,
        targetAudiences: _audience.dbValues,
        publishAt: _postNow ? DateTime.now() : _scheduledAt!,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text((_postNow ? 'event_setup_announcement_posted' : 'event_setup_announcement_scheduled').tr())),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('EventSetup: announcement failed: $e');
      messenger.showSnackBar(SnackBar(content: Text('event_setup_announcement_error'.tr())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = context.locale.toLanguageTag();

    return Scaffold(
      appBar: AppBar(title: Text('event_setup_new_announcement'.tr())),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SetupCard(
                    label: 'event_setup_section_details'.tr(),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: setupInputDecoration(
                            context,
                            'event_setup_field_announcement_title'.tr(),
                            icon: Icons.campaign_outlined,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'event_setup_error_required'.tr() : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _bodyCtrl,
                          minLines: 4,
                          maxLines: 10,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: setupInputDecoration(
                            context,
                            'event_setup_field_message'.tr(),
                          ).copyWith(alignLabelWithHint: true),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'event_setup_error_required'.tr() : null,
                        ),
                        const SizedBox(height: 16),
                        ImagePickerField(
                          label: 'event_setup_field_announcement_image'.tr(),
                          onChanged: (bytes, ext, _) => setState(() {
                            _imageBytes = bytes;
                            _imageExt = ext;
                          }),
                        ),
                        const SizedBox(height: 16),
                        MinistryField(
                          choices: _choices,
                          value: _groupId,
                          onChanged: (v) => setState(() => _groupId = v),
                        ),
                        const SizedBox(height: 16),
                        AudienceSelector(value: _audience, onChanged: (a) => setState(() => _audience = a)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SetupCard(
                    label: 'event_setup_section_when'.tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(value: true, label: Text('event_setup_post_now'.tr())),
                              ButtonSegment(value: false, label: Text('event_setup_post_schedule'.tr())),
                            ],
                            selected: {_postNow},
                            onSelectionChanged: (s) => setState(() => _postNow = s.first),
                          ),
                        ),
                        if (!_postNow) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: PickerRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'event_setup_field_date'.tr(),
                                  value: _date == null ? null : DateFormat.yMMMEd(locale).format(_date!),
                                  onTap: _pickDate,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: PickerRow(
                                  icon: Icons.schedule_outlined,
                                  label: 'event_setup_field_time'.tr(),
                                  value: _time?.format(context),
                                  onTap: _pickTime,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_scheduleError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10, left: 4),
                            child: Text(_scheduleError!, style: TextStyle(color: colorScheme.error, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SubmitButton(
                    label: (_postNow ? 'event_setup_post_now' : 'event_setup_post_schedule').tr(),
                    icon: Icons.send_outlined,
                    busy: _saving,
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
