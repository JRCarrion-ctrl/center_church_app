// File: lib/shared/widgets/glass.dart
//
// Shared "frosted glass over the church photo" look used by the landing page
// and the Event Setup tab. All colors come from the ambient ColorScheme; the
// photo-backed widgets force the dark theme so text stays light on the image.
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

const String kLandingPhoto = 'assets/landing_v2.png';

/// Frosted, translucent panel. Place it over an image or a colored surface.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 32,
    this.opacity = 0.42,
    this.blur = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// How much of the surface color covers the photo (0 = clear, 1 = solid).
  final double opacity;

  /// Blur strength of whatever is behind the panel.
  final double blur;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: opacity),
            borderRadius: shape,
            border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Square-ish quick action: icon bubble, label, optional caption.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback onTap;

  /// Filled with the primary color, for the main action in a row.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bg = emphasized ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.06);
    final fg = emphasized ? colorScheme.onPrimary : colorScheme.onSurface;
    final bubble = emphasized ? colorScheme.onPrimary.withValues(alpha: 0.14) : colorScheme.onSurface.withValues(alpha: 0.08);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: bubble, shape: BoxShape.circle),
                  child: Icon(icon, size: 22, color: fg),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.72)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Church photo with a bottom gradient, used as a page hero.
class PhotoBackdrop extends StatelessWidget {
  const PhotoBackdrop({super.key, this.child, this.scrimStrength = 0.85, this.midStrength = 0.10});

  final Widget? child;

  /// Opacity of the gradient at the bottom edge.
  final double scrimStrength;

  /// Opacity of the gradient through the middle of the photo.
  final double midStrength;

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(kLandingPhoto, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scrim.withValues(alpha: 0.25),
                scrim.withValues(alpha: midStrength),
                scrim.withValues(alpha: scrimStrength),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}

/// Rounded photo header card: big title, subtitle, optional trailing action.
/// Text is always light because it sits on the photo.
class PhotoHeader extends StatelessWidget {
  const PhotoHeader({super.key, required this.title, this.subtitle, this.trailing, this.height = 170});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ccfDarkTheme,
      child: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: height,
              child: PhotoBackdrop(
                // The button floats in the corner so it never pushes the
                // title down (short headers used to overflow).
                child: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      right: trailing != null ? 72 : 20,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) Positioned(top: 14, right: 14, child: trailing!),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small round glass button for use on the photo (e.g. settings, language).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GlassPanel(
        radius: 24,
        padding: EdgeInsets.zero,
        child: IconButton(icon: Icon(icon, color: colorScheme.onSurface), onPressed: onPressed),
      ),
    );
  }
}
