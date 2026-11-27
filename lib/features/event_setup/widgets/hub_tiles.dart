// File: lib/features/event_setup/widgets/hub_tiles.dart
//
// Compact cards for the Event Setup page: approved events and announcements.
import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/event_setup_models.dart';

/// Small rounded label, e.g. "On calendar" or "Scheduled".
class HubChip extends StatelessWidget {
  const HubChip({super.key, required this.icon, required this.label, this.emphasized = false});

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = emphasized ? colorScheme.tertiaryContainer : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final fg = emphasized ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// An event that has all three sign-offs.
class ApprovedEventTile extends StatelessWidget {
  const ApprovedEventTile({super.key, required this.request});

  final EventSetupRequest request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toLanguageTag();
    final when =
        '${DateFormat.MMMEd(locale).format(request.start)} · '
        '${DateFormat.jm(locale).format(request.start)} – ${DateFormat.jm(locale).format(request.end)}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateBadge(date: request.start),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.title, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${request.groupName ?? 'event_setup_ministry_none'.tr()} · ${request.customLocation ?? request.room.labelKey.tr()}',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  Text(when, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      HubChip(
                        icon: request.addToCalendar ? Icons.event_available_outlined : Icons.event_busy_outlined,
                        label: (request.addToCalendar ? 'event_setup_chip_on_calendar' : 'event_setup_chip_not_on_calendar').tr(),
                      ),
                      if (request.announceLead != null)
                        HubChip(icon: Icons.campaign_outlined, label: 'event_setup_chip_announced'.tr()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({super.key, required this.announcement, this.onDelete});

  final HubAnnouncement announcement;

  /// Null hides the delete button.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toLanguageTag();
    final a = announcement;
    final when = DateFormat.MMMEd(locale).add_jm().format(a.publishAt);
    final body = a.body?.trim() ?? '';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((a.imageUrl ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: a.imageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Icon(Icons.campaign_outlined, color: colorScheme.primary, size: 22),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.campaign_outlined, color: colorScheme.primary, size: 22),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    a.groupName ?? 'event_setup_ministry_none'.tr(),
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      a.isScheduled
                          ? HubChip(
                              icon: Icons.schedule_outlined,
                              label: 'event_setup_chip_scheduled'.tr(namedArgs: {'date': when}),
                              emphasized: true,
                            )
                          : HubChip(
                              icon: Icons.check_circle_outline,
                              label: 'event_setup_chip_posted'.tr(namedArgs: {'date': when}),
                            ),
                      if (a.isFromEvent) HubChip(icon: Icons.event_outlined, label: 'event_setup_chip_from_event'.tr()),
                    ],
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'event_setup_delete_announcement'.tr(),
                icon: Icon(Icons.delete_outline, color: colorScheme.onSurfaceVariant),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = context.locale.toLanguageTag();
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(
            DateFormat.MMM(locale).format(date).toUpperCase(),
            style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          Text(
            DateFormat.d(locale).format(date),
            style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// One of your own submitted events, with its status and an Edit button.
class MySubmissionTile extends StatelessWidget {
  const MySubmissionTile({super.key, required this.request, required this.onEdit});

  final EventSetupRequest request;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toLanguageTag();
    final r = request;
    final when =
        '${DateFormat.MMMEd(locale).format(r.start)} · '
        '${DateFormat.jm(locale).format(r.start)} – ${DateFormat.jm(locale).format(r.end)}';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBadge(date: r.start),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${r.groupName ?? 'event_setup_ministry_none'.tr()} · ${r.customLocation ?? r.room.labelKey.tr()}',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    Text(when, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    HubChip(
                      emphasized: r.isApproved,
                      icon: r.isApproved ? Icons.verified_outlined : Icons.hourglass_top_rounded,
                      label: r.isApproved
                          ? 'event_setup_status_approved'.tr()
                          : 'event_setup_status_waiting'.tr(namedArgs: {'count': '${r.approvedCount}'}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onEdit,
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text('event_setup_edit'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Maria edited Youth Night: date, room" (sent to Cleaning, Security, owners).
class EditNoticeTile extends StatelessWidget {
  const EditNoticeTile({super.key, required this.notice, required this.onDismiss});

  final EventSetupNotification notice;
  final VoidCallback onDismiss;

  static const _fieldKeys = {
    'title': 'event_setup_change_title',
    'description': 'event_setup_change_description',
    'room': 'event_setup_change_room',
    'event_date': 'event_setup_change_start',
    'event_end': 'event_setup_change_end',
    'estimated_attendance': 'event_setup_change_attendance',
    'notes': 'event_setup_change_notes',
    'target_audiences': 'event_setup_change_audience',
    'image_url': 'event_setup_change_image',
    'rsvp_enabled': 'event_setup_change_rsvp',
    'signup_slots': 'event_setup_change_slots',
    'attachments': 'event_setup_change_files',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toLanguageTag();
    final n = notice;
    final changed = n.changes.map((c) => (_fieldKeys[c] ?? c).tr()).join(', ');
    final who = n.actorName?.trim().isNotEmpty == true ? n.actorName!.trim() : 'event_setup_someone'.tr();

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.edit_calendar_outlined, color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'event_setup_notice_edited'.tr(namedArgs: {'who': who, 'title': n.title}),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  if (changed.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'event_setup_notice_changed'.tr(namedArgs: {'fields': changed}),
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSecondaryContainer),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    DateFormat.MMMEd(locale).add_jm().format(n.createdAt),
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'event_setup_dismiss'.tr(),
              icon: Icon(Icons.close_rounded, color: colorScheme.onSecondaryContainer),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
