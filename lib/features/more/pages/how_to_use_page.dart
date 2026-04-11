import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

class HowToSection {
  final String title;
  final String content;

  const HowToSection({required this.title, required this.content});
}

class HowToUsePage extends StatefulWidget {
  const HowToUsePage({super.key});

  @override
  State<HowToUsePage> createState() => _HowToUsePageState();
}

class _HowToUsePageState extends State<HowToUsePage> {
  String _searchQuery = '';

  // Use a getter so .tr() evaluates correctly if the user switches languages
  List<HowToSection> get _allSections => [
        HowToSection(title: "how_q1".tr(), content: "how_a1".tr()),
        HowToSection(title: "how_q2".tr(), content: "how_a2".tr()),
        HowToSection(title: "how_q3".tr(), content: "how_a3".tr()),
        HowToSection(title: "how_q4".tr(), content: "how_a4".tr()),
        HowToSection(title: "how_q5".tr(), content: "how_a5".tr()),
        HowToSection(title: "how_q6".tr(), content: "how_a6".tr()),
        HowToSection(title: "how_q8".tr(), content: "how_a8".tr()), // Assuming skipping 7 is intentional
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Filter logic for the search bar
    final filteredSections = _allSections.where((section) {
      final query = _searchQuery.toLowerCase();
      return section.title.toLowerCase().contains(query) || 
             section.content.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("key_290".tr()), // E.g., "How to Use"
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Sleek Search Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: "Search guides...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          // 2. The List (or empty state)
          Expanded(
            child: filteredSections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book, size: 64, color: theme.disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          "No guides found",
                          style: TextStyle(color: theme.disabledColor, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        // Quick support link if search fails
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.support_agent),
                          label: const Text("Contact Support"),
                          onPressed: () => context.push('/more/settings/contact-support'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    // Add 1 to the count to render the Contact Support banner at the very bottom
                    itemCount: filteredSections.length + 1,
                    itemBuilder: (context, index) {
                      // Render the Support Banner as the last item
                      if (index == filteredSections.length) {
                        return const _SupportBanner();
                      }
                      return _HowToCard(section: filteredSections[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// 3. Simplified, Stateless Card
class _HowToCard extends StatelessWidget {
  final HowToSection section;

  const _HowToCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Removes default ExpansionTile divider lines
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: theme.colorScheme.primary,
          collapsedIconColor: theme.colorScheme.onSurfaceVariant,
          title: Text(
            section.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. Contact Support Escape Hatch
class _SupportBanner extends StatelessWidget {
  const _SupportBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 40.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.help_outline, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              "Still have questions?",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Our support team is here to help.",
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text("Contact Support"),
              onPressed: () => context.push('/more/settings/contact-support'),
            ),
          ],
        ),
      ),
    );
  }
}