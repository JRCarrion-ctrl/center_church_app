// File: lib/features/landing/landing_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../shared/widgets/widgets.dart';

class LandingPage extends StatefulWidget {
  final VoidCallback? onContinue;
  const LandingPage({super.key, this.onContinue});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  String selectedLanguage = 'en';

  String get churchName =>
      selectedLanguage == 'en' ? 'Center Church Frederick' : 'Centro Cristiano Frederick';

  void setLanguage(String lang) {
    setState(() {
      selectedLanguage = lang;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final fontSize = screenHeight * 0.022;
    final padding = screenHeight * 0.018;

    final appState = context.watch<AppState>();
    final profile = appState.profile;

    final statusText = profile != null
        ? 'Logged in as: ${profile.displayName}'
        : 'Not Currently Logged In: Login/Signup';

    if (appState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset(
              'assets/landing_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(color: const Color(0x99000000)),
          Center(
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
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: profile == null ? () => context.push('/auth') : null,
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    decoration: profile == null
                        ? TextDecoration.underline
                        : TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(double screenHeight) {
    return Center(
      child: Image.asset(
        'assets/logo_image.png',
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
        color: Colors.white70,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildButtons(double fontSize, double padding) {
    return Column(
      children: [
        SecondaryButton(
            title: "How to Use", onTap: () {}, fontSize: fontSize, padding: padding),
        SizedBox(height: padding * 1.4),
        SecondaryButton(
            title: "Church Information",
            onTap: () {},
            fontSize: fontSize,
            padding: padding),
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
          onTap: () {
            context.go('/');
            Provider.of<AppState>(context, listen: false).setIndex(2);
            Provider.of<AppState>(context, listen: false).markLandingSeen();
          },
          fontSize: fontSize,
          padding: padding,
        ),
      ],
    );
  }
}
