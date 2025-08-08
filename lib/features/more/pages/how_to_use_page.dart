import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class HowToUsePage extends StatelessWidget {
  HowToUsePage({super.key});

  final List<HowToSection> sections = [
    HowToSection(
      title: "how_q1".tr(),
      content:
          "how_a1".tr(),
    ),
    HowToSection(
      title: "how_q2".tr(),
      content:
          "how_a2".tr(),
    ),
    HowToSection(
      title: "how_q3".tr(),
      content:
          "how_a3".tr(),
    ),
    HowToSection(
      title: "how_q4".tr(),
      content:
          "how_a4".tr(),
    ),
    HowToSection(
      title: "how_q5".tr(),
      content:
          "how_a5".tr(),
    ),
    HowToSection(
      title: "how_q6".tr(),
      content:
          "how_a6".tr(),
    ),
    HowToSection(
      title: "how_q7".tr(),
      content:
          "how_a7".tr(),
    ),
    HowToSection(
      title: "how_q8".tr(),
      content:
          "how_a8".tr(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("key_290".tr()),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return _HowToCard(section: section);
        },
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  final HowToSection section;

  const _HowToCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(section.title, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: [
          Text(section.content, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class HowToSection {
  final String title;
  final String content;

  const HowToSection({required this.title, required this.content});
}
