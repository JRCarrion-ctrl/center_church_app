// File: lib/features/event_setup/widgets/setup_card.dart
import 'package:material_ui/material_ui.dart';

/// Flat grouped card that uses the app-wide CardTheme (28px radius, hairline
/// border, no elevation), with an optional small uppercase section label.
class SetupCard extends StatelessWidget {
  const SetupCard({super.key, required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            child: Text(
              label!.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ],
    );
  }
}

/// Input decoration matching the existing event form (church_event_form_modal).
InputDecoration setupInputDecoration(BuildContext context, String label, {IconData? icon}) {
  final colorScheme = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(16);
  return InputDecoration(
    labelText: label,
    prefixIcon: icon != null ? Icon(icon, color: colorScheme.primary) : null,
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.error, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  );
}

/// Centered message used for empty / restricted states.
class SetupMessage extends StatelessWidget {
  const SetupMessage({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
