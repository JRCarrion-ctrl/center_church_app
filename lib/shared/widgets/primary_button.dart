// lib/widgets/primary_button.dart
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final double fontSize;
  final double padding;

  const PrimaryButton({
    super.key,
    required this.title,
    required this.onTap,
    this.fontSize = 16.0,
    this.padding = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          vertical: padding / 1.5,
          horizontal: padding * 1.5,
       ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
       ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        textStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: onTap,
      child: Text(title),
    );
  }
}
