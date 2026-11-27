// File: lib/features/event_setup/widgets/extras_fields.dart
//
// Sign-up slots and files for the New / Edit Event form.
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';

import '../event_setup_service.dart';
import '../models/event_setup_models.dart';
import 'setup_card.dart';

/// One editable slot row. The parent owns (and disposes) the controllers.
class SlotDraft {
  SlotDraft({String title = '', int maxSlots = 1})
      : title = TextEditingController(text: title),
        max = TextEditingController(text: maxSlots.toString());

  final TextEditingController title;
  final TextEditingController max;

  SetupSlot? toSlot() {
    final t = title.text.trim();
    if (t.isEmpty) return null;
    final m = int.tryParse(max.text.trim()) ?? 1;
    return SetupSlot(title: t, maxSlots: m < 1 ? 1 : m);
  }

  void dispose() {
    title.dispose();
    max.dispose();
  }
}

/// "Bring a dessert · 10 spots" rows with add / remove.
class SlotsEditor extends StatelessWidget {
  const SlotsEditor({super.key, required this.slots, required this.onAdd, required this.onRemove});

  final List<SlotDraft> slots;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'event_setup_slots_hint'.tr(),
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < slots.length; i++)
          Padding(
            key: ObjectKey(slots[i]),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: slots[i].title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: setupInputDecoration(context, 'event_setup_slot_title'.tr()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'event_setup_error_required'.tr() : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: TextFormField(
                    controller: slots[i].max,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: setupInputDecoration(context, 'event_setup_slot_spots'.tr()),
                    validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) < 1 ? 'event_setup_error_min_one'.tr() : null,
                  ),
                ),
                IconButton(
                  padding: const EdgeInsets.only(top: 8),
                  tooltip: 'event_setup_slot_remove'.tr(),
                  icon: Icon(Icons.remove_circle_outline, color: colorScheme.error),
                  onPressed: () => onRemove(i),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text('event_setup_slot_add'.tr()),
        ),
      ],
    );
  }
}

/// Files list with an "Add file" button. Files upload as soon as they're
/// picked so submitting stays quick.
class AttachmentsEditor extends StatefulWidget {
  const AttachmentsEditor({
    super.key,
    required this.service,
    required this.files,
    required this.onChanged,
    this.onBusyChanged,
  });

  final EventSetupService service;
  final List<SetupAttachment> files;
  final ValueChanged<List<SetupAttachment>> onChanged;

  /// True while files are uploading, so the form can hold off on submitting.
  final ValueChanged<bool>? onBusyChanged;

  @override
  State<AttachmentsEditor> createState() => _AttachmentsEditorState();
}

class _AttachmentsEditorState extends State<AttachmentsEditor> {
  int _uploading = 0;

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(allowMultiple: true, withData: true);
    if (result == null || result.files.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      setState(() => _uploading++);
      widget.onBusyChanged?.call(true);
      try {
        final uploaded = await widget.service.uploadAttachment(bytes, f.name);
        widget.onChanged([...widget.files, uploaded]);
      } catch (e) {
        debugPrint('EventSetup: file upload failed: $e');
        messenger.showSnackBar(
          SnackBar(content: Text('event_setup_file_upload_error'.tr(namedArgs: {'name': f.name}))),
        );
      } finally {
        if (mounted) {
          setState(() => _uploading--);
          if (_uploading == 0) widget.onBusyChanged?.call(false);
        }
      }
    }
  }

  IconData _icon(SetupAttachment a) {
    final ct = a.contentType;
    if (ct.startsWith('image/')) return Icons.image_outlined;
    if (ct == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (ct.contains('sheet') || ct.contains('excel') || ct == 'text/csv') return Icons.table_chart_outlined;
    if (ct.contains('presentation') || ct.contains('powerpoint')) return Icons.slideshow_outlined;
    if (ct.contains('word')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _size(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'event_setup_files_hint'.tr(),
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < widget.files.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_icon(widget.files[i]), color: colorScheme.primary),
            title: Text(widget.files[i].fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: widget.files[i].fileSizeBytes == null ? null : Text(_size(widget.files[i].fileSizeBytes)),
            trailing: IconButton(
              tooltip: 'event_setup_file_remove'.tr(),
              icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
              onPressed: () => widget.onChanged([...widget.files]..removeAt(i)),
            ),
          ),
        if (_uploading > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('event_setup_file_uploading'.tr(), style: textTheme.bodyMedium),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.attach_file),
          label: Text('event_setup_file_add'.tr()),
        ),
      ],
    );
  }
}
