// File: lib/shared/widgets/app_surface.dart
//
// The group chat's look, shared with the rest of the app: a softly tinted
// page and clean cards (white with a hairline edge and a soft shadow in light
// mode, a raised surface in dark mode). All colors come from the ColorScheme.
import 'package:material_ui/material_ui.dart';

/// Page background behind cards: the same tint the group chat uses.
Color appBackgroundColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surface
      : theme.colorScheme.surfaceContainerLow;
}

/// Card decoration matching other people's messages in the group chat.
BoxDecoration appCardDecoration(BuildContext context, {double radius = 24}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colorScheme.onSurface.withValues(alpha: dark ? 0.06 : 0.09)),
    boxShadow: dark
        ? null
        : [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
  );
}

/// Fills the page with [appBackgroundColor].
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: appBackgroundColor(context), child: child);
  }
}

/// A clean card in the group chat style.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.radius = 24, this.padding});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appCardDecoration(context, radius: radius),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: child,
    );
  }
}
