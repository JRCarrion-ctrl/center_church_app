// File: lib/features/landing/landing_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../app_state.dart';
import '../../shared/widgets/widgets.dart';
import '../../features/auth/profile.dart';

// --- Constants ---
const double _kButtonSpacingFactor = 1.4;
const double _kHomeButtonSpacingFactor = 3.3;

// --- Refactored Widgets ---

/// A reusable widget for the main background.
class _LandingBackground extends StatelessWidget {
  const _LandingBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        SizedBox.expand(
          child: Image.asset(
            'assets/landing_v2.png',
            fit: BoxFit.cover,
          ),
        ),
        // Dark overlay for contrast
        Container(
          color: isDark ? Colors.black.withAlpha(64) : Colors.black.withAlpha(32),
        ),
      ],
    );
  }
}

/// The logo and church title section.
class _LandingTitleSection extends StatelessWidget {
  final double screenHeight;

  const _LandingTitleSection({required this.screenHeight});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final languageCode = appState.languageCode;
    final churchName = languageCode == 'en'
        ? 'Center Church Frederick'
        : 'Centro Cristiano Frederick';
    final fontSize = screenHeight * 0.022;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo_light.png',
          width: screenHeight * 0.1, 
          height: screenHeight * 0.1,
          fit: BoxFit.contain,
          color: Colors.white.withValues(alpha: 0.9),
          semanticLabel: 'Church Logo',
        ),
        SizedBox(height: screenHeight * 0.015),
        Text(
          churchName.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize * 0.9,
            fontWeight: FontWeight.w400,
            letterSpacing: 4.0,
            shadows: const [
              Shadow(
                blurRadius: 3,
                color: Colors.black54,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The set of navigation buttons.
class _LandingButtons extends StatelessWidget {
  final double fontSize;
  final double padding;
  final VoidCallback onSelectLanguage;
  final VoidCallback goToHome;

  const _LandingButtons({
    required this.fontSize,
    required this.padding,
    required this.onSelectLanguage,
    required this.goToHome,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SecondaryButton(
          title: "landing_01".tr(),
          onTap: () => context.push('/more/how_to'),
          fontSize: fontSize,
          padding: padding,
        ),
        SizedBox(height: padding * _kButtonSpacingFactor),
        SecondaryButton(
          title: "landing_02".tr(),
          onTap: () => launchUrl(Uri.parse('https://www.centrocristianofrederick.com/')),
          fontSize: fontSize,
          padding: padding,
        ),
        SizedBox(height: padding * _kButtonSpacingFactor),
        SecondaryButton(
          title: "landing_03".tr(),
          onTap: onSelectLanguage,
          fontSize: fontSize,
          padding: padding,
        ),
        SizedBox(height: padding * _kHomeButtonSpacingFactor),
        PrimaryButton(
          title: "landing_04".tr(),
          onTap: goToHome,
          fontSize: fontSize,
          padding: padding,
        ),
      ],
    );
  }
}

/// The status indicator at the bottom (Login/Welcome).
class _AuthStatusDisplay extends StatelessWidget {
  final Profile? profile;

  const _AuthStatusDisplay({this.profile});

  @override
  Widget build(BuildContext context) {
    final isAuth = profile != null;
    final statusText = isAuth
        ? "landing_05".tr(args: [profile!.displayName])
        : "landing_06".tr();

    // Set the dynamic border color
    final borderColor = isAuth 
        ? Colors.green.withAlpha(180) 
        : Colors.red.withAlpha(180);
        
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPadding > 0 ? bottomPadding + 16 : 30,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: isAuth ? null : () => context.push('/auth'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(8),
              // Apply the dynamic border here
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Language Selector Modal
class _LanguageSelectorModal extends StatefulWidget {
  final String initialLanguageCode;
  final AppState appState;

  const _LanguageSelectorModal({
    required this.initialLanguageCode,
    required this.appState,
  });

  @override
  State<_LanguageSelectorModal> createState() => __LanguageSelectorModalState();
}

class __LanguageSelectorModalState extends State<_LanguageSelectorModal> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguageCode;
  }

  void _handleLanguageChange(String? value) {
    if (value != null) {
      widget.appState.setLanguageCode(context, value);
      setState(() => _selectedLanguage = value);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Stronger blur for content readability
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15), // Translucent white tint
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Small handle indicator at the top
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                "landing_07".tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              RadioGroup<String>(
                groupValue: _selectedLanguage,
                onChanged: _handleLanguageChange,
                child: Column(
                  children: [
                    _buildLanguageTile('en', "landing_08".tr()),
                    _buildLanguageTile('es', "landing_09".tr()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTile(String value, String label) {
    final isSelected = _selectedLanguage == value;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Radio<String>(
          value: value,
          activeColor: Colors.white,
          fillColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.8)),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => _handleLanguageChange(value),
      ),
    );
  }
}

// --- Main Refactored Widget ---

class LandingPage extends StatefulWidget {
  final VoidCallback? onContinue;
  const LandingPage({super.key, this.onContinue});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  // Use a constant for the home tab index
  static const int _homeTabIndex = 2; 

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Calculate dimensions once
    final screenHeight = MediaQuery.of(context).size.height;
    final fontSize = screenHeight * 0.022;
    final padding = screenHeight * 0.018;

    return Scaffold(
      body: Stack(
        children: [
          const _LandingBackground(),
          _buildMainContent(appState, screenHeight, fontSize, padding),
          _AuthStatusDisplay(profile: appState.profile),
        ],
      ),
    );
  }

  /// Builds the central content area.
  Widget _buildMainContent(
    AppState appState,
    double screenHeight,
    double fontSize,
    double padding,
  ) {
    return Center(
      child: SingleChildScrollView(
        // Retain the physics setting
        physics: const NeverScrollableScrollPhysics(), 
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LandingTitleSection(screenHeight: screenHeight),
            SizedBox(height: screenHeight * 0.06),
            _LandingButtons(
              fontSize: fontSize,
              padding: padding,
              onSelectLanguage: _showLanguageSelector,
              goToHome: _goToHome,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    final appState = Provider.of<AppState>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Required for the glass effect to show
      barrierColor: Colors.black.withValues(alpha: 0.2), // Subtle dimming of the background
      builder: (_) => _LanguageSelectorModal(
        initialLanguageCode: appState.languageCode,
        appState: appState,
      ),
    );
  }

  void _goToHome() {
    if (widget.onContinue != null) {
      // Use the provided callback if available
      widget.onContinue!();
    } else {
      // Fallback to default navigation logic
      final appState = Provider.of<AppState>(context, listen: false);
      appState.updateTabIndex(_homeTabIndex);
      context.go('/');
    }
  }
}