// File: lib/features/event_setup/widgets/form_fields.dart
//
// Fields shared by the New Event and New Announcement forms.
import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';
import '../../../shared/user_roles.dart';
import '../event_setup_access.dart';
import '../event_setup_service.dart';
import '../models/event_setup_models.dart';
import 'setup_card.dart';

/// Which ministries the user may create for. Owners/supervisors get every
/// ministry; leaders only get ministries they lead. Church-wide events are for
/// owners/supervisors, but church-wide announcements are owner-only.
/// The server enforces the same rules.
class MinistryChoices {
  const MinistryChoices({required this.options, required this.allowChurchWide});

  final List<MinistryOption> options;
  final bool allowChurchWide;

  static Future<MinistryChoices> load(
    AppState appState,
    EventSetupService service, {
    required bool forAnnouncement,
  }) async {
    if (EventSetupAccess.isAdmin(appState.userRole)) {
      return MinistryChoices(
        options: await service.fetchMinistries(),
        allowChurchWide: forAnnouncement ? appState.userRole == UserRole.owner : true,
      );
    }
    return MinistryChoices(options: appState.ledMinistries, allowChurchWide: false);
  }

  String? nameFor(String? id) {
    for (final m in options) {
      if (m.id == id) return m.name;
    }
    return null;
  }
}

/// Ministry dropdown plus a line saying who will see the result.
class MinistryField extends StatelessWidget {
  const MinistryField({
    super.key,
    required this.choices,
    required this.value,
    required this.onChanged,
  });

  final MinistryChoices? choices;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = choices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          // Rebuild once the options arrive so initialValue is re-read.
          key: ValueKey(c),
          initialValue: value,
          isExpanded: true,
          decoration: setupInputDecoration(context, 'event_setup_field_ministry'.tr(), icon: Icons.groups_outlined),
          items: [
            if (c == null || c.allowChurchWide)
              DropdownMenuItem<String?>(value: null, child: Text('event_setup_ministry_none'.tr())),
            ...?c?.options.map(
              (m) => DropdownMenuItem<String?>(
                value: m.id,
                child: Text(m.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
          validator: (v) => (v == null && c != null && !c.allowChurchWide) ? 'event_setup_error_required'.tr() : null,
        ),
        VisibilityHint(ministryName: value == null ? null : c?.nameFor(value), churchWide: value == null),
      ],
    );
  }
}

/// "Only members of Worship, plus Admin, Security & Cleaning, will see this."
class VisibilityHint extends StatelessWidget {
  const VisibilityHint({super.key, required this.ministryName, required this.churchWide});

  final String? ministryName;
  final bool churchWide;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String text;
    if (churchWide) {
      text = 'event_setup_visibility_everyone'.tr();
    } else if (ministryName != null) {
      text = 'event_setup_visibility_ministry'.tr(namedArgs: {'ministry': ministryName!});
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

enum TargetAudience {
  both(['english', 'spanish'], 'event_setup_audience_both'),
  english(['english'], 'event_setup_audience_english'),
  spanish(['spanish'], 'event_setup_audience_spanish');

  const TargetAudience(this.dbValues, this.labelKey);

  final List<String> dbValues;
  final String labelKey;
}

class AudienceSelector extends StatelessWidget {
  const AudienceSelector({super.key, required this.value, required this.onChanged});

  final TargetAudience value;
  final ValueChanged<TargetAudience> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TargetAudience>(
        showSelectedIcon: false,
        segments: [
          for (final a in TargetAudience.values) ButtonSegment(value: a, label: Text(a.labelKey.tr())),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

/// Tappable read-only field that opens a native picker.
class PickerRow extends StatelessWidget {
  const PickerRow({super.key, required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: setupInputDecoration(context, label, icon: icon),
        isEmpty: value == null,
        child: Text(value ?? '', style: TextStyle(color: colorScheme.onSurface), overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Primary submit button used at the bottom of both forms.
class SubmitButton extends StatelessWidget {
  const SubmitButton({super.key, required this.label, required this.icon, required this.busy, required this.onPressed});

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(shape: const StadiumBorder()),
        onPressed: busy ? null : onPressed,
        icon: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }
}
