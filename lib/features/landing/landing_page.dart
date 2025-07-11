// File: lib/features/landing/landing_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../shared/widgets/widgets.dart';
import '../../features/auth/profile.dart';

class LandingPage extends StatefulWidget {
  final VoidCallback? onContinue;
  const LandingPage({super.key, this.onContinue});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  String selectedLanguage = 'en';

  String get churchName => selectedLanguage == 'en'
      ? 'Center Church Frederick'
      : 'Centro Cristiano Frederick';

  void setLanguage(String lang) {
    setState(() => selectedLanguage = lang);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.profile;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenHeight = MediaQuery.of(context).size.height;
    final fontSize = screenHeight * 0.022;
    final padding = screenHeight * 0.018;

    if (appState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(isDark),
          _buildMainContent(screenHeight, fontSize, padding),
          _buildAuthStatus(profile),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Stack(
      children: [
        SizedBox.expand(
          child: Image.asset(
            'assets/landing_background.png',
            fit: BoxFit.cover,
          ),
        ),
        Container(
          color: isDark
              ? Colors.black.withAlpha(64)
              : Colors.black.withAlpha(32),
        ),
      ],
    );
  }

  Widget _buildMainContent(double screenHeight, double fontSize, double padding) {
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLogo(screenHeight),
            SizedBox(height: screenHeight * 0.015),
            _buildTitle(fontSize),
            SizedBox(height: screenHeight * 0.06),
            _buildButtons(fontSize, padding),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(double screenHeight) {
    return Center(
      child: Image.asset(
        'assets/logo_light.png',
        width: screenHeight * 0.12,
        height: screenHeight * 0.12,
        fit: BoxFit.contain,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTitle(double fontSize) {
    return Text(
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
    );
  }

  Widget _buildButtons(double fontSize, double padding) {
    return Column(
      children: [
        SecondaryButton(
          title: "How to Use",
          onTap: () {},
          fontSize: fontSize,
          padding: padding,
        ),
        SizedBox(height: padding * 1.4),
        SecondaryButton(
          title: "Church Information",
          onTap: () {},
          fontSize: fontSize,
          padding: padding,
        ),
        SizedBox(height: padding * 1.4),
        LanguageButtons(
          selectedLanguage: selectedLanguage,
          onLanguageChange: setLanguage,
          fontSize: fontSize,
          padding: padding,
        ),
        SizedBox(height: padding * 3.3),
        PrimaryButton(
          title: "Home",
          onTap: _goToHome,
          fontSize: fontSize,
          padding: padding,
        ),
      ],
    );
  }

  Widget _buildAuthStatus(Profile? profile) {
    final statusText = profile != null
        ? 'Logged in as: ${profile.displayName}'
        : 'Not Currently Logged In: Login/Signup';

    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: profile == null ? () => context.push('/auth') : null,
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

  void _goToHome() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.markLandingSeen();
    appState.updateTabIndex(2); // Home
    context.go('/');
  }
}
