import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class FAQItem {
  final String question;
  final String answer;

  const FAQItem({required this.question, required this.answer});
}

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  String _searchQuery = '';

  // Use a getter so .tr() always evaluates with the latest locale
  List<FAQItem> get _allFaqs => [
        FAQItem(question: "faq_q1".tr(), answer: "faq_a1".tr()),
        FAQItem(question: "faq_q2".tr(), answer: "faq_a1".tr()), // Assuming faq_a2 was meant here
        FAQItem(question: "faq_q3".tr(), answer: "faq_a3".tr()),
        FAQItem(question: "faq_q4".tr(), answer: "faq_a4".tr()),
        FAQItem(question: "faq_q5".tr(), answer: "faq_a5".tr()),
        FAQItem(question: "faq_q7".tr(), answer: "faq_a7".tr()),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Filter logic for the search bar
    final filteredFaqs = _allFaqs.where((faq) {
      final query = _searchQuery.toLowerCase();
      return faq.question.toLowerCase().contains(query) || 
             faq.answer.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("key_289".tr()),
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
                hintText: "Search FAQs...",
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
            child: filteredFaqs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: theme.disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          "No results found",
                          style: TextStyle(color: theme.disabledColor, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredFaqs.length,
                    itemBuilder: (context, index) {
                      return _FAQCard(faq: filteredFaqs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// 3. Simplified, Stateless FAQ Card
class _FAQCard extends StatelessWidget {
  final FAQItem faq;

  const _FAQCard({required this.faq});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0, // Flat look is more modern
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias, // Ensures the background color doesn't bleed out of rounded corners
      child: Theme(
        // This removes the ugly default divider lines of ExpansionTile
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: theme.colorScheme.primary,
          collapsedIconColor: theme.colorScheme.onSurfaceVariant,
          title: Text(
            faq.question,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              faq.answer,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5, // Improves readability for long text
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}