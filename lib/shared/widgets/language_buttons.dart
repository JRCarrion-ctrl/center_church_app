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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () => onLanguageChange('en'),
          style: OutlinedButton.styleFrom(
            backgroundColor:
                selectedLanguage == 'en' ? const Color(0x33FFFFFF) : Colors.transparent,
            side: const BorderSide(color: Colors.white),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
            textStyle: TextStyle(fontSize: fontSize),
          ),
          child: const Text('English'),
        ),
        SizedBox(width: padding),
        OutlinedButton(
          onPressed: () => onLanguageChange('es'),
          style: OutlinedButton.styleFrom(
            backgroundColor:
                selectedLanguage == 'es' ? const Color(0x33FFFFFF) : Colors.transparent,
            side: const BorderSide(color: Colors.white),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
            textStyle: TextStyle(fontSize: fontSize),
          ),
          child: const Text('Español'),
        ),
      ],
    );
  }
}
