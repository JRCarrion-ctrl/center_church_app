// lib/widgets/language_buttons.dart
import 'package:flutter/material.dart';

class LanguageButtons extends StatelessWidget {
  final String selectedLanguage;
  final void Function(String) onLanguageChange;
  final double fontSize;
  final double padding;

  const LanguageButtons({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChange,
    required this.fontSize,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Color getFill(String lang) {
  return selectedLanguage == lang
      ? Color(0xFFFAF4EF) // soft beige background
      : Color(0xFFFAF4EF).withAlpha(128); // coppery glow  
  }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () => onLanguageChange('en'),
          style: OutlinedButton.styleFrom(
            backgroundColor: getFill('en'),
            side: const BorderSide(color: Colors.black87),
            foregroundColor: Colors.black87,
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
            textStyle: TextStyle(fontSize: fontSize),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: const Text('English'),
        ),
        SizedBox(width: padding),
        OutlinedButton(
          onPressed: () => onLanguageChange('es'),
          style: OutlinedButton.styleFrom(
            backgroundColor: getFill('es'),
            side: const BorderSide(color: Colors.black87),
            foregroundColor: Colors.black87,
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
            textStyle: TextStyle(fontSize: fontSize),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: const Text('Español'),
        ),
      ],
    );
  }
}
