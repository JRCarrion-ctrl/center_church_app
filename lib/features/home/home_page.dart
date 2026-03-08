// File: lib/features/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:ccf_app/app_state.dart';
import 'package:provider/provider.dart';
import 'package:ccf_app/features/home/welcome_header.dart';
import 'package:ccf_app/features/home/announcements_section.dart';
import 'package:ccf_app/features/home/livestream_preview.dart';
import 'package:ccf_app/features/home/church_info_card.dart';
import 'package:ccf_app/features/home/quick_links_footer.dart';
import 'package:ccf_app/features/home/incident_report_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const double horizontalPadding = 16.0;
  static const double verticalPadding = 24.0;
  static const double maxWidth = 600.0;
  static const double spacing = 24.0;

  Widget _buildConstrainedChild(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthenticated = context.watch<AppState>().isAuthenticated;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // We use a Stack to layer the background asset under the content
      body: Stack(
        children: [
          // 1. The Pre-Blurred Asset (Performance efficient)
          Positioned.fill(
            child: Image.asset(
              'assets/landing_v2_blurred_2.png',
              fit: BoxFit.cover,
            ),
          ),
          // 2. The Accessibility Tint Overlay
          // Provides a readable surface for the cards and text
          Positioned.fill(
            child: Container(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.65) 
                  : Colors.white.withValues(alpha: 0.70),
            ),
          ),
          // 3. Your Main App Content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: verticalPadding)),

                // --- WELCOME HEADER ---
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(child: _buildConstrainedChild(const WelcomeHeader())),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: spacing)),

                // --- CHURCH INFO CARD ---
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(child: _buildConstrainedChild(const ChurchInfoCard())),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: spacing)),

                // --- ANNOUNCEMENTS SECTION ---
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(child: _buildConstrainedChild(const AnnouncementsSection())),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: spacing)),

                // --- LIVESTREAM PREVIEW ---
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(child: _buildConstrainedChild(const LivestreamPreview())),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: spacing)),

                // --- QUICK LINKS FOOTER ---
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(child: _buildConstrainedChild(const QuickLinksFooter())),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: verticalPadding)),

                // --- CONDITIONAL INCIDENT REPORT BUTTON ---
                if (isAuthenticated)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                    sliver: SliverToBoxAdapter(
                      child: _buildConstrainedChild(const IncidentReportButton()),
                    ),
                  ),
                
                const SliverToBoxAdapter(child: SizedBox(height: verticalPadding)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}