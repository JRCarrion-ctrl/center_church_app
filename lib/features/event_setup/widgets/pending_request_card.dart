// File: lib/features/event_setup/widgets/pending_request_card.dart
import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/event_setup_models.dart';

typedef SignoffToggle = Future<void> Function(EventSetupRequest request, SetupDepartment dept, bool approve);

class PendingRequestCard extends StatelessWidget {
  const PendingRequestCard({
    super.key,
    required this.request,
    required this.canApprove,
    required this.isBusy,
    required this.onToggle,
  });

  final EventSetupRequest request;

  /// Whether the current user may toggle [dept] for this request's ministry.
  final bool Function(SetupDepartment dept) canApprove;
  final bool Function(SetupDepartment dept) isBusy;
  final SignoffToggle onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toLanguageTag();
    final dateLine =
        '${DateFormat.yMMMEd(locale).format(request.start)} · '
        '${DateFormat.jm(locale).format(request.start)} – ${DateFormat.jm(locale).format(request.end)}';
    final notes = request.notes?.trim() ?? '';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        request.groupName ?? 'event_setup_ministry_none'.tr(),
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusBadge(request: request),
              ],
            ),
            const SizedBox(height: 16),

            if ((request.imageUrl ?? '').isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: request.imageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // --- Facts ---
            _InfoLine(icon: Icons.calendar_today_outlined, text: dateLine),
            _InfoLine(
              icon: request.hasCustomLocation ? Icons.place_outlined : Icons.meeting_room_outlined,
              text: request.customLocation ?? request.room.labelKey.tr(),
            ),
            if (request.addToCalendar && request.rsvpEnabled)
              _InfoLine(icon: Icons.how_to_reg_outlined, text: 'event_setup_card_rsvp'.tr()),
            if (request.signupSlots.isNotEmpty)
              _InfoLine(
                icon: Icons.checklist_rounded,
                text: 'event_setup_card_slots'.tr(namedArgs: {
                  'slots': request.signupSlots.map((s) => '${s.title} (${s.maxSlots})').join(', '),
                }),
              ),
            if (request.attachments.isNotEmpty)
              _InfoLine(
                icon: Icons.attach_file,
                text: 'event_setup_card_files'.tr(namedArgs: {'count': '${request.attachments.length}'}),
              ),
            if (request.estimatedAttendance != null)
              _InfoLine(
                icon: Icons.people_outline,
                text: 'event_setup_attendance_value'.tr(namedArgs: {'count': '${request.estimatedAttendance}'}),
              ),
            if (request.creatorName != null)
              _InfoLine(
                icon: Icons.person_outline,
                text: 'event_setup_submitted_by'.tr(namedArgs: {'name': request.creatorName!}),
              ),
            _InfoLine(
              icon: Icons.campaign_outlined,
              text: request.announceLead == null
                  ? 'event_setup_card_no_announcement'.tr()
                  : 'event_setup_card_announce'.tr(namedArgs: {'when': request.announceLead!.labelKey.tr()}),
            ),
            _InfoLine(
              icon: request.addToCalendar ? Icons.event_available_outlined : Icons.event_busy_outlined,
              text: (request.addToCalendar ? 'event_setup_card_calendar_yes' : 'event_setup_card_calendar_no').tr(),
            ),
            _InfoLine(
              icon: Icons.visibility_outlined,
              text: request.groupName == null
                  ? 'event_setup_visibility_everyone'.tr()
                  : 'event_setup_visibility_ministry'.tr(namedArgs: {'ministry': request.groupName!}),
            ),

            // --- Notes & Equipment ---
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'event_setup_field_notes'.tr(),
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notes.isEmpty ? 'event_setup_notes_empty'.tr() : notes,
                    style: textTheme.bodyMedium?.copyWith(
                      color: notes.isEmpty ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // --- Department sign-offs ---
            const SizedBox(height: 16),
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            for (final dept in SetupDepartment.values)
              _SignoffRow(
                dept: dept,
                signoff: request.signoffFor(dept),
                editable: !request.isApproved && canApprove(dept),
                busy: isBusy(dept),
                onChanged: (v) => onToggle(request, dept, v),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.request});

  final EventSetupRequest request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final approved = request.isApproved;
    final bg = approved ? colorScheme.primaryContainer : colorScheme.tertiaryContainer;
    final fg = approved ? colorScheme.onPrimaryContainer : colorScheme.onTertiaryContainer;
    final label = approved
        ? 'event_setup_status_approved'.tr()
        : 'event_setup_status_pending'.tr(namedArgs: {'count': '${request.approvedCount}'});

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _SignoffRow extends StatelessWidget {
  const _SignoffRow({
    required this.dept,
    required this.signoff,
    required this.editable,
    required this.busy,
    required this.onChanged,
  });

  final SetupDepartment dept;
  final EventSetupSignoff? signoff;
  final bool editable;
  final bool busy;
  final ValueChanged<bool> onChanged;

  IconData get _icon => switch (dept) {
    SetupDepartment.administrator => Icons.campaign_outlined,
    SetupDepartment.security => Icons.shield_outlined,
    SetupDepartment.cleaning => Icons.cleaning_services_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toLanguageTag();
    final approved = signoff != null;

    final statusText = approved
        ? 'event_setup_signed_by'.tr(
            namedArgs: {
              'name': signoff!.approverName ?? 'event_setup_unknown_user'.tr(),
              'date': DateFormat.MMMd(locale).add_jm().format(signoff!.approvedAt),
            },
          )
        : 'event_setup_signoff_pending'.tr();

    final Widget trailing;
    if (busy) {
      trailing = const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (editable) {
      trailing = Switch(value: approved, onChanged: onChanged);
    } else {
      // Read-only state for departments the user can't approve.
      trailing = Icon(
        approved ? Icons.check_circle : Icons.radio_button_unchecked,
        color: approved ? colorScheme.primary : colorScheme.onSurfaceVariant,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_icon, size: 22, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dept.labelKey.tr(), style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  dept.descriptionKey.tr(),
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: textTheme.labelSmall?.copyWith(
                    color: approved ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 56, child: Center(child: trailing)),
        ],
      ),
    );
  }
}
