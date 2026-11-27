// File: lib/features/landing/landing_page.dart
//
// Full-bleed church photo. Top corners: profile (when signed in) and an
// EN | ES switch. Centre: the church mark. Bottom (thumb reach): a frosted
// panel with a time-of-day greeting, one primary action, sign-in when signed
// out, and two compact quick links. Content fades/slides in once on open.
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../shared/widgets/glass.dart';

class LandingPage extends StatefulWidget {
  final VoidCallback? onContinue;
  const LandingPage({super.key, this.onContinue});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const int _homeTabIndex = 2;

  // Same sites as the Home church-info card, picked by language.
  static final Uri _englishSite = Uri.parse('https://www.tccf.church/');
  static final Uri _spanishSite = Uri.parse('https://www.centrocristianofrederick.com/');

  void _goToHome() {
    if (widget.onContinue != null) {
      widget.onContinue!();
      return;
    }
    context.read<AppState>().updateTabIndex(_homeTabIndex);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isSpanish = appState.languageCode == 'es';
    final site = isSpanish ? _spanishSite : _englishSite;

    // The page sits on a photo, so it always uses the dark theme's colors.
    return Theme(
      data: ccfDarkTheme,
      child: Builder(
        builder: (context) {
          if (appState.isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final profile = appState.profile;

          return Scaffold(
            body: PhotoBackdrop(
              scrimStrength: 0.92,
              // A touch darker through the middle so the mark and panel read cleanly.
              midStrength: 0.22,
              child: SafeArea(
                child: LayoutBuilder(
                  // Scrolls only when the window is too short to fit.
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            // --- Top bar: full width, so the switch sits in the real corner.
                            Row(
                              children: [
                                if (profile != null)
                                  _ProfileButton(
                                    name: profile.displayName,
                                    onTap: () => context.push('/more/profile'),
                                  ),
                                const Spacer(),
                                _LanguageToggle(
                                  code: appState.languageCode,
                                  onChanged: (code) => appState.setLanguageCode(context, code),
                                ),
                              ],
                            ),
                            const Spacer(flex: 2),
                            const _Entrance(delayMs: 0, child: _Brand()),
                            const Spacer(flex: 3),
                            _Entrance(
                              delayMs: 150,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 460),
                                child: _WelcomePanel(
                                  name: profile?.displayName,
                                  siteLabel: site.host.replaceFirst('www.', ''),
                                  onEnter: _goToHome,
                                  onSignIn: () => context.push('/auth'),
                                  onHowTo: () => context.push('/more/how_to'),
                                  onWebsite: () => launchUrl(site, mode: LaunchMode.externalApplication),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Fades and slides its child up once when the page opens.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, required this.delayMs});

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final total = 600 + delayMs;
    final start = delayMs / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Soft shadow keeps the light text legible where it crosses bright parts
    // of the photo.
    final shadow = [Shadow(color: colorScheme.scrim.withValues(alpha: 0.55), blurRadius: 16)];
    return Column(
      children: [
        Image.asset(
          'assets/logo_light.png',
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          color: colorScheme.onSurface,
          semanticLabel: 'landing_church_name'.tr(),
        ),
        const SizedBox(height: 20),
        Text(
          'landing_church_name'.tr().toUpperCase(),
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            letterSpacing: 4,
            fontWeight: FontWeight.w500,
            shadows: shadow,
          ),
        ),
        const SizedBox(height: 14),
        // Thin gold rule: the brand accent from the app theme.
        Container(width: 36, height: 2, decoration: BoxDecoration(color: kBrandAccent, borderRadius: BorderRadius.circular(1))),
      ],
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    required this.name,
    required this.siteLabel,
    required this.onEnter,
    required this.onSignIn,
    required this.onHowTo,
    required this.onWebsite,
  });

  final String? name;
  final String siteLabel;
  final VoidCallback onEnter;
  final VoidCallback onSignIn;
  final VoidCallback onHowTo;
  final VoidCallback onWebsite;

  String get _timeGreetingKey {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'landing_good_morning';
    if (hour < 18) return 'landing_good_afternoon';
    return 'landing_good_evening';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final firstName = name?.trim().split(RegExp(r'\s+')).first;
    final signedIn = firstName != null && firstName.isNotEmpty;

    return GlassPanel(
      radius: 28,
      // More solid and more blurred than the default, so the photo behind it
      // becomes a soft wash instead of visible shapes.
      opacity: 0.66,
      blur: 32,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _timeGreetingKey.tr().toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: kBrandAccent,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            signedIn ? 'landing_welcome_back'.tr(namedArgs: {'name': firstName}) : 'landing_welcome'.tr(),
            style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            (signedIn ? 'landing_welcome_back_sub' : 'landing_welcome_sub').tr(),
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              onPressed: onEnter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('landing_enter'.tr()),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
          if (!signedIn) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.35)),
                ),
                onPressed: onSignIn,
                icon: const Icon(Icons.login_rounded),
                label: Text('landing_sign_in'.tr()),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _QuickLink(
            icon: Icons.help_outline_rounded,
            label: 'landing_01'.tr(),
            caption: 'landing_how_to_sub'.tr(),
            trailingIcon: Icons.chevron_right_rounded,
            onTap: onHowTo,
          ),
          _QuickLink(
            icon: Icons.public_rounded,
            label: 'landing_02'.tr(),
            caption: siteLabel,
            trailingIcon: Icons.open_in_new_rounded,
            onTap: onWebsite,
          ),
        ],
      ),
    );
  }
}

/// Compact list row: icon bubble, label + caption, trailing hint icon.
class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.caption,
    required this.trailingIcon,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final IconData trailingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.9)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(
                    caption,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            Icon(trailingIcon, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.45)),
          ],
        ),
      ),
    );
  }
}

/// Glass circle with the user's initial; opens the profile.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    return Tooltip(
      message: 'landing_profile'.tr(),
      child: GlassPanel(
        radius: 24,
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                initial,
                style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline EN | ES switch on a glass pill.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.code, required this.onChanged});

  final String code;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'landing_03'.tr(),
      child: GlassPanel(
        radius: 24,
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LangChip(label: 'landing_lang_en'.tr(), tooltip: 'landing_08'.tr(), selected: code == 'en', onTap: () => onChanged('en')),
            _LangChip(label: 'landing_lang_es'.tr(), tooltip: 'landing_09'.tr(), selected: code == 'es', onTap: () => onChanged('es')),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.label, required this.tooltip, required this.selected, required this.onTap});

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: ShapeDecoration(
          color: selected ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0),
          shape: const StadiumBorder(),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: selected ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
