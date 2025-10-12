// File: lib/features/landing/landing_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../app_state.dart';
import '../../shared/widgets/widgets.dart';
import '../../features/auth/profile.dart';

// --- Constants ---
const double _kLogoSizeFactor = 0.12;
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
            'assets/landing_background.png',
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
          width: screenHeight * _kLogoSizeFactor,
          height: screenHeight * _kLogoSizeFactor,
          fit: BoxFit.contain,
          color: Colors.white,
          semanticLabel: 'Church Logo',
        ),
        SizedBox(height: screenHeight * 0.015),
        Text(
          churchName,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
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

    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: isAuth ? null : () => context.push('/auth'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(80),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                decoration: TextDecoration.none,
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
  
  // Handler for when a new language is selected via the RadioGroup
  void _handleLanguageChange(String? value) {
    if (value != null) {
      // 1. Update the AppState
      widget.appState.setLanguageCode(context, value); 
      // 2. Update the local modal state
      setState(() => _selectedLanguage = value); 
      // 3. Close the modal after selection
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "landing_07".tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          
          // Wrap the entire group in the RadioGroup widget
          RadioGroup<String>(
            // The RadioGroup manages the current selection state
            groupValue: _selectedLanguage,
            // The RadioGroup manages the callback for all children
            onChanged: _handleLanguageChange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // English Option
                ListTile(
                  // We only need to provide the value to the Radio widget. 
                  // groupValue and onChanged are inherited from RadioGroup.
                  leading: const Radio<String>(value: 'en'),
                  title: Text("landing_08".tr()), // English label
                  // Tapping the ListTile is now enabled implicitly by RadioGroup 
                  // when it surrounds the Radio and the title.
                ),
                // Spanish Option
                ListTile(
                  leading: const Radio<String>(value: 'es'),
                  title: Text("landing_09".tr()), // Spanish label
                ),
              ],
            ),
          ),
        ],
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