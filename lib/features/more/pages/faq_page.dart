import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class FAQPage extends StatelessWidget {
  FAQPage({super.key});

  final List<FAQItem> faqs = [
    FAQItem(
      question: "faq_q1".tr(),
      answer:
          "faq_a1".tr(),
    ),
    FAQItem(
      question: "faq_q2".tr(),
      answer:
          "faq_a1".tr(),
    ),
    FAQItem(
      question: "faq_q3".tr(),
      answer:
          "faq_a3".tr(),
    ),
    FAQItem(
      question: "faq_q4".tr(),
      answer:
          "faq_a4".tr(),
    ),
    FAQItem(
      question: "faq_q5".tr(),
      answer:
          "faq_a5".tr(),
    ),
    FAQItem(
      question: "faq_q6".tr(),
      answer:
          "faq_a6".tr(),
    ),
    FAQItem(
      question: "faq_q7".tr(),
      answer:
          "faq_a7".tr(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("key_289".tr()),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return _FAQCard(faq: faq);
        },
      ),
    );
  }
}

class _FAQCard extends StatefulWidget {
  final FAQItem faq;

  const _FAQCard({required this.faq});

  @override
  State<_FAQCard> createState() => _FAQCardState();
}

class _FAQCardState extends State<_FAQCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(widget.faq.question, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        initiallyExpanded: _expanded,
        onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
        children: [
          Text(widget.faq.answer, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  const FAQItem({required this.question, required this.answer});
}
