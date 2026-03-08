// File: lib/features/home/quick_links_footer.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

class QuickLinksFooter extends StatelessWidget {
  const QuickLinksFooter({super.key});

  static const String _donateUrl = 'https://tccf.givingfire.com';
  static const String _cafeUrl = 'https://center-cafe.square.site';

  static const List<LinkData> _socials = [
    LinkData(
      label: 'Facebook',
      url: 'https://www.facebook.com/profile.php?id=100089863186477',
      icon: FontAwesomeIcons.facebook,
    ),
    LinkData(
      label: 'Instagram',
      url: 'https://www.instagram.com/centrocristiano_frederick/',
      icon: FontAwesomeIcons.instagram,
    ),
    LinkData(
      label: 'YouTube',
      url: 'https://www.youtube.com/@centerchurch8898/streams',
      icon: FontAwesomeIcons.youtube,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              _SectionLabel(isDark: isDark),
              const SizedBox(height: 20),
              _DonateCard(
                isDark: isDark,
                onTap: () => _launchUrl(context, _donateUrl),
              ),
              const SizedBox(height: 28),
              const Divider(height: 1),
              const SizedBox(height: 24),
              _SecondaryLinks(
                socials: _socials,
                isDark: isDark,
                onLaunch: (url) => _launchUrl(context, url),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    HapticFeedback.lightImpact();

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open link'),
          ),
        );
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final bool isDark;

  const _SectionLabel({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      "key_187a".tr().toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: isDark ? Colors.white54 : Colors.black45,
      ),
    );
  }
}

class _DonateCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _DonateCard({
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.8)
              : const Color(0xFF1D4ED8).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.35 : 0.15,
              ),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.heart_fill,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              "key_188".tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryLinks extends StatelessWidget {
  final List<LinkData> socials;
  final bool isDark;
  final ValueChanged<String> onLaunch;

  const _SecondaryLinks({
    required this.socials,
    required this.isDark,
    required this.onLaunch,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    final iconColor = isDark ? Colors.white : Colors.black;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        ...socials.map(
          (link) => _CircleIconButton(
            icon: link.icon,
            bgColor: bgColor,
            iconColor: _brandColor(link.icon, iconColor),
            onTap: () => onLaunch(link.url),
          ),
        ),
        _CafeButton(
          bgColor: bgColor,
          iconColor: iconColor,
          onTap: () => onLaunch(QuickLinksFooter._cafeUrl),
        ),
      ],
    );
  }

  Color _brandColor(IconData icon, Color fallback) {
    if (icon == FontAwesomeIcons.facebook) {
      return const Color(0xFF1877F2);
    }
    if (icon == FontAwesomeIcons.instagram) {
      return const Color(0xFFE4405F);
    }
    if (icon == FontAwesomeIcons.youtube) {
      return const Color(0xFFFF0000);
    }
    return fallback;
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: iconColor.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor,
        ),
      ),
    );
  }
}

class _CafeButton extends StatelessWidget {
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _CafeButton({
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FontAwesomeIcons.mugSaucer,
              size: 18,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Cafe',
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkData {
  final String label;
  final String url;
  final IconData icon;

  const LinkData({
    required this.label,
    required this.url,
    required this.icon,
  });
}
